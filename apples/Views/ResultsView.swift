import SwiftUI

struct ResultsView: View {
    @Environment(GameCoordinator.self) private var coordinator
    @State private var isAdvancing = false
    @State private var errorMessage = ""
    @State private var showError = false

    private var isGameOver: Bool {
        coordinator.session?.state == .finished
    }

    private var roundWinners: [Player] {
        guard let winnerIds = coordinator.currentRound?.winnerPlayerIds else { return [] }
        return coordinator.players.filter { winnerIds.contains($0.id) }
    }

    private var gameWinner: Player? {
        guard let session = coordinator.session else { return nil }
        return coordinator.players.first { $0.score >= session.winningScore }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isGameOver, let winner = gameWinner {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.yellow)

                    Text("Game Over!")
                        .font(.largeTitle.bold())

                    Text("\(winner.name) wins!")
                        .font(.title)
                } else if isGameOver {
                    Text("Game Over!")
                        .font(.largeTitle.bold())

                    Text("The game was ended early.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Round \(coordinator.session?.roundNumber ?? 0) Results")
                        .font(.largeTitle.bold())

                    if !roundWinners.isEmpty {
                        let names = roundWinners.map(\.name).joined(separator: " & ")
                        if roundWinners.count > 1 {
                            Text("\(names) tie the round!")
                                .font(.title3)
                        } else {
                            Text("\(names) wins the round!")
                                .font(.title3)
                        }
                    }
                }

                // Winning image(s)
                ForEach(coordinator.currentRound?.winnerPlayerIds ?? [], id: \.self) { winnerId in
                    if let submission = coordinator.currentRound?.submissions[winnerId],
                       let urlString = submission.generatedImageURL,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Scoreboard
                VStack(spacing: 12) {
                    Text("Scoreboard")
                        .font(.headline)

                    ForEach(coordinator.players.sorted { $0.score > $1.score }) { player in
                        HStack {
                            if player.id == gameWinner?.id && isGameOver {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                            }
                            Text(player.name)
                            Spacer()
                            Text("\(player.score) / \(coordinator.session?.winningScore ?? 3)")
                                .bold()
                                .monospacedDigit()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                Spacer(minLength: 20)

                if isGameOver {
                    Button("Back to Lobby") {
                        coordinator.cleanup()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if coordinator.isHost {
                    Button(action: nextRound) {
                        if isAdvancing {
                            ProgressView()
                        } else {
                            Text("Next Round")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isAdvancing)
                } else {
                    Text("Waiting for host to start next round...")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func nextRound() {
        isAdvancing = true
        Task {
            do {
                try await coordinator.advanceState()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isAdvancing = false
        }
    }
}
