import SwiftUI

struct ScoreBar: View {
    let players: [Player]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(players) { player in
                VStack(spacing: 2) {
                    Text(player.name)
                        .font(.caption2)
                        .lineLimit(1)
                    Text("\(player.score)")
                        .font(.caption.bold())
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
