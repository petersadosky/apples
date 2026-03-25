import SwiftUI

struct WaitingRoomView: View {
    @Environment(GameCoordinator.self) private var coordinator
    @State private var isStarting = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Waiting Room")
                .font(.largeTitle.bold())

            if let session = coordinator.session {
                Text("Game Room")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(session.name)
                    .font(.title2.bold())
            }

            List {
                Section("Players (\(coordinator.players.count)/4)") {
                    ForEach(coordinator.players) { player in
                        HStack {
                            Text(player.name)
                                .font(.body)
                            Spacer()
                            if player.id == coordinator.session?.hostId {
                                Text("Host")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.orange.opacity(0.2), in: Capsule())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            if coordinator.isHost {
                Button(action: startGame) {
                    if isStarting {
                        ProgressView()
                    } else {
                        Text("Start Game")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(coordinator.players.count < 2 || isStarting)

                if coordinator.players.count < 2 {
                    Text("Need at least 2 players to start")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Waiting for host to start the game...")
                    .foregroundStyle(.secondary)
            }

            Button(coordinator.isHost ? "End Game" : "Leave Game", role: .destructive) {
                leaveSession()
            }
            .controlSize(.small)
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func startGame() {
        isStarting = true
        Task {
            do {
                try await coordinator.startGame()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isStarting = false
        }
    }

    private func leaveSession() {
        Task {
            try? await coordinator.leaveSession()
        }
    }
}
