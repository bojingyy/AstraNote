import Foundation
import AstraData

public actor SettingsService {
    private let repository: SettingsRepositoryProtocol

    public init(repository: SettingsRepositoryProtocol) {
        self.repository = repository
    }

    public func load() async -> AppSettings {
        AppSettings(stored: await repository.getSettings())
    }

    public func update(
        pluginsEnabled: Bool,
        biometricUnlockEnabled: Bool? = nil
    ) async throws {
        let current = await repository.getSettings()
        let settings = StoredSettingsRecord(
            pluginsEnabled: pluginsEnabled,
            biometricUnlockEnabled: biometricUnlockEnabled ?? current.biometricUnlockEnabled
        )
        try await repository.updateSettings(settings)
    }

    public func setBiometricUnlockEnabled(_ enabled: Bool) async throws {
        let current = await repository.getSettings()
        try await update(
            pluginsEnabled: current.pluginsEnabled,
            biometricUnlockEnabled: enabled
        )
    }
}
