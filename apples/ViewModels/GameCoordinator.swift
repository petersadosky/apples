import Foundation
import Observation

@Observable
final class GameCoordinator {
    let authService: AuthService
    private let firestore: FirestoreService
    private let imageService = ImageGenerationService()

    // MARK: - Observable State (updated via Firestore listeners)

    var session: GameSession?
    var players: [Player] = []
    var currentRound: Round?
    var lobbySessions: [GameSession] = []
    var playerName: String = ""
    var error: String?

    // MARK: - Computed

    var isHost: Bool { session?.hostId == authService.currentUserId }
    var currentPlayerId: String? { authService.currentUserId }
    var isFinished: Bool { session?.state == .finished }

    var currentPlayer: Player? {
        guard let id = currentPlayerId else { return nil }
        return players.first { $0.id == id }
    }

    // MARK: - Listener Tasks

    private var sessionTask: Task<Void, Never>?
    private var playersTask: Task<Void, Never>?
    private var roundTask: Task<Void, Never>?
    private var lobbyTask: Task<Void, Never>?
    private var observedRoundId: String?
    private var isAutoAdvancing = false

    init(authService: AuthService, firestoreService: FirestoreService) {
        self.authService = authService
        self.firestore = firestoreService
    }

    // MARK: - Lobby

    func startObservingLobby() {
        lobbyTask?.cancel()
        lobbyTask = Task { [firestore] in
            for await sessions in firestore.lobbySessionsStream() {
                self.lobbySessions = sessions
            }
        }
    }

    func stopObservingLobby() {
        lobbyTask?.cancel()
        lobbyTask = nil
        lobbySessions = []
    }

    // MARK: - Session Lifecycle

    func createSession() async throws -> String {
        guard let userId = authService.currentUserId else {
            throw CoordinatorError.notSignedIn
        }
        let session = GameSession(hostId: userId)
        try await firestore.createSession(session)
        let player = Player(id: userId, name: playerName)
        try await firestore.addPlayer(player, toSession: session.id)
        stopObservingLobby()
        startObserving(sessionId: session.id)
        return session.id
    }

    func joinSession(_ sessionId: String) async throws {
        guard let userId = authService.currentUserId else {
            throw CoordinatorError.notSignedIn
        }
        let player = Player(id: userId, name: playerName)
        try await firestore.addPlayer(player, toSession: sessionId)
        stopObservingLobby()
        startObserving(sessionId: sessionId)
    }

    func leaveSession() async throws {
        guard let session, let playerId = currentPlayerId else { return }
        if isHost && session.state == .lobby {
            // Game never started — delete it entirely so it disappears for everyone
            try await firestore.deleteSession(session.id)
            cleanup()
            return
        }
        if isHost && session.state != .finished {
            try await endGame()
        }
        try await firestore.removePlayer(playerId: playerId, fromSession: session.id)
        cleanup()
    }

    func endGame() async throws {
        guard isHost else { throw CoordinatorError.notHost }
        guard let session, session.state != .finished else { return }
        try await firestore.updateSessionFields(sessionId: session.id, fields: [
            "state": GameState.finished.rawValue
        ])
    }

    // MARK: - Listeners

    func startObserving(sessionId: String) {
        sessionTask?.cancel()
        sessionTask = Task { [firestore] in
            for await session in firestore.sessionStream(id: sessionId) {
                self.session = session
                if let roundId = session.currentRoundId, roundId != self.observedRoundId {
                    self.startObservingRound(sessionId: sessionId, roundId: roundId)
                }
            }
        }

        playersTask?.cancel()
        playersTask = Task { [firestore] in
            for await players in firestore.playersStream(sessionId: sessionId) {
                self.players = players
                // Auto-end if fewer than 2 players during an active game
                if self.isHost,
                   let state = self.session?.state,
                   state != .lobby && state != .finished,
                   players.count < 2 {
                    try? await self.endGame()
                }
                // Re-check auto-advance when player count changes
                await self.autoAdvanceIfReady()
            }
        }
    }

    private func startObservingRound(sessionId: String, roundId: String) {
        observedRoundId = roundId
        roundTask?.cancel()
        roundTask = Task { [firestore] in
            for await round in firestore.roundStream(sessionId: sessionId, roundId: roundId) {
                self.currentRound = round
                await self.autoAdvanceIfReady()
            }
        }
    }

