import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var auth
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        Group {
            if !auth.isSignedIn || coordinator.playerName.isEmpty {
                JoinScreen()
            } else if coordinator.session == nil {
                LobbyBrowserView()
            } else {
                GameView()
            }
        }
        .animation(.default, value: auth.isSignedIn)
        .animation(.default, value: coordinator.playerName.isEmpty)
        .animation(.default, value: coordinator.session?.id)
    }
}
