import Foundation

public protocol PluginBundleRepositoryProtocol: Sendable {
    func upsert(_ bundle: StoredPluginBundleRecord) async throws
    func fetch(pluginId: String) async -> StoredPluginBundleRecord?
    func remove(pluginId: String) async throws -> Bool
}

public actor PluginBundleRepository: PluginBundleRepositoryProtocol {
    private let database: DatabaseProvider

    public init(database: DatabaseProvider) {
        self.database = database
    }

    public func upsert(_ bundle: StoredPluginBundleRecord) async throws {
        try await database.transaction { state in
            state.pluginBundles[bundle.pluginId] = bundle
        }
    }

    public func fetch(pluginId: String) async -> StoredPluginBundleRecord? {
        await database.read { $0.pluginBundles[pluginId] }
    }

    public func remove(pluginId: String) async throws -> Bool {
        try await database.transaction { state in
            guard state.pluginBundles.removeValue(forKey: pluginId) != nil else {
                return false
            }
            return true
        }
    }
}
