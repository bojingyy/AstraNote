import Foundation

public protocol PluginMetadataRepositoryProtocol: Sendable {
    func upsert(_ metadata: StoredPluginMetadataRecord) async throws
    func fetch(pluginId: String) async -> StoredPluginMetadataRecord?
    func listAll() async -> [StoredPluginMetadataRecord]
    func setEnabled(pluginId: String, isEnabled: Bool) async throws -> StoredPluginMetadataRecord?
    func remove(pluginId: String) async throws -> Bool
}

public actor PluginMetadataRepository: PluginMetadataRepositoryProtocol {
    private let database: DatabaseProvider

    public init(database: DatabaseProvider) {
        self.database = database
    }

    public func upsert(_ metadata: StoredPluginMetadataRecord) async throws {
        try await database.transaction { state in
            state.pluginMetadata[metadata.pluginId] = metadata
        }
    }

    public func fetch(pluginId: String) async -> StoredPluginMetadataRecord? {
        await database.read { $0.pluginMetadata[pluginId] }
    }

    public func listAll() async -> [StoredPluginMetadataRecord] {
        await database.read { state in
            state.pluginMetadata.values.sorted {
                if $0.displayName == $1.displayName {
                    return $0.installedAt < $1.installedAt
                }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
    }

    public func setEnabled(pluginId: String, isEnabled: Bool) async throws -> StoredPluginMetadataRecord? {
        try await database.transaction { state in
            guard var metadata = state.pluginMetadata[pluginId] else {
                return nil
            }
            metadata.isEnabled = isEnabled
            state.pluginMetadata[pluginId] = metadata
            return metadata
        }
    }

    public func remove(pluginId: String) async throws -> Bool {
        try await database.transaction { state in
            guard state.pluginMetadata.removeValue(forKey: pluginId) != nil else {
                return false
            }
            return true
        }
    }
}
