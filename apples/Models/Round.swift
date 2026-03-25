import Foundation

struct Round: Codable, Identifiable, Sendable {
    var id: String
    var greenCardURL: String
    /// Keyed by playerId — enforces one submission per player.
    var submissions: [String: Submission]
    /// Keyed by voterPlayerId — enforces one vote per player.
    var votes: [String: Vote]
    var winnerPlayerIds: [String]
    var createdAt: Date

    init(id: String = UUID().uuidString, greenCardURL: String, createdAt: Date = .now) {
        self.id = id
        self.greenCardURL = greenCardURL
        self.submissions = [:]
        self.votes = [:]
        self.winnerPlayerIds = []
        self.createdAt = createdAt
    }
}
