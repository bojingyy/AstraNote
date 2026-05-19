import XCTest
@testable import AstraCore
@testable import AstraData
@testable import AstraPlatform

final class AstraIntegrationTests: XCTestCase {
    func testPhase1And2HappyPathFlow() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let clock = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: clock)

        let keyManager = KeyManager(settingsRepository: settingsRepository, timeProvider: clock, logger: logger)
        let noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: clock
        )
        let subjectService = SubjectService(repository: subjectRepository)
        let settingsService = SettingsService(repository: settingsRepository)

        let hasPassphraseInitially = await keyManager.hasPassphrase()
        XCTAssertFalse(hasPassphraseInitially)
        try await keyManager.createInitialPassphrase("my-passphrase")
        _ = try await keyManager.unlock(passphrase: "my-passphrase")

        let subject = try await subjectService.create(name: "CSE296")
        let id = try await noteService.save(
            draft: NoteDraft(
                title: "Secure Draft",
                content: "phase 2 content",
                subjectId: subject.id,
                secureModeEnabled: true,
                expirationUTC: clock.now().addingTimeInterval(600)
            )
        )

        let loaded = try await noteService.load(id: id)
        XCTAssertEqual(loaded.title, "Secure Draft")
        XCTAssertEqual(loaded.subjectId, subject.id)
        XCTAssertTrue(loaded.isSecure)

        try await settingsService.update(lockTimeoutSeconds: 600, telemetryEnabled: true, pluginsEnabled: false)
        let updatedSettings = await settingsService.load()
        XCTAssertEqual(updatedSettings.lockTimeoutSeconds, 600)
        XCTAssertTrue(updatedSettings.telemetryEnabled)
        XCTAssertFalse(updatedSettings.pluginsEnabled)

        let deleted = try await noteService.delete(noteId: id)
        XCTAssertTrue(deleted)
        let deletedNote = await noteRepository.fetch(id: id)
        XCTAssertNil(deletedNote)

        let state = await database.read { $0 }
        XCTAssertEqual(state.trash.count, 1)
    }

    func testPhase3And4SecureExpirationTrashAndSearchFlow() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let trashRepository = ProtectedTrashRepository(database: database)
        let clock = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: clock)
        let notificationService = InMemoryNotificationService(timeProvider: clock)

        let keyManager = KeyManager(settingsRepository: settingsRepository, timeProvider: clock, logger: logger)
        let noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: clock
        )
        let policyService = SecureNotePolicyService(
            noteRepository: noteRepository,
            noteService: noteService,
            settingsRepository: settingsRepository,
            notificationService: notificationService,
            logger: logger,
            timeProvider: clock
        )
        let searchService = NoteSearchService(noteRepository: noteRepository, noteService: noteService)
        let trashService = ProtectedTrashService(trashRepository: trashRepository, keyManager: keyManager)

        try await keyManager.createInitialPassphrase("phase34")
        _ = try await keyManager.unlock(passphrase: "phase34")

        _ = try await noteService.save(
            draft: NoteDraft(
                title: "Secure Search Title",
                content: "payload",
                subjectId: nil,
                secureModeEnabled: true,
                expirationUTC: clock.now().addingTimeInterval(20)
            )
        )

        let unlockedSearch = await searchService.searchTitle(query: "secure", isUnlocked: true)
        XCTAssertEqual(unlockedSearch.count, 1)
        XCTAssertTrue(unlockedSearch[0].isSecure)

        _ = try await policyService.handleLaunchTimeCheckpoint()
        clock.advance(seconds: 30)
        let sweep = try await policyService.sweepExpiredSecureNotes(isForeground: true)
        XCTAssertEqual(sweep.expiredMovedCount, 1)

        let trashItems = await trashService.listTrashItems()
        XCTAssertEqual(trashItems.count, 1)
        XCTAssertTrue(trashItems[0].lockBadgeVisible)
        XCTAssertNil(trashItems[0].displayTitle)

        let securePreview = try await trashService.secureTitlePreviewMessage(trashId: trashItems[0].trashId)
        XCTAssertEqual(securePreview, "This secure note is locked and cannot be previewed until restored and unlocked.")

        await keyManager.clearInMemoryKeyMaterial()
        await searchService.clearSecureCacheOnLock()
        let lockedSearch = await searchService.searchTitle(query: "secure", isUnlocked: false)
        XCTAssertTrue(lockedSearch.isEmpty)
    }
}
