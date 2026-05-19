import Foundation
import SwiftUI
import AstraCore
import AstraData
import AstraPlatform

@MainActor
final class AppEnvironment: ObservableObject {
    let database = DatabaseProvider()
    let timeProvider = SystemTimeProvider()
    let logger: InMemoryAuditLogger
    let notificationService: InMemoryNotificationService

    let settingsRepository: SettingsRepository
    let noteRepository: NoteRepository
    let attachmentRepository: AttachmentRepository
    let subjectRepository: SubjectRepository
    let trashRepository: ProtectedTrashRepository

    let keyManager: KeyManager
    let settingsService: SettingsService
    let noteService: NoteService
    let subjectService: SubjectService
    let trashService: ProtectedTrashService
    let noteSearchService: NoteSearchService
    let secureNotePolicyService: SecureNotePolicyService
    let coordinator: AppCoordinator

    init() {
        logger = InMemoryAuditLogger(timeProvider: timeProvider)
        notificationService = InMemoryNotificationService(timeProvider: timeProvider)

        settingsRepository = SettingsRepository(database: database)
        noteRepository = NoteRepository(database: database)
        attachmentRepository = AttachmentRepository(database: database)
        subjectRepository = SubjectRepository(database: database)
        trashRepository = ProtectedTrashRepository(database: database)

        keyManager = KeyManager(settingsRepository: settingsRepository, timeProvider: timeProvider, logger: logger)
        settingsService = SettingsService(repository: settingsRepository)
        noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: timeProvider
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
        coordinator = AppCoordinator(
            keyManager: keyManager,
            settingsService: settingsService,
            noteSearchService: noteSearchService
        )
    }
}
