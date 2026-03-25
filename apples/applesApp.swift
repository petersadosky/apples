import SwiftUI
import FirebaseCore

@main
struct applesApp: App {
    @State private var authService: AuthService
    @State private var coordinator: GameCoordinator

    init() {
        FirebaseApp.configure()
        let auth = AuthService()
        let firestore = FirestoreService()
        _authService = State(initialValue: auth)
        _coordinator = State(initialValue: GameCoordinator(authService: auth, firestoreService: firestore))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(coordinator)
        }
    }
}
