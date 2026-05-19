import SwiftUI
import AstraCore

struct UnlockView: View {
    @ObservedObject var coordinator: AppCoordinator
    let createAction: (String) async throws -> Void
    let unlockAction: (String) async throws -> Void
    let biometricUnlockAction: (() async throws -> Void)?

    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(coordinator.sessionState == .firstLaunchSetup ? "Create Passphrase" : "Unlock AstraNotes")
                .font(.title)
                .bold()

            SecureField("Passphrase", text: $passphrase)
                .textFieldStyle(.roundedBorder)

            if coordinator.sessionState == .firstLaunchSetup {
                SecureField("Confirm Passphrase", text: $confirmPassphrase)
                    .textFieldStyle(.roundedBorder)
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
            errorMessage = String(describing: error)
        }
    }
}
