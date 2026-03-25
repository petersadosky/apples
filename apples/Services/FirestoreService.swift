import FirebaseFirestore

final class FirestoreService {
    private let db = Firestore.firestore()

    // MARK: - Sessions

    func createSession(_ session: GameSession) async throws {
        let data = try Firestore.Encoder().encode(session)
        try await db.collection("sessions").document(session.id).setData(data)
    }

    func updateSessionFields(sessionId: String, fields: [String: Any]) async throws {
        try await db.collection("sessions").document(sessionId).updateData(fields)
    }

    func deleteSession(_ sessionId: String) async throws {
        try await db.collection("sessions").document(sessionId).delete()
    }

    func sessionStream(id: String) -> AsyncStream<GameSession> {
        AsyncStream { continuation in
            let listener = self.db.collection("sessions").document(id)
                .addSnapshotListener { snapshot, _ in
                    guard let snapshot,
                          let session = try? snapshot.data(as: GameSession.self) else { return }
                    continuation.yield(session)
                }
            continuation.onTermination = { @Sendable _ in listener.remove() }
        }
    }

    func lobbySessionsStream() -> AsyncStream<[GameSession]> {
        AsyncStream { continuation in
            let listener = self.db.collection("sessions")
                .whereField("state", isEqualTo: GameState.lobby.rawValue)
                .addSnapshotListener { snapshot, _ in
                    guard let documents = snapshot?.documents else { return }
                    let sessions = documents.compactMap { try? $0.data(as: GameSession.self) }
                    continuation.yield(sessions)
                }
            continuation.onTermination = { @Sendable _ in listener.remove() }
        }
    }

    // MARK: - Players

    func addPlayer(_ player: Player, toSession sessionId: String) async throws {
        let data = try Firestore.Encoder().encode(player)
        let sessionRef = db.collection("sessions").document(sessionId)
        try await sessionRef.collection("players").document(player.id).setData(data)
        try await sessionRef.updateData(["playerCount": FieldValue.increment(Int64(1))])
    }

    func removePlayer(playerId: String, fromSession sessionId: String) async throws {
        let sessionRef = db.collection("sessions").document(sessionId)
        try await sessionRef.collection("players").document(playerId).delete()
        try await sessionRef.updateData(["playerCount": FieldValue.increment(Int64(-1))])
    }

    func updatePlayerScore(sessionId: String, playerId: String, score: Int) async throws {
        try await db.collection("sessions").document(sessionId)
            .collection("players").document(playerId).updateData(["score": score])
    }

    func playersStream(sessionId: String) -> AsyncStream<[Player]> {
        AsyncStream { continuation in
            let listener = self.db.collection("sessions").document(sessionId)
                .collection("players")
                .addSnapshotListener { snapshot, _ in
                    guard let documents = snapshot?.documents else { return }
                    let players = documents.compactMap { try? $0.data(as: Player.self) }
                    continuation.yield(players)
                }
            continuation.onTermination = { @Sendable _ in listener.remove() }
        }
    }

    // MARK: - Rounds

    func createRound(_ round: Round, inSession sessionId: String) async throws {
        let data = try Firestore.Encoder().encode(round)
        try await db.collection("sessions").document(sessionId)
            .collection("rounds").document(round.id).setData(data)
    }

    func updateRoundField(sessionId: String, roundId: String, field: String, value: Any) async throws {
        try await db.collection("sessions").document(sessionId)
            .collection("rounds").document(roundId).updateData([field: value])
    }

    func roundStream(sessionId: String, roundId: String) -> AsyncStream<Round> {
        AsyncStream { continuation in
            let listener = self.db.collection("sessions").document(sessionId)
                .collection("rounds").document(roundId)
                .addSnapshotListener { snapshot, _ in
                    guard let snapshot,
                          let round = try? snapshot.data(as: Round.self) else { return }
                    continuation.yield(round)
                }
            continuation.onTermination = { @Sendable _ in listener.remove() }
        }
    }

    // MARK: - Submissions (nested field update on round doc)

    func addSubmission(_ submission: Submission, roundId: String, sessionId: String) async throws {
        let encoded = try Firestore.Encoder().encode(submission)
        try await db.collection("sessions").document(sessionId)
            .collection("rounds").document(roundId)
            .updateData(["submissions.\(submission.playerId)": encoded])
    }

    func updateSubmissionImageURL(sessionId: String, roundId: String, playerId: String, imageURL: String) async throws {
        try await db.collection("sessions").document(sessionId)
            .collection("rounds").document(roundId)
            .updateData(["submissions.\(playerId).generatedImageURL": imageURL])
    }

    // MARK: - Votes (nested field update on round doc)

    func addVote(_ vote: Vote, roundId: String, sessionId: String) async throws {
        let encoded = try Firestore.Encoder().encode(vote)
        try await db.collection("sessions").document(sessionId)
            .collection("rounds").document(roundId)
            .updateData(["votes.\(vote.voterPlayerId)": encoded])
    }
}
