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
                    },
                    biometricUnlockAction: {
                        try await env.coordinator.unlockWithBiometrics()
                    }
                )
            case .unlocked:
                NotesWorkspaceView(
                    searchAction: { query in
                        await env.noteSearchService.searchTitle(query: query, isUnlocked: true)
                    },
                    lockAction: {
                        await env.coordinator.lockNow()
                    },
                    loadSettingsAction: {
                        await env.settingsService.load()
                    },
                    saveSettingsAction: { settings in
                        try await env.settingsService.update(
                            lockTimeoutSeconds: settings.lockTimeoutSeconds,
                            telemetryEnabled: settings.telemetryEnabled,
                            pluginsEnabled: settings.pluginsEnabled,
                            biometricUnlockEnabled: settings.biometricUnlockEnabled
                        )
                    },
                    updateBiometricAction: { isEnabled in
                        try await env.coordinator.updateBiometricUnlock(enabled: isEnabled)
                    },
                    installedPluginsAction: {
                        await env.pluginService.listInstalled()
                    },
                    setPluginEnabledAction: { pluginId, isEnabled in
                        try await env.pluginService.setEnabled(pluginId: pluginId, isEnabled: isEnabled)
                    }
                )
            }
        }
        .task {
            await env.coordinator.start()
            env.coordinator.bind(platformIntegration: env.platformIntegration)
        }
    }
}
