import Foundation

public protocol TimeProvider: Sendable {
    func now() -> Date
}

public struct SystemTimeProvider: TimeProvider {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

public final class MutableTimeProvider: @unchecked Sendable, TimeProvider {
    private let lock = NSLock()
    private var current: Date

    public init(now: Date) {
        self.current = now
    }

    public func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    public func set(now: Date) {
        lock.lock()
        current = now
        lock.unlock()
    }

    public func advance(seconds: TimeInterval) {
        lock.lock()
        current = current.addingTimeInterval(seconds)
        lock.unlock()
    }
}
