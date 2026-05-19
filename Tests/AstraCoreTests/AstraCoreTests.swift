import XCTest
@testable import AstraCore
@testable import AstraData
@testable import AstraPlatform

final class AstraCoreTests: XCTestCase {
    func testEncryptionRoundTrip() throws {
        let encryption = EncryptionService()
        let key = KeyMaterial(encryptionKey: Data(repeating: 7, count: 32))
        let plaintext = Data("secure payload".utf8)

        let payload = try encryption.encrypt(plaintext: plaintext, keyMaterial: key)
        let decrypted = try encryption.decrypt(payload: payload, keyMaterial: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testKeyManagerLockoutAfterFiveFailures() async throws {
        let database = DatabaseProvider()
        let settings = SettingsRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)
        let manager = KeyManager(settingsRepository: settings, timeProvider: time, logger: logger)

        try await manager.createInitialPassphrase("TopSecret!")

        for _ in 0..<5 {
            do {
                _ = try await manager.unlock(passphrase: "wrong")
                XCTFail("Expected invalid passphrase")
            } catch {}
        }

        do {
            _ = try await manager.unlock(passphrase: "TopSecret!")
            XCTFail("Expected lockout")
        } catch let KeyManagerError.lockoutActive(remaining) {
            XCTAssertGreaterThan(remaining, 0)
        }

        let entries = await logger.entries().map(\.event)
        XCTAssertTrue(entries.contains("unlock_lockout"))
    }

    func testNoteServiceSecureAndNormalStorageRules() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settings = SettingsRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)
        let keyManager = KeyManager(settingsRepository: settings, timeProvider: time, logger: logger)
        let service = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: time
        )

        try await keyManager.createInitialPassphrase("abc123")
        _ = try await keyManager.unlock(passphrase: "abc123")

        let normalId = try await service.save(
            draft: NoteDraft(
                title: "Normal",
                content: "Plain",
                subjectId: nil,
                secureModeEnabled: false,
                expirationUTC: nil
            )
        )
        let secureId = try await service.save(
            draft: NoteDraft(
                title: "Secure",
                content: "Encrypted",
                subjectId: nil,
                secureModeEnabled: true,
                expirationUTC: time.now().addingTimeInterval(600)
            )
        )

        let normalStored = await noteRepository.fetch(id: normalId)
        XCTAssertEqual(normalStored?.plainTitle, "Normal")
        XCTAssertNotNil(normalStored?.plainContent)
        XCTAssertNil(normalStored?.securePayload)

        let secureStored = await noteRepository.fetch(id: secureId)
        XCTAssertTrue(secureStored?.isSecure == true)
        XCTAssertNil(secureStored?.plainTitle)
        XCTAssertNil(secureStored?.plainContent)
        XCTAssertNotNil(secureStored?.securePayload)

        let loadedSecure = try await service.load(id: secureId)
        XCTAssertEqual(loadedSecure.title, "Secure")
        XCTAssertEqual(loadedSecure.content, "Encrypted")
    }

    func testSecureNotePolicyMovesExpiredSecureNotes() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)
        let notifications = InMemoryNotificationService(timeProvider: time)

        let keyManager = KeyManager(settingsRepository: settingsRepository, timeProvider: time, logger: logger)
        let noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: time
        )
        let policy = SecureNotePolicyService(
            noteRepository: noteRepository,
            noteService: noteService,
            settingsRepository: settingsRepository,
            notificationService: notifications,
            logger: logger,
            timeProvider: time
        )

        try await keyManager.createInitialPassphrase("phase3")
        _ = try await keyManager.unlock(passphrase: "phase3")

        let secureId = try await noteService.save(
            draft: NoteDraft(
                title: "Expires Soon",
                content: "payload",
                subjectId: nil,
                secureModeEnabled: true,
                expirationUTC: time.now().addingTimeInterval(5)
            )
        )
        let fetchedNoteCore = await noteRepository.fetch(id: secureId)
        XCTAssertNotNil(fetchedNoteCore)

        _ = try await policy.handleLaunchTimeCheckpoint()
        time.advance(seconds: 10)

        let sweep = try await policy.sweepExpiredSecureNotes(isForeground: true)
        XCTAssertEqual(sweep.expiredMovedCount, 1)
        let fetchedDeletedNote = await noteRepository.fetch(id: secureId)
        XCTAssertTrue(fetchedDeletedNote == nil)

        let events = await notifications.history()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.noteId, secureId)
    }

    func testRollbackGuardDefersExpirationChecks() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let now = Date()
        let time = MutableTimeProvider(now: now)
        let logger = InMemoryAuditLogger(timeProvider: time)
        let notifications = InMemoryNotificationService(timeProvider: time)

        let keyManager = KeyManager(settingsRepository: settingsRepository, timeProvider: time, logger: logger)
        let noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: time
        )
        let policy = SecureNotePolicyService(
            noteRepository: noteRepository,
            noteService: noteService,
            settingsRepository: settingsRepository,
            notificationService: notifications,
            logger: logger,
            timeProvider: time
        )

        try await keyManager.createInitialPassphrase("phase3")
        _ = try await keyManager.unlock(passphrase: "phase3")

        _ = try await noteService.save(
            draft: NoteDraft(
                title: "Guarded",
                content: "payload",
                subjectId: nil,
                secureModeEnabled: true,
                expirationUTC: now.addingTimeInterval(5)
            )
        )

        try await settingsRepository.saveLastKnownUTC(now.addingTimeInterval(3600))
        let launchResult = try await policy.handleLaunchTimeCheckpoint()
        XCTAssertTrue(launchResult.rollbackGuardActive)

        time.advance(seconds: 10)
        let sweep = try await policy.sweepExpiredSecureNotes(isForeground: true)
        XCTAssertTrue(sweep.rollbackGuardActive)
        XCTAssertEqual(sweep.expiredMovedCount, 0)
    }

    func testProtectedTrashRestoreSecureRequiresUnlock() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let trashRepository = ProtectedTrashRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)

        let keyManager = KeyManager(settingsRepository: settingsRepository, timeProvider: time, logger: logger)
        let noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: time
        )
        let trashService = ProtectedTrashService(trashRepository: trashRepository, keyManager: keyManager)

        try await keyManager.createInitialPassphrase("phase3")
        _ = try await keyManager.unlock(passphrase: "phase3")

        let id = try await noteService.save(
            draft: NoteDraft(
                title: "Secure",
                content: "payload",
                subjectId: nil,
                secureModeEnabled: true,
                expirationUTC: time.now().addingTimeInterval(120)
            )
        )
        _ = try await noteService.delete(noteId: id)

        let item = await trashService.listTrashItems().first
        XCTAssertNotNil(item)

        await keyManager.clearInMemoryKeyMaterial()
        do {
            _ = try await trashService.restore(trashId: try XCTUnwrap(item).trashId)
            XCTFail("Expected restore to require unlocked session")
        } catch let ProtectedTrashServiceError.restoreRequiresUnlockedSession {
            XCTAssertTrue(true)
        }

        _ = try await keyManager.unlock(passphrase: "phase3")
        let restored = try await trashService.restore(trashId: try XCTUnwrap(item).trashId)
        XCTAssertTrue(restored)
    }

    func testNoteSearchSecureCacheAndLockBehavior() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)
        let keyManager = KeyManager(settingsRepository: settingsRepository, timeProvider: time, logger: logger)
        let noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: time
        )
        let searchService = NoteSearchService(noteRepository: noteRepository, noteService: noteService)

        try await keyManager.createInitialPassphrase("phase4")
        _ = try await keyManager.unlock(passphrase: "phase4")

        _ = try await noteService.save(
            draft: NoteDraft(
                title: "Normal Algebra",
                content: "n",
                subjectId: nil,
                secureModeEnabled: false,
                expirationUTC: nil
            )
        )
        _ = try await noteService.save(
            draft: NoteDraft(
                title: "Secret Algebra",
                content: "s",
                subjectId: nil,
                secureModeEnabled: true,
                expirationUTC: time.now().addingTimeInterval(300)
            )
        )

        let unlockedResults = await searchService.searchTitle(query: "secret", isUnlocked: true)
        XCTAssertEqual(unlockedResults.count, 1)
        XCTAssertTrue(unlockedResults.first?.isSecure == true)
        let countBeforeLock = await searchService.secureCacheCount()
        XCTAssertEqual(countBeforeLock, 1)

        await searchService.clearSecureCacheOnLock()
        let countAfterLock = await searchService.secureCacheCount()
        XCTAssertEqual(countAfterLock, 0)
        let lockedResults = await searchService.searchTitle(query: "secret", isUnlocked: false)
        XCTAssertEqual(lockedResults.count, 0)
    }

    func testAttachmentLimitsAndSecurityModeInheritance() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)
        let keyManager = KeyManager(settingsRepository: settingsRepository, timeProvider: time, logger: logger)
        let noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: time
        )

        try await keyManager.createInitialPassphrase("phase4")
        _ = try await keyManager.unlock(passphrase: "phase4")

        let normalId = try await noteService.save(
            draft: NoteDraft(
                title: "Normal",
                content: "n",
                subjectId: nil,
                secureModeEnabled: false,
                expirationUTC: nil
            )
        )
        let secureId = try await noteService.save(
            draft: NoteDraft(
                title: "Secure",
                content: "s",
                subjectId: nil,
                secureModeEnabled: true,
                expirationUTC: time.now().addingTimeInterval(600)
            )
        )

        do {
            _ = try await noteService.addImageAttachment(
                noteId: normalId,
                storagePath: "/tmp/too-big.jpg",
                byteSize: 21 * 1024 * 1024
            )
            XCTFail("Expected image limit rejection")
        } catch let NoteServiceError.imageAttachmentTooLarge {
            XCTAssertTrue(true)
        }

        do {
            _ = try await noteService.addVoiceAttachment(
                noteId: normalId,
                storagePath: "/tmp/too-big.m4a",
                byteSize: 51 * 1024 * 1024
            )
            XCTFail("Expected voice limit rejection")
        } catch let NoteServiceError.voiceAttachmentTooLarge {
            XCTAssertTrue(true)
        }

        _ = try await noteService.addVoiceAttachment(noteId: normalId, storagePath: "/tmp/a.m4a", byteSize: 1_024)
        _ = try await noteService.addVoiceAttachment(noteId: secureId, storagePath: "/tmp/b.m4a", byteSize: 1_024)

        let normalAttachments = await noteService.listAttachments(noteId: normalId)
        let secureAttachments = await noteService.listAttachments(noteId: secureId)
        XCTAssertEqual(normalAttachments.count, 1)
        XCTAssertEqual(secureAttachments.count, 1)
        XCTAssertFalse(normalAttachments[0].isEncrypted)
        XCTAssertTrue(secureAttachments[0].isEncrypted)
    }

    @MainActor
    func testAppCoordinatorFirstLaunchAndDeferredAutoLock() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)

        let keyManager = KeyManager(settingsRepository: settingsRepository, timeProvider: time, logger: logger)
        let noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: time
        )
        let searchService = NoteSearchService(noteRepository: noteRepository, noteService: noteService)
        let settingsService = SettingsService(repository: settingsRepository)
        try await settingsService.update(lockTimeoutSeconds: 30, telemetryEnabled: false, pluginsEnabled: true)

        let coordinator = AppCoordinator(
            keyManager: keyManager,
            settingsService: settingsService,
            noteSearchService: searchService,
            now: Date(timeIntervalSince1970: 0)
        )

        await coordinator.start(now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(coordinator.sessionState, .firstLaunchSetup)

        try await coordinator.createInitialPassphraseAndUnlock("phase4")
        XCTAssertEqual(coordinator.sessionState, .unlocked)

        coordinator.registerUserInteraction(now: Date(timeIntervalSince1970: 0))
        coordinator.beginBackgroundOperation()
        await coordinator.evaluateInactivityAutoLock(now: Date(timeIntervalSince1970: 50))
        XCTAssertEqual(coordinator.sessionState, .unlocked)

        await coordinator.endBackgroundOperation()
        XCTAssertEqual(coordinator.sessionState, .locked)
    }
}
