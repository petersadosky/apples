import SwiftUI

struct GeneratingView: View {
    @Environment(GameCoordinator.self) private var coordinator

    private var generatedCount: Int {
        coordinator.currentRound?.submissions.values
            .filter { $0.generatedImageURL != nil }.count ?? 0
    }

    private var totalCount: Int {
        coordinator.currentRound?.submissions.count ?? 0
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Round \(coordinator.session?.roundNumber ?? 0)")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let round = coordinator.currentRound {
                AsyncImage(url: URL(string: round.greenCardURL)) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.clear
                }
                .frame(maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(0.6)
            }

            ProgressView()
                .scaleEffect(1.5)

            Text("Generating Images...")
                .font(.title2.bold())

            Text("\(generatedCount) of \(totalCount) ready")
                .foregroundStyle(.secondary)

            Text("Images are being created by AI based on player prompts.\nThis may take a moment.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            ScoreBar(players: coordinator.players)
        }
        .padding()
    }
}
