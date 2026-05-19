import Foundation

public protocol SettingsRepositoryProtocol: Sendable {
    func getSettings() async -> StoredSettingsRecord
    func updateSettings(_ settings: StoredSettingsRecord) async throws

    func loadCredentials() async -> StoredCredentialState?
    func saveCredentials(_ credentials: StoredCredentialState) async throws

    func loadLastKnownUTC() async -> Date?
    func saveLastKnownUTC(_ value: Date?) async throws

    func loadRollbackGuardUntilUTC() async -> Date?
    func saveRollbackGuardUntilUTC(_ value: Date?) async throws
}

public actor SettingsRepository: SettingsRepositoryProtocol {
    private let database: DatabaseProvider

    public init(database: DatabaseProvider) {
        self.database = database
    }

    public func getSettings() async -> StoredSettingsRecord {
        await database.read { $0.settings }
    }

    public func updateSettings(_ settings: StoredSettingsRecord) async throws {
        try await database.transaction { state in
            state.settings = settings
        }
    }

    public func loadCredentials() async -> StoredCredentialState? {
        await database.read { $0.credentials }
    }

    public func saveCredentials(_ credentials: StoredCredentialState) async throws {
        try await database.transaction { state in
            state.credentials = credentials
        }
    }

    public func loadLastKnownUTC() async -> Date? {
        await database.read { $0.lastKnownUTC }
    }

    public func saveLastKnownUTC(_ value: Date?) async throws {
        try await database.transaction { state in
            state.lastKnownUTC = value
        }
    }

    public func loadRollbackGuardUntilUTC() async -> Date? {
        await database.read { $0.rollbackGuardUntilUTC }
    }

    public func saveRollbackGuardUntilUTC(_ value: Date?) async throws {
        try await database.transaction { state in
            state.rollbackGuardUntilUTC = value
        }
    }
}
