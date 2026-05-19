import Foundation

public protocol NoteRepositoryProtocol: Sendable {
    func upsert(_ note: StoredNoteRecord) async throws
    func fetch(id: UUID) async -> StoredNoteRecord?
    func fetchAllActive() async -> [StoredNoteRecord]
    func setSubject(noteId: UUID, subjectId: UUID?) async throws
    func deleteToTrash(noteId: UUID, deletedAt: Date) async throws -> Bool
}

public actor NoteRepository: NoteRepositoryProtocol {
    private let database: DatabaseProvider

    public init(database: DatabaseProvider) {
        self.database = database
    }

    public func upsert(_ note: StoredNoteRecord) async throws {
        try await database.transaction { state in
            state.notes[note.id] = note
        }
    }

    public func fetch(id: UUID) async -> StoredNoteRecord? {
        await database.read { $0.notes[id] }
    }

    public func fetchAllActive() async -> [StoredNoteRecord] {
        await database.read { state in
            state.notes.values.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    public func setSubject(noteId: UUID, subjectId: UUID?) async throws {
        try await database.transaction { state in
            guard var note = state.notes[noteId] else {
                return
            }
            note.subjectId = subjectId
            note.updatedAt = Date()
            state.notes[noteId] = note
        }
    }

    public func deleteToTrash(noteId: UUID, deletedAt: Date) async throws -> Bool {
        try await database.transaction { state in
            guard let note = state.notes[noteId] else {
                return false
            }

            let attachments = state.attachments.values.filter { $0.noteId == noteId }
            for attachment in attachments {
                state.attachments.removeValue(forKey: attachment.id)
            }

            let trashRecord = StoredTrashRecord(
                id: UUID(),
                sourceNote: note,
                attachments: attachments,
                deletedAt: deletedAt
            )
            state.trash[trashRecord.id] = trashRecord
            state.notes.removeValue(forKey: noteId)
            return true
        }
    }
}
