import SwiftUI
import AstraCore

struct ContentView: View {
    @StateObject private var env = AppEnvironment()

    var body: some View {
        Group {
            switch env.coordinator.sessionState {
            case .firstLaunchSetup, .locked:
                UnlockView(
                    coordinator: env.coordinator,
                    createAction: { passphrase in
                        try await env.coordinator.createInitialPassphraseAndUnlock(passphrase)
                    },
                    unlockAction: { passphrase in
                        try await env.coordinator.unlock(passphrase: passphrase)
                    }
                )
            case .unlocked:
                NotesWorkspaceView(
                    searchAction: { query in
                        await env.noteSearchService.searchTitle(query: query, isUnlocked: true)
                    },
                    lockAction: {
                        await env.coordinator.lockNow()
                    }
                )
            }
        }
        .task {
            await env.coordinator.start()
        }
    }
}
