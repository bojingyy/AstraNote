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

    public func update(lockTimeoutSeconds: Int, telemetryEnabled: Bool, pluginsEnabled: Bool) async throws {
        guard (30...3600).contains(lockTimeoutSeconds) else {
            throw SettingsServiceError.invalidLockTimeout
        }
        let settings = StoredSettingsRecord(
            lockTimeoutSeconds: lockTimeoutSeconds,
            telemetryEnabled: telemetryEnabled,
            pluginsEnabled: pluginsEnabled
        )
        try await repository.updateSettings(settings)
    }
}
