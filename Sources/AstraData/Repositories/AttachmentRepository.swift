import Foundation

public protocol AttachmentRepositoryProtocol: Sendable {
    func add(_ attachment: StoredAttachmentRecord) async throws
    func list(noteId: UUID) async -> [StoredAttachmentRecord]
}

public actor AttachmentRepository: AttachmentRepositoryProtocol {
    private let database: DatabaseProvider

    public init(database: DatabaseProvider) {
        self.database = database
    }

    public func add(_ attachment: StoredAttachmentRecord) async throws {
        try await database.transaction { state in
            state.attachments[attachment.id] = attachment
        }
    }

    public func list(noteId: UUID) async -> [StoredAttachmentRecord] {
        await database.read { state in
            state.attachments.values
                .filter { $0.noteId == noteId }
                .sorted { $0.createdAt < $1.createdAt }
        }
    }
}
