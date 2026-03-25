import SwiftUI

struct JoinScreen: View {
    @Environment(AuthService.self) private var auth
    @Environment(GameCoordinator.self) private var coordinator
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "apple.logo")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("AI Apples to Apples")
                .font(.largeTitle.bold())

            Text("Write prompts. Generate images.\nWin the round.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Your Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
                .autocorrectionDisabled()
                .padding(.horizontal, 40)
                .onSubmit { join() }

            Button(action: join) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Play")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)

            Spacer()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func join() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        Task {
            do {
                if !auth.isSignedIn {
                    _ = try await auth.signInAnonymously()
                }
                coordinator.playerName = trimmed
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}
