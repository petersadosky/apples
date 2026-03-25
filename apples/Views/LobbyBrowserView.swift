import SwiftUI

struct LobbyBrowserView: View {
    @Environment(GameCoordinator.self) private var coordinator
    @State private var isCreating = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Group {
                if coordinator.lobbySessions.isEmpty {
                    ContentUnavailableView(
                        "No Games Yet",
                        systemImage: "gamecontroller",
                        description: Text("Create a new game to get started.")
                    )
                } else {
                    List(coordinator.lobbySessions) { session in
                        Button {
                            joinSession(session.id)
                        } label: {
                            LobbySessionRow(session: session)
                        }
                    }
                }
            }
            .navigationTitle("Apples to Apples")
            .toolbar {
                Button {
                    createSession()
                } label: {
                    Label("New Game", systemImage: "plus")
                }
                .disabled(isCreating)
            }
            .overlay {
                if isCreating {
                    ProgressView("Creating...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .task {
            coordinator.startObservingLobby()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func createSession() {
        isCreating = true
        Task {
            do {
                _ = try await coordinator.createSession()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isCreating = false
        }
    }

    private func joinSession(_ id: String) {
        Task {
            do {
                try await coordinator.joinSession(id)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct LobbySessionRow: View {
    let session: GameSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.headline)
                Text("Created \(session.createdAt, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label("\(session.playerCount)/4", systemImage: "person.2.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
    }
}
