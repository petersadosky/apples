import SwiftUI

struct GameView: View {
    @Environment(GameCoordinator.self) private var coordinator
    @State private var showLeaveConfirmation = false

    private var isInActiveGame: Bool {
        guard let state = coordinator.session?.state else { return false }
        return state != .lobby && state != .finished
    }

    var body: some View {
        NavigationStack {
            Group {
                switch coordinator.session?.state {
                case .lobby:
                    WaitingRoomView()
                case .prompting:
                    PromptView()
                case .generating:
                    GeneratingView()
                case .voting:
                    VotingView()
                case .results, .finished:
                    ResultsView()
                case nil:
                    ProgressView()
                }
            }
            .animation(.default, value: coordinator.session?.state)
            .toolbar {
                if isInActiveGame {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showLeaveConfirmation = true
                        } label: {
                            Image(systemName: "xmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .confirmationDialog(
                coordinator.isHost ? "End Game?" : "Leave Game?",
                isPresented: $showLeaveConfirmation,
                titleVisibility: .visible
            ) {
                Button(coordinator.isHost ? "End Game" : "Leave Game", role: .destructive) {
                    Task {
                        if coordinator.isHost {
                            try? await coordinator.endGame()
                        } else {
                            try? await coordinator.leaveSession()
                        }
                    }
                }
            } message: {
                Text(coordinator.isHost
                    ? "This will end the game for all players."
                    : "You will be removed from the game.")
            }
        }
    }
}
