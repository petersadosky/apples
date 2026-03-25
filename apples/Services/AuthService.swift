import FirebaseAuth
import Observation

@Observable
final class AuthService {
    var currentUserId: String?
    var isSignedIn: Bool { currentUserId != nil }

    init() {
        currentUserId = Auth.auth().currentUser?.uid
    }

    func signInAnonymously() async throws -> String {
        let result = try await Auth.auth().signInAnonymously()
        let uid = result.user.uid
        currentUserId = uid
        return uid
    }

    func signOut() throws {
        try Auth.auth().signOut()
        currentUserId = nil
    }
}
