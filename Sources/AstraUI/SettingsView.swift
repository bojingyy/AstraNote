import SwiftUI
import AstraCore

struct SettingsView: View {
    let loadSettingsAction: () async -> AppSettings
    let saveSettingsAction: (AppSettings) async throws -> Void
    let updateBiometricAction: (Bool) async throws -> Void
    let installedPluginsAction: () async -> [InstalledPlugin]
    let setPluginEnabledAction: (String, Bool) async throws -> Void
    let changePassphraseAction: (String, String) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var settings = AppSettings(
        pluginsEnabled: true,
        biometricUnlockEnabled: false
    )
    @State private var installedPlugins: [InstalledPlugin] = []
    @State private var errorMessage: String?

    @State private var currentPassphrase = ""
    @State private var newPassphrase = ""
    @State private var confirmNewPassphrase = ""
    @State private var passphraseChangeError: String?
    @State private var passphraseChangeSuccess: String?
    @State private var isChangingPassphrase = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2)
                .bold()

            Toggle("Enable plugins", isOn: Binding(
                get: { settings.pluginsEnabled },
                set: { settings = AppSettings(
                    pluginsEnabled: $0,
                    biometricUnlockEnabled: settings.biometricUnlockEnabled
                ) }
            ))

            Toggle("Enable biometric unlock", isOn: Binding(
                get: { settings.biometricUnlockEnabled },
                set: { newValue in
                    settings = AppSettings(
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

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Change Passphrase")
                    .font(.headline)

                SecureField("Current passphrase", text: $currentPassphrase)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)

                SecureField("New passphrase", text: $newPassphrase)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)

                SecureField("Confirm new passphrase", text: $confirmNewPassphrase)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)

                if let passphraseChangeError {
                    Text(passphraseChangeError)
                        .foregroundStyle(.red)
                }
                if let passphraseChangeSuccess {
                    Text(passphraseChangeSuccess)
                        .foregroundStyle(.green)
                }

                Button("Change Passphrase") {
                    Task {
                        await submitPassphraseChange()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isChangingPassphrase)
            }

            Divider()

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
        .frame(minWidth: 420, minHeight: 320)
        .task {
            settings = await loadSettingsAction()
            installedPlugins = await installedPluginsAction()
        }
    }

    private func submitPassphraseChange() async {
        passphraseChangeError = nil
        passphraseChangeSuccess = nil

        guard !newPassphrase.isEmpty, newPassphrase == confirmNewPassphrase else {
            passphraseChangeError = "New passphrase must be non-empty and match confirmation."
            return
        }

        isChangingPassphrase = true
        defer { isChangingPassphrase = false }

        do {
            try await changePassphraseAction(currentPassphrase, newPassphrase)
            currentPassphrase = ""
            newPassphrase = ""
            confirmNewPassphrase = ""
            passphraseChangeSuccess = "Passphrase changed successfully."
        } catch {
            switch error {
            case KeyManagerError.invalidPassphrase:
                passphraseChangeError = "Current passphrase is incorrect."
            case KeyManagerError.identicalPassphrase:
                passphraseChangeError = "New passphrase must be different from the current one."
            case KeyManagerError.passphraseNotInitialized:
                passphraseChangeError = "No passphrase found. Please restart and create a passphrase."
            case KeyManagerError.migrationUnavailable:
                passphraseChangeError = "Changing the passphrase is unavailable right now."
            default:
                passphraseChangeError = String(describing: error)
            }
        }
    }
}
