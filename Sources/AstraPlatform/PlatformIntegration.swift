import Foundation

public enum PlatformEvent: Sendable {
    case appDidBackground
    case appDidForeground
    case osWillSleep
    case osDidWake
    case userInteraction
}

public protocol PlatformIntegrationProtocol: Sendable {
    func publish(_ event: PlatformEvent) async
    func stream() -> AsyncStream<PlatformEvent>
}

public actor InMemoryPlatformIntegration: PlatformIntegrationProtocol {
    private var continuations: [AsyncStream<PlatformEvent>.Continuation] = []

    public init() {}

    public func publish(_ event: PlatformEvent) async {
        for continuation in continuations {
            continuation.yield(event)
        }
    }

    public nonisolated func stream() -> AsyncStream<PlatformEvent> {
        AsyncStream { continuation in
            Task {
                await self.register(continuation)
            }
        }
    }

    private func register(_ continuation: AsyncStream<PlatformEvent>.Continuation) {
        continuations.append(continuation)
    }
}