    // MARK: - Auto-advance (host only)

    private func autoAdvanceIfReady() async {
        guard isHost, !isAutoAdvancing, let session, let round = currentRound else { return }
        guard !players.isEmpty else { return }

        let shouldAdvance: Bool
        switch session.state {
        case .prompting:
            shouldAdvance = players.allSatisfy { round.submissions[$0.id] != nil }
        case .generating:
            shouldAdvance = !round.submissions.isEmpty
                && round.submissions.values.allSatisfy { $0.generatedImageURL != nil }
        case .voting:
            shouldAdvance = players.allSatisfy { round.votes[$0.id] != nil }
        default:
            shouldAdvance = false
        }

        guard shouldAdvance else { return }
        isAutoAdvancing = true
        defer { isAutoAdvancing = false }

        do {
            try await advanceState()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Host Actions

    func startGame() async throws {
        guard isHost else { throw CoordinatorError.notHost }
        guard let session else { throw CoordinatorError.noSession }
        guard players.count >= 2, players.count <= 4 else {
            throw CoordinatorError.invalidPlayerCount
        }

        let round = makeNewRound()
        try await firestore.createRound(round, inSession: session.id)
        try await firestore.updateSessionFields(sessionId: session.id, fields: [
            "state": GameState.prompting.rawValue,
            "currentRoundId": round.id,
            "roundNumber": 1
        ])
    }

    func advanceState() async throws {
        guard isHost else { throw CoordinatorError.notHost }
        guard let session else { throw CoordinatorError.noSession }

        switch session.state {
        case .prompting:
            guard let round = currentRound,
                  players.allSatisfy({ round.submissions[$0.id] != nil }) else {
                throw CoordinatorError.notAllPlayersSubmitted
            }
            let allGenerated = round.submissions.values.allSatisfy { $0.generatedImageURL != nil }
            if allGenerated {
                // All images ready — skip generating, go straight to voting
                try await firestore.updateSessionFields(sessionId: session.id, fields: [
                    "state": GameState.voting.rawValue
                ])
            } else {
                try await firestore.updateSessionFields(sessionId: session.id, fields: [
                    "state": GameState.generating.rawValue
                ])
            }

        case .generating:
            guard let round = currentRound else { throw CoordinatorError.noRound }
            let allGenerated = round.submissions.values.allSatisfy { $0.generatedImageURL != nil }
            guard allGenerated else { throw CoordinatorError.notAllImagesGenerated }
            try await firestore.updateSessionFields(sessionId: session.id, fields: [
                "state": GameState.voting.rawValue
            ])

        case .voting:
            guard let round = currentRound,
                  players.allSatisfy({ round.votes[$0.id] != nil }) else {
                throw CoordinatorError.notAllPlayersVoted
            }
            let winnerIds = tallyWinners(from: round)
            var someoneWon = false
            if !winnerIds.isEmpty {
                try await firestore.updateRoundField(
                    sessionId: session.id, roundId: round.id,
                    field: "winnerPlayerIds", value: winnerIds
                )
                for winnerId in winnerIds {
                    if let player = players.first(where: { $0.id == winnerId }) {
                        let newScore = player.score + 1
                        try await firestore.updatePlayerScore(
                            sessionId: session.id, playerId: winnerId,
                            score: newScore
                        )
                        if newScore >= session.winningScore {
                            someoneWon = true
                        }
                    }
                }
            }
            try await firestore.updateSessionFields(sessionId: session.id, fields: [
                "state": someoneWon ? GameState.finished.rawValue : GameState.results.rawValue
            ])

        case .results:
            if players.contains(where: { $0.score >= session.winningScore }) {
                try await firestore.updateSessionFields(sessionId: session.id, fields: [
                    "state": GameState.finished.rawValue
                ])
            } else {
                let nextNumber = session.roundNumber + 1
                let round = makeNewRound()
                try await firestore.createRound(round, inSession: session.id)
                try await firestore.updateSessionFields(sessionId: session.id, fields: [
                    "state": GameState.prompting.rawValue,
                    "currentRoundId": round.id,
                    "roundNumber": nextNumber
                ])
            }

        default:
            break
        }
    }

    // MARK: - Player Actions

    func submitPrompt(_ prompt: String) async throws {
        guard let session, session.state == .prompting else { throw CoordinatorError.wrongState }
        guard let playerId = currentPlayerId else { throw CoordinatorError.notSignedIn }
        guard let round = currentRound, round.submissions[playerId] == nil else {
            throw CoordinatorError.alreadySubmitted
        }

        let submission = Submission(playerId: playerId, prompt: prompt, submittedAt: .now)
        try await firestore.addSubmission(submission, roundId: round.id, sessionId: session.id)

        // Generate image in background, then write URL to Firestore.
        // The round listener picks up the change on all clients.
        // On total failure after retries, write a placeholder so the game doesn't stall.
        let sid = session.id
        let rid = round.id
        Task { [imageService, firestore] in
            do {
                let imageURL = try await imageService.generateImage(prompt: prompt)
                try await firestore.updateSubmissionImageURL(
                    sessionId: sid, roundId: rid,
                    playerId: playerId, imageURL: imageURL
                )
            } catch {
                self.error = "Image generation failed: \(error.localizedDescription)"
                // Write a failure marker so generating phase can still advance
                try? await firestore.updateSubmissionImageURL(
                    sessionId: sid, roundId: rid,
                    playerId: playerId, imageURL: "generation_failed"
                )
            }
        }
    }

    func submitVote(for votedForPlayerId: String) async throws {
        guard let session, session.state == .voting else { throw CoordinatorError.wrongState }
        guard let playerId = currentPlayerId else { throw CoordinatorError.notSignedIn }
        guard playerId != votedForPlayerId else { throw CoordinatorError.cannotVoteForSelf }
        guard let round = currentRound,
              round.votes[playerId] == nil,
              round.submissions[votedForPlayerId] != nil else {
            throw CoordinatorError.alreadyVoted
        }

        let vote = Vote(voterPlayerId: playerId, votedForPlayerId: votedForPlayerId, createdAt: .now)
        try await firestore.addVote(vote, roundId: round.id, sessionId: session.id)
    }

    // MARK: - Cleanup

    func cleanup() {
        sessionTask?.cancel()
        playersTask?.cancel()
        roundTask?.cancel()
        lobbyTask?.cancel()
        session = nil
        players = []
        currentRound = nil
        lobbySessions = []
        observedRoundId = nil
    }

    // MARK: - Helpers

    private func makeNewRound() -> Round {
        let seed = UUID().uuidString.prefix(8)
        let greenCardURL = "https://picsum.photos/seed/\(seed)/400/400"
        return Round(greenCardURL: greenCardURL)
    }

    private func tallyWinners(from round: Round) -> [String] {
        var voteCounts: [String: Int] = [:]
        for vote in round.votes.values {
            voteCounts[vote.votedForPlayerId, default: 0] += 1
        }
        guard let maxVotes = voteCounts.values.max() else { return [] }
        return voteCounts.filter { $0.value == maxVotes }.map(\.key)
    }

    // MARK: - Errors

    enum CoordinatorError: LocalizedError {
        case notSignedIn
        case notHost
        case noSession
        case noRound
        case invalidPlayerCount
        case notAllPlayersSubmitted
        case notAllImagesGenerated
        case notAllPlayersVoted
        case alreadySubmitted
        case alreadyVoted
        case cannotVoteForSelf
        case wrongState

        var errorDescription: String? {
            switch self {
            case .notSignedIn: "Not signed in"
            case .notHost: "Only the host can perform this action"
            case .noSession: "No active session"
            case .noRound: "No active round"
            case .invalidPlayerCount: "Need 2-4 players to start"
            case .notAllPlayersSubmitted: "Waiting for all players to submit"
            case .notAllImagesGenerated: "Waiting for all images to generate"
            case .notAllPlayersVoted: "Waiting for all players to vote"
            case .alreadySubmitted: "Already submitted this round"
            case .alreadyVoted: "Already voted this round"
            case .cannotVoteForSelf: "Cannot vote for your own image"
            case .wrongState: "Action not available in current state"
            }
        }
    }
}
