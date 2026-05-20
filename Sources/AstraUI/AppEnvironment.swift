import Foundation
import SwiftUI
import AstraCore
import AstraData
import AstraPlatform

@MainActor
final class AppEnvironment: ObservableObject {
    let database = DatabaseProvider(persistenceURL: DatabaseProvider.defaultPersistenceURL())
    let timeProvider = SystemTimeProvider()
    let logger: InMemoryAuditLogger
    let notificationService: InMemoryNotificationService
    let localAuthService: InMemoryLocalAuthService
    let storageProtection: InMemoryStorageProtection
    let platformIntegration: InMemoryPlatformIntegration

    let settingsRepository: SettingsRepository
    let noteRepository: NoteRepository
    let attachmentRepository: AttachmentRepository
    let subjectRepository: SubjectRepository
    let trashRepository: ProtectedTrashRepository
    let pluginMetadataRepository: PluginMetadataRepository
    let pluginBundleRepository: PluginBundleRepository

    let keyManager: KeyManager
    let settingsService: SettingsService
    let noteService: NoteService
    let subjectService: SubjectService
    let trashService: ProtectedTrashService
    let noteSearchService: NoteSearchService
    let secureNotePolicyService: SecureNotePolicyService
    let exportImportService: ExportImportService
    let pluginService: PluginService
    let coordinator: AppCoordinator

    init() {
        logger = InMemoryAuditLogger(timeProvider: timeProvider)
        notificationService = InMemoryNotificationService(timeProvider: timeProvider)
        localAuthService = InMemoryLocalAuthService()
        storageProtection = InMemoryStorageProtection()
        platformIntegration = InMemoryPlatformIntegration()

        settingsRepository = SettingsRepository(database: database)
        noteRepository = NoteRepository(database: database)
        attachmentRepository = AttachmentRepository(database: database)
        subjectRepository = SubjectRepository(database: database)
        trashRepository = ProtectedTrashRepository(database: database)
        pluginMetadataRepository = PluginMetadataRepository(database: database)
        pluginBundleRepository = PluginBundleRepository(database: database)

        keyManager = KeyManager(
            settingsRepository: settingsRepository,
            databaseProvider: database,
            timeProvider: timeProvider,
            logger: logger
        )
        settingsService = SettingsService(repository: settingsRepository)
        noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: timeProvider,
            storageProtection: storageProtection
        )
        subjectService = SubjectService(repository: subjectRepository)
        trashService = ProtectedTrashService(trashRepository: trashRepository, keyManager: keyManager)
        noteSearchService = NoteSearchService(noteRepository: noteRepository, noteService: noteService)
        secureNotePolicyService = SecureNotePolicyService(
            noteRepository: noteRepository,
            noteService: noteService,
            settingsRepository: settingsRepository,
            notificationService: notificationService,
            logger: logger,
            timeProvider: timeProvider
        )
        exportImportService = ExportImportService(
            database: database,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            logger: logger
        )
        pluginService = PluginService(
            metadataRepository: pluginMetadataRepository,
            bundleRepository: pluginBundleRepository,
            settingsService: settingsService,
            logger: logger
        )
        coordinator = AppCoordinator(
            keyManager: keyManager,
            settingsService: settingsService,
            noteSearchService: noteSearchService,
            localAuthService: localAuthService
        )
    }
}
