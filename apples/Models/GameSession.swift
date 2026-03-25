import Foundation

struct GameSession: Codable, Identifiable, Sendable {
    var id: String
    var name: String
    var hostId: String
    var state: GameState
    var currentRoundId: String?
    var roundNumber: Int
    var winningScore: Int
    var playerCount: Int
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String = SessionNames.random(),
        hostId: String,
        state: GameState = .lobby,
        winningScore: Int = 3,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.hostId = hostId
        self.state = state
        self.currentRoundId = nil
        self.roundNumber = 0
        self.winningScore = winningScore
        self.playerCount = 0
        self.createdAt = createdAt
    }
}
