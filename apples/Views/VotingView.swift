import SwiftUI

struct VotingView: View {
    @Environment(GameCoordinator.self) private var coordinator
    @State private var errorMessage = ""
    @State private var showError = false

    private var hasVoted: Bool {
        guard let playerId = coordinator.currentPlayerId,
              let round = coordinator.currentRound else { return false }
        return round.votes[playerId] != nil
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Vote for the Best Match")
                    .font(.title2.bold())

                if let round = coordinator.currentRound {
                    AsyncImage(url: URL(string: round.greenCardURL)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if hasVoted {
                    Label("Vote cast!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    let voted = coordinator.currentRound?.votes.count ?? 0
                    let total = coordinator.players.count
                    Text("Waiting for others (\(voted)/\(total))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    if let round = coordinator.currentRound {
                        ForEach(round.submissions.values.sorted(by: { $0.submittedAt < $1.submittedAt }), id: \.playerId) { submission in
                            SubmissionCard(
                                submission: submission,
                                playerName: playerName(for: submission.playerId),
                                isOwnSubmission: submission.playerId == coordinator.currentPlayerId,
                                hasVoted: hasVoted
                            ) {
                                vote(for: submission.playerId)
                            }
                        }
                    }
                }

                ScoreBar(players: coordinator.players)
                    .padding(.top, 8)
            }
            .padding()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func playerName(for playerId: String) -> String {
        coordinator.players.first { $0.id == playerId }?.name ?? "Unknown"
    }

    private func vote(for playerId: String) {
        Task {
            do {
                try await coordinator.submitVote(for: playerId)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct SubmissionCard: View {
    let submission: Submission
    let playerName: String
    let isOwnSubmission: Bool
    let hasVoted: Bool
    let onVote: () -> Void

    private var canVote: Bool {
        !isOwnSubmission && !hasVoted
    }

    var body: some View {
        VStack(spacing: 8) {
            if let urlString = submission.generatedImageURL,
               urlString != "generation_failed",
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 150)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if canVote {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.blue, lineWidth: 2)
                    }
                }
                .onTapGesture {
                    if canVote { onVote() }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.15))
                    .frame(height: 150)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: submission.generatedImageURL == "generation_failed"
                                  ? "exclamationmark.triangle" : "photo")
                                .foregroundStyle(.secondary)
                            Text(submission.generatedImageURL == "generation_failed"
                                 ? "Generation failed" : "No image")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
            }

            Text(playerName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Your image")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.2), in: Capsule())
                .foregroundStyle(.orange)
                .opacity(isOwnSubmission ? 1 : 0)
        }
    }
}
