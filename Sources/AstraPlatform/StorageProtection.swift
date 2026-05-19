import Foundation

public enum StorageProtectionClass: String, Sendable, Equatable {
    case standard
    case completeUntilFirstUserAuthentication
    case complete
}

public protocol StorageProtecting: Sendable {
    func protect(path: String, classification: StorageProtectionClass) async throws
    func protectionClass(for path: String) async -> StorageProtectionClass?
}

public actor InMemoryStorageProtection: StorageProtecting {
    private var protections: [String: StorageProtectionClass] = [:]

    public init() {}

    public func protect(path: String, classification: StorageProtectionClass) async throws {
        protections[path] = classification
    }

    public func protectionClass(for path: String) async -> StorageProtectionClass? {
        protections[path]
    }
}
