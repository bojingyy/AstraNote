import Foundation

public struct ExpiryNotificationEvent: Sendable, Equatable {
    public let noteId: UUID
    public let deliveredAt: Date
    public let isForeground: Bool

    public init(noteId: UUID, deliveredAt: Date, isForeground: Bool) {
        self.noteId = noteId
        self.deliveredAt = deliveredAt
        self.isForeground = isForeground
    }
}

public protocol NotificationServiceProtocol: Sendable {
    func notifySecureNoteExpired(noteId: UUID, isForeground: Bool) async
    func history() async -> [ExpiryNotificationEvent]
}

public actor InMemoryNotificationService: NotificationServiceProtocol {
    private let timeProvider: TimeProvider
    private var events: [ExpiryNotificationEvent] = []

    public init(timeProvider: TimeProvider = SystemTimeProvider()) {
        self.timeProvider = timeProvider
    }

    public func notifySecureNoteExpired(noteId: UUID, isForeground: Bool) async {
        events.append(
            ExpiryNotificationEvent(
                noteId: noteId,
                deliveredAt: timeProvider.now(),
                isForeground: isForeground
            )
        )
    }

    public func history() async -> [ExpiryNotificationEvent] {
        events
    }
}
