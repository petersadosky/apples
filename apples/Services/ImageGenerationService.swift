import Foundation
import FirebaseStorage

final class ImageGenerationService {
    private let apiKey: String
    private let storage = Storage.storage()

    init(apiKey: String = APIKeys.openAI) {
        self.apiKey = apiKey
    }

    func generateImage(prompt: String, maxAttempts: Int = 3) async throws -> String {
        var lastError: Error = ImageGenerationError.networkError
        let retryDelays: [UInt64] = [0, 3_000_000_000, 8_000_000_000] // 0s, 3s, 8s

        for attempt in 0..<maxAttempts {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: retryDelays[attempt])
            }
            do {
                return try await attemptGeneration(prompt: prompt)
            } catch ImageGenerationError.apiError(let code, _) where code == 400 || code == 401 {
                throw lastError // Don't retry auth or bad request errors
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func attemptGeneration(prompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": "gpt-image-1",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024",
            "quality": "medium",
            "output_format": "jpeg",
            "output_compression": 80
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenerationError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ImageGenerationError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let decoded = try JSONDecoder().decode(OpenAIImageResponse.self, from: data)
        guard let b64 = decoded.data.first?.b64_json else {
            throw ImageGenerationError.noImageReturned
        }

        guard let imageData = Data(base64Encoded: b64) else {
            throw ImageGenerationError.noImageReturned
        }

        // Upload to Firebase Storage and return the download URL
        let filename = "\(UUID().uuidString).jpg"
        let ref = storage.reference().child("generated_images/\(filename)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        return downloadURL.absoluteString
    }

    // MARK: - Response Models

    private struct OpenAIImageResponse: Decodable {
        let data: [ImageData]

        struct ImageData: Decodable {
            let b64_json: String
        }
    }

    // MARK: - Errors

    enum ImageGenerationError: LocalizedError {
        case networkError
        case apiError(statusCode: Int, message: String)
        case noImageReturned

        var errorDescription: String? {
            switch self {
            case .networkError:
                "Network error during image generation"
            case .apiError(let code, let message):
                "OpenAI API error (\(code)): \(message)"
            case .noImageReturned:
                "No image was returned"
            }
        }
    }
}
