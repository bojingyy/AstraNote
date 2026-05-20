import SwiftUI
import AstraCore

struct UnlockView: View {
    private enum FocusField: Hashable {
        case passphrase
        case confirmPassphrase
    }

    @ObservedObject var coordinator: AppCoordinator
    let createAction: (String) async throws -> Void
    let unlockAction: (String) async throws -> Void
    let biometricUnlockAction: (() async throws -> Void)?

    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: FocusField?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(coordinator.sessionState == .firstLaunchSetup ? "Create Passphrase" : "Unlock AstraNotes")
                .font(.title)
                .bold()

            SecureField("Passphrase", text: $passphrase)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
                .focused($focusedField, equals: .passphrase)
                .onSubmit {
                    if coordinator.sessionState == .firstLaunchSetup {
                        focusedField = .confirmPassphrase
                    } else {
                        Task {
                            await submit()
                        }
                    }
                }

            if coordinator.sessionState == .firstLaunchSetup {
                SecureField("Confirm Passphrase", text: $confirmPassphrase)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .confirmPassphrase)
                    .onSubmit {
                        Task {
                            await submit()
                        }
                    }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            Button(coordinator.sessionState == .firstLaunchSetup ? "Create and Unlock" : "Unlock") {
                Task {
                    await submit()
                }
            }
            .buttonStyle(.borderedProminent)

            if coordinator.sessionState != .firstLaunchSetup, let biometricUnlockAction {
                Button("Unlock with Biometrics") {
                    Task {
                        do {
                            errorMessage = nil
                            try await biometricUnlockAction()
                        } catch {
                            errorMessage = String(describing: error)
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 420)
        .defaultFocus($focusedField, .passphrase)
        .task(id: coordinator.sessionState) {
            // Defer focus assignment until the view hierarchy is ready.
            await Task.yield()
            focusedField = .passphrase
        }
    }

    private func submit() async {
        do {
            errorMessage = nil
            if coordinator.sessionState == .firstLaunchSetup {
                guard !passphrase.isEmpty, passphrase == confirmPassphrase else {
                    errorMessage = "Passphrase must be non-empty and match confirmation."
                    return
                }
                try await createAction(passphrase)
            } else {
                try await unlockAction(passphrase)
            }
            passphrase = ""
            confirmPassphrase = ""
        } catch {
            switch error {
            case KeyManagerError.invalidPassphrase:
                errorMessage = "Invalid passphrase. Please try again."
            case KeyManagerError.lockoutActive(let remainingSeconds):
                errorMessage = "Too many attempts. Try again in \(remainingSeconds) seconds."
            case KeyManagerError.passphraseNotInitialized:
                errorMessage = "No passphrase found. Please restart and create a passphrase."
            default:
                errorMessage = String(describing: error)
            }
        }
    }
}
