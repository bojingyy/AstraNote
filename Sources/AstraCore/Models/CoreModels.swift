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
    public let secureTitleAlias: String?

    public init(
        id: UUID? = nil,
        title: String,
        content: String,
        subjectId: UUID?,
        secureModeEnabled: Bool,
        secureTitleAlias: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.subjectId = subjectId
        self.secureModeEnabled = secureModeEnabled
        self.secureTitleAlias = secureTitleAlias
    }
}

public struct NoteView: Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let content: String
    public let subjectId: UUID?
    public let isSecure: Bool
    public let secureTitleAlias: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        title: String,
        content: String,
        subjectId: UUID?,
        isSecure: Bool,
        secureTitleAlias: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.subjectId = subjectId
        self.isSecure = isSecure
        self.secureTitleAlias = secureTitleAlias
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
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
    public let pluginsEnabled: Bool
    public let biometricUnlockEnabled: Bool

    public init(
        pluginsEnabled: Bool,
        biometricUnlockEnabled: Bool
    ) {
        self.pluginsEnabled = pluginsEnabled
        self.biometricUnlockEnabled = biometricUnlockEnabled
    }

    init(stored: StoredSettingsRecord) {
        self.pluginsEnabled = stored.pluginsEnabled
        self.biometricUnlockEnabled = stored.biometricUnlockEnabled
    }

    var stored: StoredSettingsRecord {
        StoredSettingsRecord(
            pluginsEnabled: pluginsEnabled,
            biometricUnlockEnabled: biometricUnlockEnabled
        )
    }
}

public struct PluginManifest: Sendable, Equatable {
    public let pluginId: String
    public let displayName: String
    public let version: String
    public let capabilities: [String]

    public init(pluginId: String, displayName: String, version: String, capabilities: [String]) {
        self.pluginId = pluginId
        self.displayName = displayName
        self.version = version
        self.capabilities = capabilities
    }

    init(stored: StoredPluginMetadataRecord) {
        self.init(
            pluginId: stored.pluginId,
            displayName: stored.displayName,
            version: stored.version,
            capabilities: stored.capabilities
        )
    }
}

public struct InstalledPlugin: Sendable, Equatable {
    public let manifest: PluginManifest
    public let isEnabled: Bool
    public let installedAt: Date

    init(stored: StoredPluginMetadataRecord) {
        self.manifest = PluginManifest(stored: stored)
        self.isEnabled = stored.isEnabled
        self.installedAt = stored.installedAt
    }
}

public struct PluginActionRequest: Sendable, Equatable {
    public let action: String
    public let input: String

    public init(action: String, input: String) {
        self.action = action
        self.input = input
    }
}

public struct PluginActionResult: Sendable, Equatable {
    public let output: String

    public init(output: String) {
        self.output = output
    }
}

public enum ImportConflictResolution: Sendable {
    case reject
    case regenerateIncomingIdentifiers
}

public struct ImportResult: Sendable, Equatable {
    public let importedNotes: Int
    public let importedSubjects: Int
    public let importedPlugins: Int

    public init(importedNotes: Int, importedSubjects: Int, importedPlugins: Int) {
        self.importedNotes = importedNotes
        self.importedSubjects = importedSubjects
        self.importedPlugins = importedPlugins
    }
}
