import Foundation

public enum AuditLevel: String, Sendable, Codable {
    case info
    case warning
    case error
}

public struct AuditLogEntry: Sendable, Codable, Equatable {
    public let timestamp: Date
    public let level: AuditLevel
    public let event: String
    public let metadata: [String: String]

    public init(timestamp: Date, level: AuditLevel, event: String, metadata: [String: String] = [:]) {
        self.timestamp = timestamp
        self.level = level
        self.event = event
        self.metadata = metadata
    }
}

public protocol AuditLogging: Sendable {
    func log(level: AuditLevel, event: String, metadata: [String: String]) async
    func entries() async -> [AuditLogEntry]
}

public actor InMemoryAuditLogger: AuditLogging {
    private let timeProvider: TimeProvider
    private var storage: [AuditLogEntry] = []

    public init(timeProvider: TimeProvider = SystemTimeProvider()) {
        self.timeProvider = timeProvider
    }

    public func log(level: AuditLevel, event: String, metadata: [String: String] = [:]) async {
        let sanitized = sanitize(metadata: metadata)
        storage.append(
            AuditLogEntry(
                timestamp: timeProvider.now(),
                level: level,
                event: event,
                metadata: sanitized
            )
        )
    }

    public func entries() async -> [AuditLogEntry] {
        storage
    }

    private func sanitize(metadata: [String: String]) -> [String: String] {
        let blockedKeys: Set<String> = ["content", "title", "passphrase", "plaintext", "cipherKey"]
        return metadata.reduce(into: [:]) { partialResult, pair in
            if blockedKeys.contains(pair.key.lowercased()) {
                partialResult[pair.key] = "<redacted>"
            } else {
                partialResult[pair.key] = pair.value
            }
        }
    }
}
