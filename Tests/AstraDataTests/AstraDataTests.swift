import XCTest
@testable import AstraData

final class AstraDataTests: XCTestCase {
    func testTransactionRollsBackOnError() async throws {
        enum LocalError: Error {
            case fail
        }

        let database = DatabaseProvider()

        do {
            _ = try await database.transaction { state in
                let note = StoredNoteRecord(
                    id: UUID(),
                    subjectId: nil,
                    isSecure: false,
                    plainTitle: "before rollback",
                    plainContent: "content",
                    securePayload: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                state.notes[note.id] = note
                throw LocalError.fail
            }
            XCTFail("Expected transaction error")
        } catch {}

        let count = await database.read { $0.notes.count }
        XCTAssertEqual(count, 0)
    }

    func testDeleteMovesNoteAndAttachmentsToTrashAtomically() async throws {
        let database = DatabaseProvider()
        let notes = NoteRepository(database: database)
        let attachments = AttachmentRepository(database: database)

        let noteId = UUID()
        try await notes.upsert(
            StoredNoteRecord(
                id: noteId,
                subjectId: nil,
                isSecure: false,
                plainTitle: "hello",
                plainContent: "world",
                securePayload: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
        try await attachments.add(
            StoredAttachmentRecord(
                id: UUID(),
                noteId: noteId,
                type: .image,
                storagePath: "/tmp/pic.png",
                byteSize: 10,
                isEncrypted: false,
                createdAt: Date()
            )
        )

        let deleted = try await notes.deleteToTrash(noteId: noteId, deletedAt: Date())
        XCTAssertTrue(deleted)

        let active = await notes.fetch(id: noteId)
        XCTAssertNil(active)
        let dbState = await database.read { $0 }
        XCTAssertEqual(dbState.trash.count, 1)
        XCTAssertEqual(dbState.attachments.count, 0)
    }

    func testSubjectDeleteUngroupsNotes() async throws {
        let database = DatabaseProvider()
        let subjects = SubjectRepository(database: database)
        let notes = NoteRepository(database: database)

        let subject = try await subjects.create(name: "Math")
        let noteId = UUID()
        try await notes.upsert(
            StoredNoteRecord(
                id: noteId,
                subjectId: subject.id,
                isSecure: false,
                plainTitle: "n1",
                plainContent: "c1",
                securePayload: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        )

        let result = try await subjects.deleteAndUngroupNotes(id: subject.id)
        XCTAssertTrue(result)

        let note = await notes.fetch(id: noteId)
        XCTAssertEqual(note?.subjectId, nil)
    }

    func testProtectedTrashRestoreAndPermanentDelete() async throws {
        let database = DatabaseProvider()
        let notes = NoteRepository(database: database)
        let trash = ProtectedTrashRepository(database: database)

        let noteId = UUID()
        try await notes.upsert(
            StoredNoteRecord(
                id: noteId,
                subjectId: nil,
                isSecure: false,
                plainTitle: "trash me",
                plainContent: "data",
                securePayload: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        )

        _ = try await notes.deleteToTrash(noteId: noteId, deletedAt: Date())
        let allTrashItems = await trash.listAll()
        let trashId = try XCTUnwrap(allTrashItems.first?.id)

        let restored = try await trash.restore(trashId: trashId)
        XCTAssertTrue(restored)
        let fetchedNote = await notes.fetch(id: noteId)
        XCTAssertNotNil(fetchedNote)

        _ = try await notes.deleteToTrash(noteId: noteId, deletedAt: Date())
        let allTrashAfterDelete = await trash.listAll()
        let trashId2 = try XCTUnwrap(allTrashAfterDelete.first?.id)
        let deleted = try await trash.permanentlyDelete(trashId: trashId2)
        XCTAssertTrue(deleted)
        let finalTrashList = await trash.listAll()
        XCTAssertTrue(finalTrashList.isEmpty)
    }
}
