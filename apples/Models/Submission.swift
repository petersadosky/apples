import Foundation

struct Submission: Codable, Sendable {
    var playerId: String
    var prompt: String
    var generatedImageURL: String?
    var submittedAt: Date
}
