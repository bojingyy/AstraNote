import Foundation

public enum StoredAttachmentType: String, Codable, Sendable {
    case image
    case recording
}

public struct StoredEncryptedPayload: Codable, Sendable, Equatable {
    public let ciphertext: Data
    public let nonce: Data
    public let tag: Data
    public let salt: Data

    public init(ciphertext: Data, nonce: Data, tag: Data, salt: Data) {
        self.ciphertext = ciphertext
        self.nonce = nonce
        self.tag = tag
        self.salt = salt
    }
}

public struct StoredNoteRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public var subjectId: UUID?
    public var isSecure: Bool
    public var plainTitle: String?
    public var plainContent: String?
    public var securePayload: StoredEncryptedPayload?
    public var expirationUTC: Date?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        subjectId: UUID?,
        isSecure: Bool,
        plainTitle: String?,
        plainContent: String?,
        securePayload: StoredEncryptedPayload?,
        expirationUTC: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.subjectId = subjectId
        self.isSecure = isSecure
        self.plainTitle = plainTitle
        self.plainContent = plainContent
        self.securePayload = securePayload
        self.expirationUTC = expirationUTC
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct StoredAttachmentRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let noteId: UUID
    public let type: StoredAttachmentType
    public let storagePath: String
    public let byteSize: Int
    public let isEncrypted: Bool
    public let createdAt: Date

    public init(
        id: UUID,
        noteId: UUID,
        type: StoredAttachmentType,
        storagePath: String,
        byteSize: Int,
        isEncrypted: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.noteId = noteId
        self.type = type
        self.storagePath = storagePath
        self.byteSize = byteSize
        self.isEncrypted = isEncrypted
        self.createdAt = createdAt
    }
}

public struct StoredSubjectRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var displayOrder: Int
    public let createdAt: Date

    public init(id: UUID, name: String, displayOrder: Int, createdAt: Date) {
        self.id = id
        self.name = name
        self.displayOrder = displayOrder
        self.createdAt = createdAt
    }
}

public struct StoredSettingsRecord: Codable, Sendable, Equatable {
    public var lockTimeoutSeconds: Int
    public var telemetryEnabled: Bool
    public var pluginsEnabled: Bool

    public init(lockTimeoutSeconds: Int = 300, telemetryEnabled: Bool = false, pluginsEnabled: Bool = true) {
        self.lockTimeoutSeconds = lockTimeoutSeconds
        self.telemetryEnabled = telemetryEnabled
        self.pluginsEnabled = pluginsEnabled
    }
}

public struct StoredTrashRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let sourceNote: StoredNoteRecord
    public let attachments: [StoredAttachmentRecord]
    public let deletedAt: Date

    public init(id: UUID, sourceNote: StoredNoteRecord, attachments: [StoredAttachmentRecord], deletedAt: Date) {
        self.id = id
        self.sourceNote = sourceNote
        self.attachments = attachments
        self.deletedAt = deletedAt
    }
}

public struct StoredCredentialState: Codable, Sendable, Equatable {
    public let salt: Data
    public let hash: Data
    public let iterations: Int

    public init(salt: Data, hash: Data, iterations: Int) {
        self.salt = salt
        self.hash = hash
        self.iterations = iterations
    }
}

public struct DatabaseState: Codable, Sendable {
    public var schemaVersion: Int
    public var notes: [UUID: StoredNoteRecord]
    public var attachments: [UUID: StoredAttachmentRecord]
    public var subjects: [UUID: StoredSubjectRecord]
    public var trash: [UUID: StoredTrashRecord]
    public var settings: StoredSettingsRecord
    public var credentials: StoredCredentialState?
    public var lastKnownUTC: Date?
    public var rollbackGuardUntilUTC: Date?

    public init(
        schemaVersion: Int = 1,
        notes: [UUID: StoredNoteRecord] = [:],
        attachments: [UUID: StoredAttachmentRecord] = [:],
        subjects: [UUID: StoredSubjectRecord] = [:],
        trash: [UUID: StoredTrashRecord] = [:],
        settings: StoredSettingsRecord = .init(),
        credentials: StoredCredentialState? = nil,
        lastKnownUTC: Date? = nil,
        rollbackGuardUntilUTC: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.notes = notes
        self.attachments = attachments
        self.subjects = subjects
        self.trash = trash
        self.settings = settings
        self.credentials = credentials
        self.lastKnownUTC = lastKnownUTC
        self.rollbackGuardUntilUTC = rollbackGuardUntilUTC
    }
}
