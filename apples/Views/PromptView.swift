import SwiftUI

struct PromptView: View {
    @Environment(GameCoordinator.self) private var coordinator
    @State private var prompt = ""
    @State private var isSubmitting = false
    @State private var errorMessage = ""
    @State private var showError = false

    private var hasSubmitted: Bool {
        guard let playerId = coordinator.currentPlayerId,
              let round = coordinator.currentRound else { return false }
        return round.submissions[playerId] != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Round \(coordinator.session?.roundNumber ?? 0)")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let round = coordinator.currentRound {
                AsyncImage(url: URL(string: round.greenCardURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    default:
                        ProgressView()
                    }
                }
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if hasSubmitted {
                Label("Prompt submitted!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)

                let submitted = coordinator.currentRound?.submissions.count ?? 0
                let total = coordinator.players.count
                Text("Waiting for other players (\(submitted)/\(total))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Write a prompt to generate an image that matches this card")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Describe an image...", text: $prompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
                    .padding(.horizontal)

                Button(action: submitPrompt) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Submit Prompt")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
            }

            Spacer()

            ScoreBar(players: coordinator.players)
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func submitPrompt() {
        let trimmed = prompt.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true
        Task {
            do {
                try await coordinator.submitPrompt(trimmed)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSubmitting = false
        }
    }
}
