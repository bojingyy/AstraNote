import SwiftUI
import AstraCore

struct NotesWorkspaceView: View {
    let searchAction: (String) async -> [NoteSearchResult]
    let lockAction: () async -> Void
    let loadSettingsAction: () async -> AppSettings
    let saveSettingsAction: (AppSettings) async throws -> Void
    let updateBiometricAction: (Bool) async throws -> Void
    let installedPluginsAction: () async -> [InstalledPlugin]
    let setPluginEnabledAction: (String, Bool) async throws -> Void

    @State private var query = ""
    @State private var results: [NoteSearchResult] = []
    @State private var isShowingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Search note titles", text: $query)
                    .textFieldStyle(.roundedBorder)
                Button("Search") {
                    Task {
                        results = await searchAction(query)
                    }
                }
                Button("Lock") {
                    Task {
                        await lockAction()
                    }
                }
                Button("Settings") {
                    isShowingSettings = true
                }
            }

            List(results, id: \.noteId) { result in
                HStack {
                    Text(result.isSecure ? "[Secure]" : "[Normal]")
                    Text(result.matchedTitle)
                }
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                loadSettingsAction: loadSettingsAction,
                saveSettingsAction: saveSettingsAction,
                updateBiometricAction: updateBiometricAction,
                installedPluginsAction: installedPluginsAction,
                setPluginEnabledAction: setPluginEnabledAction
            )
        }
    }
}
