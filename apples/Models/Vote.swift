import Foundation

struct Vote: Codable, Sendable {
    var voterPlayerId: String
    var votedForPlayerId: String
    var createdAt: Date
}
