import Foundation
import AstraData

public enum SettingsServiceError: Error, Equatable {
    case invalidLockTimeout
}

public actor SettingsService {
    private let repository: SettingsRepositoryProtocol

    public init(repository: SettingsRepositoryProtocol) {
        self.repository = repository
    }

    public func load() async -> AppSettings {
        AppSettings(stored: await repository.getSettings())
    }

    public func update(
        lockTimeoutSeconds: Int,
        telemetryEnabled: Bool,
        pluginsEnabled: Bool,
        biometricUnlockEnabled: Bool? = nil
    ) async throws {
        guard (30...3600).contains(lockTimeoutSeconds) else {
            throw SettingsServiceError.invalidLockTimeout
        }
        let current = await repository.getSettings()
        let settings = StoredSettingsRecord(
            lockTimeoutSeconds: lockTimeoutSeconds,
            telemetryEnabled: telemetryEnabled,
            pluginsEnabled: pluginsEnabled,
            biometricUnlockEnabled: biometricUnlockEnabled ?? current.biometricUnlockEnabled
        )
        try await repository.updateSettings(settings)
    }

    public func setBiometricUnlockEnabled(_ enabled: Bool) async throws {
        let current = await repository.getSettings()
        try await update(
            lockTimeoutSeconds: current.lockTimeoutSeconds,
            telemetryEnabled: current.telemetryEnabled,
            pluginsEnabled: current.pluginsEnabled,
            biometricUnlockEnabled: enabled
        )
    }
}
