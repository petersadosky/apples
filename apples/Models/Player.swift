import Foundation

struct Player: Codable, Identifiable, Sendable {
    var id: String
    var name: String
    var score: Int

    init(id: String, name: String, score: Int = 0) {
        self.id = id
        self.name = name
        self.score = score
    }
}
