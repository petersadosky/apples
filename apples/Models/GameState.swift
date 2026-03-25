import Foundation

enum GameState: String, Codable, Sendable {
    case lobby
    case prompting
    case generating
    case voting
    case results
    case finished

    /// Valid transitions from this state.
    var allowedTransitions: Set<GameState> {
        switch self {
        case .lobby:      return [.prompting, .finished]
        case .prompting:  return [.generating, .voting, .finished]
        case .generating: return [.voting, .finished]
        case .voting:     return [.results, .finished]
        case .results:    return [.prompting, .finished]
        case .finished:   return []
        }
    }

    func canTransition(to next: GameState) -> Bool {
        allowedTransitions.contains(next)
    }
}
