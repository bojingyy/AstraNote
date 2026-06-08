import Foundation
import AstraData
import AstraPlatform

public enum NoteServiceError: Error, Equatable {
    case titleRequired
    case keyMaterialUnavailable
    case recordNotFound
    case invalidSecurePayload
    case voiceAttachmentTooLarge
    case imageAttachmentTooLarge
}

public actor NoteService {
    private static let defaultSecureTitleAlias = "Locked Note"

    private let notes: NoteRepositoryProtocol
    private let attachments: AttachmentRepositoryProtocol
    private let subjects: SubjectRepositoryProtocol
    private let keyManager: KeyManager
    private let encryptionService: EncryptionService
    private let timeProvider: TimeProvider
    private let storageProtection: StorageProtecting?

    public init(
        notes: NoteRepositoryProtocol,
        attachments: AttachmentRepositoryProtocol,
        subjects: SubjectRepositoryProtocol,
        keyManager: KeyManager,
        encryptionService: EncryptionService,
        timeProvider: TimeProvider = SystemTimeProvider(),
        storageProtection: StorageProtecting? = nil
    ) {
        self.notes = notes
        self.attachments = attachments
        self.subjects = subjects
        self.keyManager = keyManager
        self.encryptionService = encryptionService
        self.timeProvider = timeProvider
        self.storageProtection = storageProtection
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
            secureTitleAlias: nil,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )

        if draft.secureModeEnabled {
            guard let keyMaterial = await keyManager.currentKeyMaterial() else {
                throw NoteServiceError.keyMaterialUnavailable
            }

            let plaintext = try SecurePayloadCodec.encode(title: draft.title, content: draft.content)
            let encrypted = try encryptionService.encrypt(plaintext: plaintext, keyMaterial: keyMaterial)
            let alias = normalizedSecureTitleAlias(from: draft.secureTitleAlias)

            record.isSecure = true
            record.securePayload = encrypted.stored
            record.plainTitle = nil
            record.plainContent = nil
            record.secureTitleAlias = alias
        } else {
            record.isSecure = false
            record.securePayload = nil
            record.plainTitle = draft.title
            record.plainContent = draft.content
            record.secureTitleAlias = nil
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
                let keyMaterial = await keyManager.currentKeyMaterial()
            else {
                throw NoteServiceError.invalidSecurePayload
            }

            let decrypted = try encryptionService.decrypt(payload: EncryptedPayload(stored: payload), keyMaterial: keyMaterial)
            let decoded = try SecurePayloadCodec.decode(decrypted)

            return NoteView(
                id: stored.id,
                title: decoded.title,
                content: decoded.content,
                subjectId: stored.subjectId,
                isSecure: true,
                secureTitleAlias: stored.secureTitleAlias,
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
            secureTitleAlias: nil,
            createdAt: stored.createdAt,
            updatedAt: stored.updatedAt
        )
    }

    public func listSummaries() async -> [NoteSummary] {
        let all = await notes.fetchAllActive()
        return all.map {
            NoteSummary(
                id: $0.id,
                title: $0.isSecure ? ($0.secureTitleAlias ?? Self.defaultSecureTitleAlias) : ($0.plainTitle ?? ""),
                isSecure: $0.isSecure,
                subjectId: $0.subjectId,
                updatedAt: $0.updatedAt
            )
        }
    }

    private func normalizedSecureTitleAlias(from alias: String?) -> String {
        let trimmed = alias?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return Self.defaultSecureTitleAlias
        }
        return trimmed
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
        if let storageProtection {
            let protectionClass: StorageProtectionClass = encryptedAtRest ? .complete : .completeUntilFirstUserAuthentication
            try await storageProtection.protect(path: storagePath, classification: protectionClass)
        }
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

    public func deleteAttachment(noteId: UUID, attachmentId: UUID) async throws {
        guard let record = await attachments.fetch(id: attachmentId), record.noteId == noteId else {
            throw NoteServiceError.recordNotFound
        }
        try await attachments.remove(id: attachmentId)
        try? FileManager.default.removeItem(atPath: record.storagePath)
    }

    public func assignSubject(noteId: UUID, subjectId: UUID?) async throws {
        if let subjectId, await subjects.fetch(id: subjectId) == nil {
            throw NoteServiceError.recordNotFound
        }
        try await notes.setSubject(noteId: noteId, subjectId: subjectId)
    }

    public func updateSecureMetadata(noteId: UUID, secureTitleAlias: String?, subjectId: UUID?) async throws {
        guard var existing = await notes.fetch(id: noteId), existing.isSecure else {
            throw NoteServiceError.recordNotFound
        }

        if let subjectId, await subjects.fetch(id: subjectId) == nil {
            throw NoteServiceError.recordNotFound
        }

        existing.secureTitleAlias = normalizedSecureTitleAlias(from: secureTitleAlias)
        existing.subjectId = subjectId
        existing.updatedAt = timeProvider.now()
        try await notes.upsert(existing)
    }
}
