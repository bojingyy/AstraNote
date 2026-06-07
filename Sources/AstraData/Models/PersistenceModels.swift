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
    public var secureTitleAlias: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        subjectId: UUID?,
        isSecure: Bool,
        plainTitle: String?,
        plainContent: String?,
        securePayload: StoredEncryptedPayload?,
        secureTitleAlias: String? = nil,
        expirationUTC: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.subjectId = subjectId
        self.isSecure = isSecure
        self.plainTitle = plainTitle
        self.plainContent = plainContent
        self.securePayload = securePayload
        self.secureTitleAlias = secureTitleAlias
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
    public var pluginsEnabled: Bool
    public var biometricUnlockEnabled: Bool

    public init(
        pluginsEnabled: Bool = true,
        biometricUnlockEnabled: Bool = false
    ) {
        self.pluginsEnabled = pluginsEnabled
        self.biometricUnlockEnabled = biometricUnlockEnabled
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

public struct StoredCredentialRotationState: Codable, Sendable, Equatable {
    public let startedAt: Date

    public init(startedAt: Date) {
        self.startedAt = startedAt
    }
}

public struct StoredPluginMetadataRecord: Codable, Sendable, Equatable {
    public let pluginId: String
    public var displayName: String
    public var version: String
    public var capabilities: [String]
    public var isEnabled: Bool
    public let installedAt: Date

    public init(
        pluginId: String,
        displayName: String,
        version: String,
        capabilities: [String],
        isEnabled: Bool,
        installedAt: Date
    ) {
        self.pluginId = pluginId
        self.displayName = displayName
        self.version = version
        self.capabilities = capabilities
        self.isEnabled = isEnabled
        self.installedAt = installedAt
    }
}

public struct StoredPluginBundleRecord: Codable, Sendable, Equatable {
    public let pluginId: String
    public let bundleData: Data

    public init(pluginId: String, bundleData: Data) {
        self.pluginId = pluginId
        self.bundleData = bundleData
    }
}

public struct DatabaseState: Codable, Sendable {
    public var schemaVersion: Int
    public var notes: [UUID: StoredNoteRecord]
    public var attachments: [UUID: StoredAttachmentRecord]
    public var subjects: [UUID: StoredSubjectRecord]
    public var trash: [UUID: StoredTrashRecord]
    public var pluginMetadata: [String: StoredPluginMetadataRecord]
    public var pluginBundles: [String: StoredPluginBundleRecord]
    public var settings: StoredSettingsRecord
    public var credentials: StoredCredentialState?
    public var pendingCredentialRotation: StoredCredentialRotationState?
    public var lastKnownUTC: Date?
    public var rollbackGuardUntilUTC: Date?

    public init(
        schemaVersion: Int = 1,
        notes: [UUID: StoredNoteRecord] = [:],
        attachments: [UUID: StoredAttachmentRecord] = [:],
        subjects: [UUID: StoredSubjectRecord] = [:],
        trash: [UUID: StoredTrashRecord] = [:],
        pluginMetadata: [String: StoredPluginMetadataRecord] = [:],
        pluginBundles: [String: StoredPluginBundleRecord] = [:],
        settings: StoredSettingsRecord = .init(),
        credentials: StoredCredentialState? = nil,
        pendingCredentialRotation: StoredCredentialRotationState? = nil,
        lastKnownUTC: Date? = nil,
        rollbackGuardUntilUTC: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.notes = notes
        self.attachments = attachments
        self.subjects = subjects
        self.trash = trash
        self.pluginMetadata = pluginMetadata
        self.pluginBundles = pluginBundles
        self.settings = settings
        self.credentials = credentials
        self.pendingCredentialRotation = pendingCredentialRotation
        self.lastKnownUTC = lastKnownUTC
        self.rollbackGuardUntilUTC = rollbackGuardUntilUTC
    }
}
