import Foundation
import AstraData

public struct EncryptedPayload: Sendable, Equatable {
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

    init(stored: StoredEncryptedPayload) {
        self.init(
            ciphertext: stored.ciphertext,
            nonce: stored.nonce,
            tag: stored.tag,
            salt: stored.salt
        )
    }

    var stored: StoredEncryptedPayload {
        StoredEncryptedPayload(ciphertext: ciphertext, nonce: nonce, tag: tag, salt: salt)
    }
}

public struct KeyMaterial: Sendable, Equatable {
    public let encryptionKey: Data

    public init(encryptionKey: Data) {
        self.encryptionKey = encryptionKey
    }
}

public enum AttachmentType: String, Sendable {
    case image
    case recording

    var stored: StoredAttachmentType {
        switch self {
        case .image:
            return .image
        case .recording:
            return .recording
        }
    }

    init(stored: StoredAttachmentType) {
        switch stored {
        case .image:
            self = .image
        case .recording:
            self = .recording
        }
    }
}

public struct Attachment: Sendable, Equatable {
    public let id: UUID
    public let noteId: UUID
    public let type: AttachmentType
    public let storagePath: String
    public let byteSize: Int
    public let isEncrypted: Bool
    public let createdAt: Date

    init(stored: StoredAttachmentRecord) {
        self.id = stored.id
        self.noteId = stored.noteId
        self.type = AttachmentType(stored: stored.type)
        self.storagePath = stored.storagePath
        self.byteSize = stored.byteSize
        self.isEncrypted = stored.isEncrypted
        self.createdAt = stored.createdAt
    }
}

public struct NoteDraft: Sendable, Equatable {
    public var id: UUID?
    public let title: String
    public let content: String
    public let subjectId: UUID?
    public let secureModeEnabled: Bool
    public let expirationUTC: Date?

    public init(
        id: UUID? = nil,
        title: String,
        content: String,
        subjectId: UUID?,
        secureModeEnabled: Bool,
        expirationUTC: Date?
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.subjectId = subjectId
        self.secureModeEnabled = secureModeEnabled
        self.expirationUTC = expirationUTC
    }
}

public struct NoteView: Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let content: String
    public let subjectId: UUID?
    public let isSecure: Bool
    public let expirationUTC: Date?
    public let createdAt: Date
    public let updatedAt: Date
}

public struct NoteSummary: Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let isSecure: Bool
    public let subjectId: UUID?
    public let updatedAt: Date
}

public struct Subject: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let displayOrder: Int
    public let createdAt: Date

    init(stored: StoredSubjectRecord) {
        self.id = stored.id
        self.name = stored.name
        self.displayOrder = stored.displayOrder
        self.createdAt = stored.createdAt
    }
}

public struct AppSettings: Sendable, Equatable {
    public let lockTimeoutSeconds: Int
    public let telemetryEnabled: Bool
    public let pluginsEnabled: Bool

    init(stored: StoredSettingsRecord) {
        self.lockTimeoutSeconds = stored.lockTimeoutSeconds
        self.telemetryEnabled = stored.telemetryEnabled
        self.pluginsEnabled = stored.pluginsEnabled
    }

    var stored: StoredSettingsRecord {
        StoredSettingsRecord(
            lockTimeoutSeconds: lockTimeoutSeconds,
            telemetryEnabled: telemetryEnabled,
            pluginsEnabled: pluginsEnabled
        )
    }
}
