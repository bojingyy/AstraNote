import Foundation
import AstraData
import AstraPlatform

public enum ExportImportServiceError: Error, Equatable {
    case keyMaterialUnavailable
    case invalidArchive
    case unsupportedSchemaVersion
    case importConflict
}

public actor ExportImportService {
    private struct ExportArchive: Codable, Sendable {
        let schemaVersion: Int
        let exportedAt: Date
        let database: DatabaseState
    }

    private struct ExportEnvelope: Codable, Sendable {
        let schemaVersion: Int
        let payload: StoredEncryptedPayload
    }

    private let database: DatabaseProvider
    private let keyManager: KeyManager
    private let encryptionService: EncryptionService
    private let logger: AuditLogging

    public init(
        database: DatabaseProvider,
        keyManager: KeyManager,
        encryptionService: EncryptionService,
        logger: AuditLogging
    ) {
        self.database = database
        self.keyManager = keyManager
        self.encryptionService = encryptionService
        self.logger = logger
    }

    public func exportArchive() async throws -> Data {
        guard let keyMaterial = await keyManager.currentKeyMaterial() else {
            throw ExportImportServiceError.keyMaterialUnavailable
        }

        var snapshot = await database.exportState()
        snapshot.credentials = nil
        snapshot.pendingCredentialRotation = nil
        snapshot.lastKnownUTC = nil
        snapshot.rollbackGuardUntilUTC = nil

        let archive = ExportArchive(
            schemaVersion: snapshot.schemaVersion,
            exportedAt: Date(),
            database: snapshot
        )
        let plaintext = try JSONEncoder().encode(archive)
        let payload = try encryptionService.encrypt(plaintext: plaintext, keyMaterial: keyMaterial)
        let envelope = ExportEnvelope(schemaVersion: snapshot.schemaVersion, payload: payload.stored)
        await logger.log(level: .info, event: "export_completed", metadata: ["noteCount": String(snapshot.notes.count)])
        return try JSONEncoder().encode(envelope)
    }

    public func importArchive(
        _ archiveData: Data,
        resolution: ImportConflictResolution = .regenerateIncomingIdentifiers
    ) async throws -> ImportResult {
        guard let keyMaterial = await keyManager.currentKeyMaterial() else {
            throw ExportImportServiceError.keyMaterialUnavailable
        }

        let envelope = try decodeEnvelope(from: archiveData)
        let currentSchemaVersion = await database.schemaVersion()
        guard envelope.schemaVersion <= currentSchemaVersion else {
            throw ExportImportServiceError.unsupportedSchemaVersion
        }

        let decrypted = try encryptionService.decrypt(payload: EncryptedPayload(stored: envelope.payload), keyMaterial: keyMaterial)
        let archive = try decodeArchive(from: decrypted)

        let result = try await database.transaction { state in
            var incoming = archive.database
            if resolution == .reject && Self.hasConflicts(existing: state, incoming: incoming) {
                throw ExportImportServiceError.importConflict
            }
            if resolution == .regenerateIncomingIdentifiers {
                incoming = Self.remapIncomingState(incoming, existing: state)
            }

            let importedNotes = incoming.notes.count
            let importedSubjects = incoming.subjects.count
            let importedPlugins = incoming.pluginMetadata.count

            for (id, subject) in incoming.subjects {
                state.subjects[id] = subject
            }
            for (id, note) in incoming.notes {
                state.notes[id] = note
            }
            for (id, attachment) in incoming.attachments {
                state.attachments[id] = attachment
            }
            for (id, trashRecord) in incoming.trash {
                state.trash[id] = trashRecord
            }
            for (pluginId, metadata) in incoming.pluginMetadata {
                state.pluginMetadata[pluginId] = metadata
            }
            for (pluginId, bundle) in incoming.pluginBundles {
                state.pluginBundles[pluginId] = bundle
            }
            state.settings = incoming.settings
            return ImportResult(
                importedNotes: importedNotes,
                importedSubjects: importedSubjects,
                importedPlugins: importedPlugins
            )
        }

        await logger.log(
            level: .info,
            event: "import_completed",
            metadata: [
                "importedNotes": String(result.importedNotes),
                "importedPlugins": String(result.importedPlugins)
            ]
        )
        return result
    }

    private func decodeEnvelope(from data: Data) throws -> ExportEnvelope {
        guard let envelope = try? JSONDecoder().decode(ExportEnvelope.self, from: data) else {
            throw ExportImportServiceError.invalidArchive
        }
        return envelope
    }

    private func decodeArchive(from data: Data) throws -> ExportArchive {
        guard let archive = try? JSONDecoder().decode(ExportArchive.self, from: data) else {
            throw ExportImportServiceError.invalidArchive
        }
        return archive
    }

    private static func hasConflicts(existing: DatabaseState, incoming: DatabaseState) -> Bool {
        !Set(existing.notes.keys).isDisjoint(with: incoming.notes.keys) ||
        !Set(existing.attachments.keys).isDisjoint(with: incoming.attachments.keys) ||
        !Set(existing.subjects.keys).isDisjoint(with: incoming.subjects.keys) ||
        !Set(existing.trash.keys).isDisjoint(with: incoming.trash.keys) ||
        !Set(existing.pluginMetadata.keys).isDisjoint(with: incoming.pluginMetadata.keys)
    }

    private static func remapIncomingState(_ incoming: DatabaseState, existing: DatabaseState) -> DatabaseState {
        var result = incoming
        let existingSubjectIds = Set(existing.subjects.keys)
        let existingNoteIds = Set(existing.notes.keys)
        let existingAttachmentIds = Set(existing.attachments.keys)
        let existingTrashIds = Set(existing.trash.keys)
        let existingPluginIds = Set(existing.pluginMetadata.keys)

        var subjectIdMap: [UUID: UUID] = [:]
        var noteIdMap: [UUID: UUID] = [:]

        result.subjects = Dictionary(uniqueKeysWithValues: incoming.subjects.map { originalId, subject in
            let mappedId = existingSubjectIds.contains(originalId) ? UUID() : originalId
            subjectIdMap[originalId] = mappedId
            return (mappedId, StoredSubjectRecord(id: mappedId, name: subject.name, displayOrder: subject.displayOrder, createdAt: subject.createdAt))
        })

        result.notes = Dictionary(uniqueKeysWithValues: incoming.notes.map { originalId, note in
            let mappedId = existingNoteIds.contains(originalId) ? UUID() : originalId
            noteIdMap[originalId] = mappedId
            return (
                mappedId,
                StoredNoteRecord(
                    id: mappedId,
                    subjectId: note.subjectId.flatMap { subjectIdMap[$0] ?? $0 },
                    isSecure: note.isSecure,
                    plainTitle: note.plainTitle,
                    plainContent: note.plainContent,
                    securePayload: note.securePayload,
                    expirationUTC: note.expirationUTC,
                    createdAt: note.createdAt,
                    updatedAt: note.updatedAt
                )
            )
        })

        result.attachments = Dictionary(uniqueKeysWithValues: incoming.attachments.map { originalId, attachment in
            let mappedId = existingAttachmentIds.contains(originalId) ? UUID() : originalId
            let mappedNoteId = noteIdMap[attachment.noteId] ?? attachment.noteId
            return (
                mappedId,
                StoredAttachmentRecord(
                    id: mappedId,
                    noteId: mappedNoteId,
                    type: attachment.type,
                    storagePath: attachment.storagePath,
                    byteSize: attachment.byteSize,
                    isEncrypted: attachment.isEncrypted,
                    createdAt: attachment.createdAt
                )
            )
        })

        result.trash = Dictionary(uniqueKeysWithValues: incoming.trash.map { originalId, record in
            let mappedTrashId = existingTrashIds.contains(originalId) ? UUID() : originalId
            let mappedNoteId = noteIdMap[record.sourceNote.id] ?? record.sourceNote.id
            let mappedSourceNote = StoredNoteRecord(
                id: mappedNoteId,
                subjectId: record.sourceNote.subjectId.flatMap { subjectIdMap[$0] ?? $0 },
                isSecure: record.sourceNote.isSecure,
                plainTitle: record.sourceNote.plainTitle,
                plainContent: record.sourceNote.plainContent,
                securePayload: record.sourceNote.securePayload,
                expirationUTC: record.sourceNote.expirationUTC,
                createdAt: record.sourceNote.createdAt,
                updatedAt: record.sourceNote.updatedAt
            )
            let mappedAttachments = record.attachments.map { attachment in
                let mappedAttachmentId = existingAttachmentIds.contains(attachment.id) ? UUID() : attachment.id
                return StoredAttachmentRecord(
                    id: mappedAttachmentId,
                    noteId: mappedNoteId,
                    type: attachment.type,
                    storagePath: attachment.storagePath,
                    byteSize: attachment.byteSize,
                    isEncrypted: attachment.isEncrypted,
                    createdAt: attachment.createdAt
                )
            }
            return (
                mappedTrashId,
                StoredTrashRecord(
                    id: mappedTrashId,
                    sourceNote: mappedSourceNote,
                    attachments: mappedAttachments,
                    deletedAt: record.deletedAt
                )
            )
        })

        result.pluginMetadata = Dictionary(uniqueKeysWithValues: incoming.pluginMetadata.map { pluginId, metadata in
            let mappedPluginId = existingPluginIds.contains(pluginId) ? "\(pluginId)-imported-\(UUID().uuidString.prefix(8))" : pluginId
            return (
                mappedPluginId,
                StoredPluginMetadataRecord(
                    pluginId: mappedPluginId,
                    displayName: metadata.displayName,
                    version: metadata.version,
                    capabilities: metadata.capabilities,
                    isEnabled: metadata.isEnabled,
                    installedAt: metadata.installedAt
                )
            )
        })

        result.pluginBundles = Dictionary(uniqueKeysWithValues: incoming.pluginBundles.map { pluginId, bundle in
            let mappedPluginId = result.pluginMetadata[pluginId] != nil ? pluginId : (result.pluginMetadata.keys.first { $0.hasPrefix("\(pluginId)-imported-") } ?? pluginId)
            return (mappedPluginId, StoredPluginBundleRecord(pluginId: mappedPluginId, bundleData: bundle.bundleData))
        })

        result.credentials = nil
        result.pendingCredentialRotation = nil
        result.lastKnownUTC = nil
        result.rollbackGuardUntilUTC = nil
        return result
    }
}
