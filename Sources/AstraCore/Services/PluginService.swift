import Foundation
import AstraData
import AstraPlatform

public enum PluginServiceError: Error, Equatable {
    case invalidManifest
    case invalidBundle
    case pluginAlreadyInstalled
    case pluginNotFound
    case pluginsGloballyDisabled
    case pluginDisabled
    case handlerUnavailable
    case executionTimedOut
}

public actor PluginService {
    public typealias PluginActionHandler = @Sendable (PluginActionRequest) async throws -> PluginActionResult

    private let metadataRepository: PluginMetadataRepositoryProtocol
    private let bundleRepository: PluginBundleRepositoryProtocol
    private let settingsService: SettingsService
    private let logger: AuditLogging

    private var handlers: [String: PluginActionHandler] = [:]

    public init(
        metadataRepository: PluginMetadataRepositoryProtocol,
        bundleRepository: PluginBundleRepositoryProtocol,
        settingsService: SettingsService,
        logger: AuditLogging
    ) {
        self.metadataRepository = metadataRepository
        self.bundleRepository = bundleRepository
        self.settingsService = settingsService
        self.logger = logger
    }

    public func install(manifest: PluginManifest, bundleData: Data) async throws {
        guard Self.isValid(manifest: manifest) else {
            throw PluginServiceError.invalidManifest
        }
        guard !bundleData.isEmpty else {
            throw PluginServiceError.invalidBundle
        }
        guard await metadataRepository.fetch(pluginId: manifest.pluginId) == nil else {
            throw PluginServiceError.pluginAlreadyInstalled
        }

        let metadata = StoredPluginMetadataRecord(
            pluginId: manifest.pluginId,
            displayName: manifest.displayName,
            version: manifest.version,
            capabilities: manifest.capabilities,
            isEnabled: true,
            installedAt: Date()
        )
        try await metadataRepository.upsert(metadata)
        try await bundleRepository.upsert(StoredPluginBundleRecord(pluginId: manifest.pluginId, bundleData: bundleData))
        await logger.log(level: .info, event: "plugin_installed", metadata: ["pluginId": manifest.pluginId])
    }

    public func listInstalled() async -> [InstalledPlugin] {
        await metadataRepository.listAll().map(InstalledPlugin.init)
    }

    public func setEnabled(pluginId: String, isEnabled: Bool) async throws {
        guard try await metadataRepository.setEnabled(pluginId: pluginId, isEnabled: isEnabled) != nil else {
            throw PluginServiceError.pluginNotFound
        }
        await logger.log(
            level: .info,
            event: isEnabled ? "plugin_enabled" : "plugin_disabled",
            metadata: ["pluginId": pluginId]
        )
    }

    public func remove(pluginId: String) async throws {
        let removedMetadata = try await metadataRepository.remove(pluginId: pluginId)
        let removedBundle = try await bundleRepository.remove(pluginId: pluginId)
        handlers.removeValue(forKey: pluginId)
        guard removedMetadata || removedBundle else {
            throw PluginServiceError.pluginNotFound
        }
        await logger.log(level: .info, event: "plugin_removed", metadata: ["pluginId": pluginId])
    }

    public func registerHandler(pluginId: String, handler: @escaping PluginActionHandler) {
        handlers[pluginId] = handler
    }

    public func execute(
        pluginId: String,
        request: PluginActionRequest,
        timeout: Duration = .seconds(2)
    ) async throws -> PluginActionResult {
        let settings = await settingsService.load()
        guard settings.pluginsEnabled else {
            throw PluginServiceError.pluginsGloballyDisabled
        }
        guard let metadata = await metadataRepository.fetch(pluginId: pluginId) else {
            throw PluginServiceError.pluginNotFound
        }
        guard metadata.isEnabled else {
            throw PluginServiceError.pluginDisabled
        }
        guard await bundleRepository.fetch(pluginId: pluginId) != nil else {
            throw PluginServiceError.pluginNotFound
        }
        guard let handler = handlers[pluginId] else {
            throw PluginServiceError.handlerUnavailable
        }

        do {
            let result = try await withThrowingTaskGroup(of: PluginActionResult.self) { group in
                group.addTask {
                    try await handler(request)
                }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw PluginServiceError.executionTimedOut
                }

                let first = try await group.next()
                group.cancelAll()
                return first
            }

            guard let result else {
                throw PluginServiceError.executionTimedOut
            }
            await logger.log(level: .info, event: "plugin_executed", metadata: ["pluginId": pluginId, "action": request.action])
            return result
        } catch {
            await logger.log(level: .error, event: "plugin_execution_failed", metadata: ["pluginId": pluginId, "action": request.action])
            throw error
        }
    }

    private static func isValid(manifest: PluginManifest) -> Bool {
        !manifest.pluginId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !manifest.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !manifest.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
