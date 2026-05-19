import Foundation

public protocol ProtectedTrashRepositoryProtocol: Sendable {
    func listAll() async -> [StoredTrashRecord]
    func restore(trashId: UUID) async throws -> Bool
    func permanentlyDelete(trashId: UUID) async throws -> Bool
}

public actor ProtectedTrashRepository: ProtectedTrashRepositoryProtocol {
    private let database: DatabaseProvider

    public init(database: DatabaseProvider) {
        self.database = database
    }

    public func listAll() async -> [StoredTrashRecord] {
        await database.read { state in
            state.trash.values.sorted { $0.deletedAt > $1.deletedAt }
        }
    }

    public func restore(trashId: UUID) async throws -> Bool {
        try await database.transaction { state in
            guard let record = state.trash.removeValue(forKey: trashId) else {
                return false
            }

            var note = record.sourceNote
            if state.notes[note.id] != nil {
                note = StoredNoteRecord(
                    id: UUID(),
                    subjectId: note.subjectId,
                    isSecure: note.isSecure,
                    plainTitle: note.plainTitle,
                    plainContent: note.plainContent,
                    securePayload: note.securePayload,
                    expirationUTC: note.expirationUTC,
                    createdAt: note.createdAt,
                    updatedAt: Date()
                )
            }
            state.notes[note.id] = note

            for attachment in record.attachments {
                let newAttachmentId = state.attachments[attachment.id] == nil ? attachment.id : UUID()
                let restoredAttachment = StoredAttachmentRecord(
                    id: newAttachmentId,
                    noteId: note.id,
                    type: attachment.type,
                    storagePath: attachment.storagePath,
                    byteSize: attachment.byteSize,
                    isEncrypted: attachment.isEncrypted,
                    createdAt: attachment.createdAt
                )
                state.attachments[restoredAttachment.id] = restoredAttachment
            }
            return true
        }
    }

    public func permanentlyDelete(trashId: UUID) async throws -> Bool {
        try await database.transaction { state in
            guard state.trash.removeValue(forKey: trashId) != nil else {
                return false
            }
            return true
        }
    }
}
