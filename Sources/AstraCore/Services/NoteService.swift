import Foundation
import AstraData
import AstraPlatform

public enum NoteServiceError: Error, Equatable {
    case titleRequired
    case secureModeRequiresExpiration
    case secureModeExpirationInPast
    case keyMaterialUnavailable
    case recordNotFound
    case invalidSecurePayload
    case voiceAttachmentTooLarge
    case imageAttachmentTooLarge
}

public actor NoteService {
    private struct SecurePayloadDTO: Codable {
        let title: String
        let content: String
    }

    private let notes: NoteRepositoryProtocol
    private let attachments: AttachmentRepositoryProtocol
    private let subjects: SubjectRepositoryProtocol
    private let keyManager: KeyManager
    private let encryptionService: EncryptionService
    private let timeProvider: TimeProvider

    public init(
        notes: NoteRepositoryProtocol,
        attachments: AttachmentRepositoryProtocol,
        subjects: SubjectRepositoryProtocol,
        keyManager: KeyManager,
        encryptionService: EncryptionService,
        timeProvider: TimeProvider = SystemTimeProvider()
    ) {
        self.notes = notes
        self.attachments = attachments
        self.subjects = subjects
        self.keyManager = keyManager
        self.encryptionService = encryptionService
        self.timeProvider = timeProvider
    }

    @discardableResult
    public func save(draft: NoteDraft) async throws -> UUID {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw NoteServiceError.titleRequired
        }

        if let subjectId = draft.subjectId, await subjects.fetch(id: subjectId) == nil {
            throw NoteServiceError.recordNotFound
        }

        let now = timeProvider.now()
        let noteId = draft.id ?? UUID()
        let existing = await notes.fetch(id: noteId)

        var record = StoredNoteRecord(
            id: noteId,
            subjectId: draft.subjectId,
            isSecure: draft.secureModeEnabled,
            plainTitle: nil,
            plainContent: nil,
            securePayload: nil,
            expirationUTC: nil,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )

        if draft.secureModeEnabled {
            guard let expirationUTC = draft.expirationUTC else {
                throw NoteServiceError.secureModeRequiresExpiration
            }
            guard expirationUTC > now else {
                throw NoteServiceError.secureModeExpirationInPast
            }
            guard let keyMaterial = await keyManager.currentKeyMaterial() else {
                throw NoteServiceError.keyMaterialUnavailable
            }

            let plaintext = try JSONEncoder().encode(SecurePayloadDTO(title: draft.title, content: draft.content))
            let encrypted = try encryptionService.encrypt(plaintext: plaintext, keyMaterial: keyMaterial)

            record.isSecure = true
            record.expirationUTC = expirationUTC
            record.securePayload = encrypted.stored
            record.plainTitle = nil
            record.plainContent = nil
        } else {
            record.isSecure = false
            record.expirationUTC = nil
            record.securePayload = nil
            record.plainTitle = draft.title
            record.plainContent = draft.content
        }

        try await notes.upsert(record)
        return noteId
    }

    public func load(id: UUID) async throws -> NoteView {
        guard let stored = await notes.fetch(id: id) else {
            throw NoteServiceError.recordNotFound
        }

        if stored.isSecure {
            guard
                let payload = stored.securePayload,
                let expirationUTC = stored.expirationUTC,
                let keyMaterial = await keyManager.currentKeyMaterial()
            else {
                throw NoteServiceError.invalidSecurePayload
            }

            let decrypted = try encryptionService.decrypt(payload: EncryptedPayload(stored: payload), keyMaterial: keyMaterial)
            let decoded = try JSONDecoder().decode(SecurePayloadDTO.self, from: decrypted)

            return NoteView(
                id: stored.id,
                title: decoded.title,
                content: decoded.content,
                subjectId: stored.subjectId,
                isSecure: true,
                expirationUTC: expirationUTC,
                createdAt: stored.createdAt,
                updatedAt: stored.updatedAt
            )
        }

        return NoteView(
            id: stored.id,
            title: stored.plainTitle ?? "",
            content: stored.plainContent ?? "",
            subjectId: stored.subjectId,
            isSecure: false,
            expirationUTC: nil,
            createdAt: stored.createdAt,
            updatedAt: stored.updatedAt
        )
    }

    public func listSummaries() async -> [NoteSummary] {
        let all = await notes.fetchAllActive()
        return all.map {
            NoteSummary(
                id: $0.id,
                title: $0.isSecure ? "Locked Note" : ($0.plainTitle ?? ""),
                isSecure: $0.isSecure,
                subjectId: $0.subjectId,
                updatedAt: $0.updatedAt
            )
        }
    }

    public func delete(noteId: UUID) async throws -> Bool {
        try await notes.deleteToTrash(noteId: noteId, deletedAt: timeProvider.now())
    }

    public func addAttachment(
        noteId: UUID,
        type: AttachmentType,
        storagePath: String,
        byteSize: Int,
        encryptedAtRest: Bool
    ) async throws -> UUID {
        guard await notes.fetch(id: noteId) != nil else {
            throw NoteServiceError.recordNotFound
        }

        let attachment = StoredAttachmentRecord(
            id: UUID(),
            noteId: noteId,
            type: type.stored,
            storagePath: storagePath,
            byteSize: byteSize,
            isEncrypted: encryptedAtRest,
            createdAt: timeProvider.now()
        )
        try await attachments.add(attachment)
        return attachment.id
    }

    public func addVoiceAttachment(noteId: UUID, storagePath: String, byteSize: Int) async throws -> UUID {
        let maxVoiceBytes = 50 * 1024 * 1024
        guard byteSize <= maxVoiceBytes else {
            throw NoteServiceError.voiceAttachmentTooLarge
        }
        let note = await notes.fetch(id: noteId)
        guard let note else {
            throw NoteServiceError.recordNotFound
        }
        return try await addAttachment(
            noteId: noteId,
            type: .recording,
            storagePath: storagePath,
            byteSize: byteSize,
            encryptedAtRest: note.isSecure
        )
    }

    public func addImageAttachment(noteId: UUID, storagePath: String, byteSize: Int) async throws -> UUID {
        let maxImageBytes = 20 * 1024 * 1024
        guard byteSize <= maxImageBytes else {
            throw NoteServiceError.imageAttachmentTooLarge
        }
        let note = await notes.fetch(id: noteId)
        guard let note else {
            throw NoteServiceError.recordNotFound
        }
        return try await addAttachment(
            noteId: noteId,
            type: .image,
            storagePath: storagePath,
            byteSize: byteSize,
            encryptedAtRest: note.isSecure
        )
    }

    public func listAttachments(noteId: UUID) async -> [Attachment] {
        await attachments.list(noteId: noteId).map { Attachment(stored: $0) }
    }

    public func assignSubject(noteId: UUID, subjectId: UUID?) async throws {
        if let subjectId, await subjects.fetch(id: subjectId) == nil {
            throw NoteServiceError.recordNotFound
        }
        try await notes.setSubject(noteId: noteId, subjectId: subjectId)
    }
}
