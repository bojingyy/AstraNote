import SwiftUI
import AstraCore

struct SettingsView: View {
    let loadSettingsAction: () async -> AppSettings
    let saveSettingsAction: (AppSettings) async throws -> Void
    let updateBiometricAction: (Bool) async throws -> Void
    let installedPluginsAction: () async -> [InstalledPlugin]
    let setPluginEnabledAction: (String, Bool) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var settings = AppSettings(
        lockTimeoutSeconds: 300,
        telemetryEnabled: false,
        pluginsEnabled: true,
        biometricUnlockEnabled: false
    )
    @State private var installedPlugins: [InstalledPlugin] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2)
                .bold()

            Stepper("Lock timeout: \(settings.lockTimeoutSeconds) seconds", value: Binding(
                get: { settings.lockTimeoutSeconds },
                set: { settings = AppSettings(
                    lockTimeoutSeconds: $0,
                    telemetryEnabled: settings.telemetryEnabled,
                    pluginsEnabled: settings.pluginsEnabled,
                    biometricUnlockEnabled: settings.biometricUnlockEnabled
                ) }
            ), in: 30...3600, step: 30)

            Toggle("Telemetry opt-in", isOn: Binding(
                get: { settings.telemetryEnabled },
                set: { settings = AppSettings(
                    lockTimeoutSeconds: settings.lockTimeoutSeconds,
                    telemetryEnabled: $0,
                    pluginsEnabled: settings.pluginsEnabled,
                    biometricUnlockEnabled: settings.biometricUnlockEnabled
                ) }
            ))

            Toggle("Enable plugins", isOn: Binding(
                get: { settings.pluginsEnabled },
                set: { settings = AppSettings(
                    lockTimeoutSeconds: settings.lockTimeoutSeconds,
                    telemetryEnabled: settings.telemetryEnabled,
                    pluginsEnabled: $0,
                    biometricUnlockEnabled: settings.biometricUnlockEnabled
                ) }
            ))

            Toggle("Enable biometric unlock", isOn: Binding(
                get: { settings.biometricUnlockEnabled },
                set: { newValue in
                    settings = AppSettings(
                        lockTimeoutSeconds: settings.lockTimeoutSeconds,
                        telemetryEnabled: settings.telemetryEnabled,
                        pluginsEnabled: settings.pluginsEnabled,
                        biometricUnlockEnabled: newValue
                    )
                    Task {
                        do {
                            try await updateBiometricAction(newValue)
                        } catch {
                            errorMessage = String(describing: error)
                        }
                    }
                }
            ))

            PluginStoreView(plugins: installedPlugins, setPluginEnabledAction: setPluginEnabledAction)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    Task {
                        do {
                            try await saveSettingsAction(settings)
                            dismiss()
                        } catch {
                            errorMessage = String(describing: error)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 420)
        .task {
            settings = await loadSettingsAction()
            installedPlugins = await installedPluginsAction()
        }
    }
}
