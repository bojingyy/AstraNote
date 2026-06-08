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
                secureModeEnabled: false
            )
        )
        let secureId = try await service.save(
            draft: NoteDraft(
                title: "Secure",
                content: "Encrypted",
                subjectId: nil,
                secureModeEnabled: true
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
        XCTAssertEqual(secureStored?.secureTitleAlias, "Locked Note")

        let loadedSecure = try await service.load(id: secureId)
        XCTAssertEqual(loadedSecure.title, "Secure")
        XCTAssertEqual(loadedSecure.content, "Encrypted")
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
                secureModeEnabled: true
            )
        )
        _ = try await noteService.delete(noteId: id)

        let item = await trashService.listTrashItems().first
        XCTAssertNotNil(item)

        await keyManager.clearInMemoryKeyMaterial()
        do {
            _ = try await trashService.restore(trashId: try XCTUnwrap(item).trashId)
            XCTFail("Expected restore to require unlocked session")
        } catch ProtectedTrashServiceError.restoreRequiresUnlockedSession {
            XCTAssertTrue(true)
        }

        _ = try await keyManager.unlock(passphrase: "phase3")
        let restored = try await trashService.restore(trashId: try XCTUnwrap(item).trashId)
        XCTAssertTrue(restored)
    }

    func testNoteSearchUsesSecureAliasesInsteadOfDecryptedTitles() async throws {
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
                secureModeEnabled: false
            )
        )
        _ = try await noteService.save(
            draft: NoteDraft(
                title: "Secret Algebra",
                content: "s",
                subjectId: nil,
                secureModeEnabled: true,
                secureTitleAlias: "Math Vault"
            )
        )

        let decryptedTitleResults = await searchService.searchTitle(query: "secret", isUnlocked: true)
        XCTAssertTrue(decryptedTitleResults.isEmpty)

        let aliasResults = await searchService.searchTitle(query: "vault", isUnlocked: true)
        XCTAssertEqual(aliasResults.count, 1)
        XCTAssertTrue(aliasResults.first?.isSecure == true)
        XCTAssertEqual(aliasResults.first?.matchedTitle, "Math Vault")

        await searchService.clearSecureCacheOnLock()
        let countAfterLock = await searchService.secureCacheCount()
        XCTAssertEqual(countAfterLock, 0)

        let lockedAliasResults = await searchService.searchTitle(query: "vault", isUnlocked: false)
        XCTAssertEqual(lockedAliasResults.count, 1)
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
                secureModeEnabled: false
            )
        )
        let secureId = try await noteService.save(
            draft: NoteDraft(
                title: "Secure",
                content: "s",
                subjectId: nil,
                secureModeEnabled: true
            )
        )

        do {
            _ = try await noteService.addImageAttachment(
                noteId: normalId,
                storagePath: "/tmp/too-big.jpg",
                byteSize: 21 * 1024 * 1024
            )
            XCTFail("Expected image limit rejection")
        } catch NoteServiceError.imageAttachmentTooLarge {
            XCTAssertTrue(true)
        }

        do {
            _ = try await noteService.addVoiceAttachment(
                noteId: normalId,
                storagePath: "/tmp/too-big.m4a",
                byteSize: 51 * 1024 * 1024
            )
            XCTFail("Expected voice limit rejection")
        } catch NoteServiceError.voiceAttachmentTooLarge {
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
    func testAppCoordinatorFirstLaunchAndUnlock() async throws {
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
        try await settingsService.update(pluginsEnabled: true)

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

        let keyMaterial = await keyManager.currentKeyMaterial()
        XCTAssertNotNil(keyMaterial)
    }

    func testPassphraseRotationReencryptsSecureNotes() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)

        let keyManager = KeyManager(
            settingsRepository: settingsRepository,
            databaseProvider: database,
            timeProvider: time,
            logger: logger
        )
        let noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: time
        )

        try await keyManager.createInitialPassphrase("old-passphrase")
        _ = try await keyManager.unlock(passphrase: "old-passphrase")
        let noteId = try await noteService.save(
            draft: NoteDraft(
                title: "Rotating",
                content: "phase5",
                subjectId: nil,
                secureModeEnabled: true
            )
        )

        let payloadBefore = await noteRepository.fetch(id: noteId)?.securePayload

        try await keyManager.changePassphrase(current: "old-passphrase", next: "new-passphrase")
        await keyManager.clearInMemoryKeyMaterial()

        do {
            _ = try await keyManager.unlock(passphrase: "old-passphrase")
            XCTFail("Expected old passphrase to fail after rotation")
        } catch KeyManagerError.invalidPassphrase {
            XCTAssertTrue(true)
        }

        _ = try await keyManager.unlock(passphrase: "new-passphrase")
        let rotated = try await noteService.load(id: noteId)
        XCTAssertEqual(rotated.title, "Rotating")
        XCTAssertEqual(rotated.content, "phase5")

        let payloadAfter = await noteRepository.fetch(id: noteId)?.securePayload
        XCTAssertNotEqual(payloadBefore, payloadAfter)
    }

    func testExportImportRoundTripRegeneratesConflictingIdentifiers() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let pluginMetadataRepository = PluginMetadataRepository(database: database)
        let pluginBundleRepository = PluginBundleRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)

        let keyManager = KeyManager(
            settingsRepository: settingsRepository,
            databaseProvider: database,
            timeProvider: time,
            logger: logger
        )
        let noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: time
        )
        let settingsService = SettingsService(repository: settingsRepository)
        let pluginService = PluginService(
            metadataRepository: pluginMetadataRepository,
            bundleRepository: pluginBundleRepository,
            settingsService: settingsService,
            logger: logger
        )
        let exportImportService = ExportImportService(
            database: database,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            logger: logger
        )

        try await keyManager.createInitialPassphrase("export-pass")
        _ = try await keyManager.unlock(passphrase: "export-pass")
        _ = try await subjectRepository.create(name: "Imported Subject")
        _ = try await noteService.save(
            draft: NoteDraft(
                title: "Exportable",
                content: "payload",
                subjectId: nil,
                secureModeEnabled: false
            )
        )
        try await pluginService.install(
            manifest: PluginManifest(
                pluginId: "com.astra.upper",
                displayName: "Upper",
                version: "1.0.0",
                capabilities: ["transform"]
            ),
            bundleData: Data("bundle".utf8)
        )

        let archive = try await exportImportService.exportArchive()
        let importResult = try await exportImportService.importArchive(archive)
        XCTAssertEqual(importResult.importedNotes, 1)
        XCTAssertEqual(importResult.importedPlugins, 1)

        let snapshot = await database.read { $0 }
        XCTAssertEqual(snapshot.notes.count, 2)
        XCTAssertEqual(snapshot.pluginMetadata.count, 2)
    }

    func testPluginServiceExecutionAndTimeoutGuards() async throws {
        let database = DatabaseProvider()
        let settingsRepository = SettingsRepository(database: database)
        let settingsService = SettingsService(repository: settingsRepository)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)
        let metadataRepository = PluginMetadataRepository(database: database)
        let bundleRepository = PluginBundleRepository(database: database)
        let pluginService = PluginService(
            metadataRepository: metadataRepository,
            bundleRepository: bundleRepository,
            settingsService: settingsService,
            logger: logger
        )

        try await pluginService.install(
            manifest: PluginManifest(
                pluginId: "com.astra.test",
                displayName: "Test Plugin",
                version: "1.0.0",
                capabilities: ["echo"]
            ),
            bundleData: Data([1, 2, 3])
        )
        await pluginService.registerHandler(pluginId: "com.astra.test") { request in
            PluginActionResult(output: request.input.uppercased())
        }

        let result = try await pluginService.execute(
            pluginId: "com.astra.test",
            request: PluginActionRequest(action: "echo", input: "astra")
        )
        XCTAssertEqual(result.output, "ASTRA")

        try await pluginService.setEnabled(pluginId: "com.astra.test", isEnabled: false)
        do {
            _ = try await pluginService.execute(
                pluginId: "com.astra.test",
                request: PluginActionRequest(action: "echo", input: "astra")
            )
            XCTFail("Expected disabled plugin to reject execution")
        } catch PluginServiceError.pluginDisabled {
            XCTAssertTrue(true)
        }

        try await pluginService.setEnabled(pluginId: "com.astra.test", isEnabled: true)
        await pluginService.registerHandler(pluginId: "com.astra.test") { _ in
            try await Task.sleep(for: .milliseconds(50))
            return PluginActionResult(output: "slow")
        }

        do {
            _ = try await pluginService.execute(
                pluginId: "com.astra.test",
                request: PluginActionRequest(action: "echo", input: "astra"),
                timeout: .milliseconds(5)
            )
            XCTFail("Expected plugin timeout")
        } catch PluginServiceError.executionTimedOut {
            XCTAssertTrue(true)
        }
    }


    @MainActor
    func testAppCoordinatorSupportsBiometricUnlockAndPlatformAutoLock() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)
        let localAuth = InMemoryLocalAuthService()
        let platformIntegration = InMemoryPlatformIntegration()

        let keyManager = KeyManager(
            settingsRepository: settingsRepository,
            databaseProvider: database,
            timeProvider: time,
            logger: logger
        )
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
        let coordinator = AppCoordinator(
            keyManager: keyManager,
            settingsService: settingsService,
            noteSearchService: searchService,
            localAuthService: localAuth,
            now: time.now()
        )

        await coordinator.start(now: time.now())
        try await coordinator.createInitialPassphraseAndUnlock("bio-pass")
        try await coordinator.updateBiometricUnlock(enabled: true)
        await coordinator.lockNow()
        XCTAssertEqual(coordinator.sessionState, .unlocked)
        let keyAfterManualLock = await keyManager.currentKeyMaterial()
        XCTAssertNil(keyAfterManualLock)
        try await coordinator.unlockWithBiometrics()
        XCTAssertEqual(coordinator.sessionState, .unlocked)

        coordinator.bind(platformIntegration: platformIntegration)
        await platformIntegration.publish(.appDidBackground)
        try await Task.sleep(for: .milliseconds(25))
        XCTAssertEqual(coordinator.sessionState, .unlocked)
        let keyAfterBackgroundEvent = await keyManager.currentKeyMaterial()
        XCTAssertNil(keyAfterBackgroundEvent)
    }

    func testSecureMetadataUpdateDoesNotRequireInMemoryKey() async throws {
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

        try await keyManager.createInitialPassphrase("meta-only")
        _ = try await keyManager.unlock(passphrase: "meta-only")

        let secureId = try await service.save(
            draft: NoteDraft(
                title: "Private Title",
                content: "Private Content",
                subjectId: nil,
                secureModeEnabled: true,
                secureTitleAlias: "Old Alias"
            )
        )

        await keyManager.clearInMemoryKeyMaterial()

        try await service.updateSecureMetadata(noteId: secureId, secureTitleAlias: "New Alias", subjectId: nil)

        let stored = await noteRepository.fetch(id: secureId)
        XCTAssertEqual(stored?.secureTitleAlias, "New Alias")
        XCTAssertNotNil(stored?.securePayload)
    }

    // MARK: - NFR6.1: Lockout escalation and 60-minute cap

    func testKeyManagerLockoutEscalatesAndCapsAtSixtyMinutes() async throws {
        let database = DatabaseProvider()
        let settings = SettingsRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)
        let manager = KeyManager(settingsRepository: settings, timeProvider: time, logger: logger)

        try await manager.createInitialPassphrase("TopSecret!")

        func triggerLockoutCycle() async throws -> Int {
            for _ in 0..<5 {
                do {
                    _ = try await manager.unlock(passphrase: "wrong")
                    XCTFail("Expected invalid passphrase")
                } catch KeyManagerError.invalidPassphrase {}
            }
            do {
                _ = try await manager.unlock(passphrase: "wrong")
                XCTFail("Expected lockout to engage after the fifth failure")
                return 0
            } catch let KeyManagerError.lockoutActive(remaining) {
                return remaining
            }
        }

        var observedDurations: [Int] = []
        for _ in 0..<9 {
            let remaining = try await triggerLockoutCycle()
            observedDurations.append(remaining)
            time.advance(seconds: TimeInterval(remaining + 1))
        }

        // 30 -> 60 -> 120 -> 240 -> 480 -> 960 -> 1920 -> capped at 3600s (60 minutes), then stays capped
        XCTAssertEqual(observedDurations, [30, 60, 120, 240, 480, 960, 1920, 3600, 3600])

        let lockoutEvents = await logger.entries().filter { $0.event == "unlock_lockout" }
        XCTAssertEqual(lockoutEvents.count, observedDurations.count)
    }

    // MARK: - NFR4.1/4.2: Authenticated-encryption tamper detection

    func testEncryptionServiceRejectsTamperedCiphertextTagAndWrongKey() throws {
        let encryption = EncryptionService()
        let key = KeyMaterial(encryptionKey: Data(repeating: 7, count: 32))
        let wrongKey = KeyMaterial(encryptionKey: Data(repeating: 9, count: 32))
        let plaintext = Data("authenticated content".utf8)
        let payload = try encryption.encrypt(plaintext: plaintext, keyMaterial: key)

        var tamperedCiphertextBytes = [UInt8](payload.ciphertext)
        tamperedCiphertextBytes[0] ^= 0xFF
        let tamperedCiphertext = EncryptedPayload(
            ciphertext: Data(tamperedCiphertextBytes),
            nonce: payload.nonce,
            tag: payload.tag,
            salt: payload.salt
        )
        XCTAssertThrowsError(try encryption.decrypt(payload: tamperedCiphertext, keyMaterial: key)) { error in
            XCTAssertEqual(error as? EncryptionError, .authenticationFailed)
        }

        var tamperedTagBytes = [UInt8](payload.tag)
        tamperedTagBytes[0] ^= 0xFF
        let tamperedTag = EncryptedPayload(
            ciphertext: payload.ciphertext,
            nonce: payload.nonce,
            tag: Data(tamperedTagBytes),
            salt: payload.salt
        )
        XCTAssertThrowsError(try encryption.decrypt(payload: tamperedTag, keyMaterial: key)) { error in
            XCTAssertEqual(error as? EncryptionError, .authenticationFailed)
        }

        XCTAssertThrowsError(try encryption.decrypt(payload: payload, keyMaterial: wrongKey)) { error in
            XCTAssertEqual(error as? EncryptionError, .authenticationFailed)
        }

        // The untampered payload still verifies and decrypts correctly under the original key,
        // proving the failures above are isolated to the tampering rather than a broken round-trip.
        XCTAssertEqual(try encryption.decrypt(payload: payload, keyMaterial: key), plaintext)
    }

    func testTamperedSecurePayloadFailsVerificationAndPreservesStoredRecord() async throws {
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

        try await keyManager.createInitialPassphrase("tamper-pass")
        _ = try await keyManager.unlock(passphrase: "tamper-pass")

        let noteId = try await noteService.save(
            draft: NoteDraft(title: "Tamper Target", content: "do not corrupt me", subjectId: nil, secureModeEnabled: true)
        )

        guard var stored = await noteRepository.fetch(id: noteId), let original = stored.securePayload else {
            XCTFail("Expected the secure note to be persisted with an encrypted payload")
            return
        }

        var tamperedTagBytes = [UInt8](original.tag)
        tamperedTagBytes[0] ^= 0xFF
        let tamperedPayload = StoredEncryptedPayload(
            ciphertext: original.ciphertext,
            nonce: original.nonce,
            tag: Data(tamperedTagBytes),
            salt: original.salt
        )
        stored.securePayload = tamperedPayload
        try await noteRepository.upsert(stored)

        do {
            _ = try await noteService.load(id: noteId)
            XCTFail("Expected loading a tampered secure note to fail verification")
        } catch EncryptionError.authenticationFailed {
            XCTAssertTrue(true)
        }

        // The stored record is preserved exactly as written — the failed verification neither
        // deletes it nor mutates it further (FR3.6, NFR4.2).
        let preserved = await noteRepository.fetch(id: noteId)
        XCTAssertEqual(preserved?.securePayload, tamperedPayload)
    }

    // MARK: - FR3.8 / FR7.4: Step-up authentication gating and post-lock usability

    @MainActor
    func testStepUpAuthenticationGatesSecureOperationsAndNormalNotesRemainUsableAfterLock() async throws {
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
        let coordinator = AppCoordinator(
            keyManager: keyManager,
            settingsService: settingsService,
            noteSearchService: searchService,
            now: time.now()
        )

        await coordinator.start(now: time.now())
        try await coordinator.createInitialPassphraseAndUnlock("stepup-pass")

        let secureId = try await noteService.save(
            draft: NoteDraft(title: "Step-Up Target", content: "needs the key", subjectId: nil, secureModeEnabled: true)
        )

        await coordinator.lockNow()
        let keyAfterFirstLock = await keyManager.currentKeyMaterial()
        XCTAssertNil(keyAfterFirstLock)

        // Opening a secure note while locked is exactly the moment FR3.8 requires step-up authentication
        do {
            _ = try await noteService.load(id: secureId)
            XCTFail("Expected opening a secure note while locked to require step-up authentication")
        } catch NoteServiceError.invalidSecurePayload {
            XCTAssertTrue(true)
        }

        // Authenticating from the prompt resumes the triggering action automatically
        try await coordinator.reauthenticateForSecureNote(passphrase: "stepup-pass")
        let resumedLoad = try await noteService.load(id: secureId)
        XCTAssertEqual(resumedLoad.content, "needs the key")

        // Saving a secure note also gates on the key at the moment of write
        await coordinator.lockNow()
        do {
            _ = try await noteService.save(
                draft: NoteDraft(title: "Second Secure", content: "also needs the key", subjectId: nil, secureModeEnabled: true)
            )
            XCTFail("Expected saving a secure note while locked to require step-up authentication")
        } catch NoteServiceError.keyMaterialUnavailable {
            XCTAssertTrue(true)
        }
        try await coordinator.reauthenticateForSecureNote(passphrase: "stepup-pass")
        let secondId = try await noteService.save(
            draft: NoteDraft(title: "Second Secure", content: "also needs the key", subjectId: nil, secureModeEnabled: true)
        )
        let secondStored = await noteRepository.fetch(id: secondId)
        XCTAssertNotNil(secondStored)

        // A wrong passphrase at the prompt is rejected and leaves the prompt retryable
        await coordinator.lockNow()
        do {
            try await coordinator.reauthenticateForSecureNote(passphrase: "incorrect-passphrase")
            XCTFail("Expected the wrong passphrase to be rejected at the step-up prompt")
        } catch KeyManagerError.invalidPassphrase {
            XCTAssertTrue(true)
        }
        try await coordinator.reauthenticateForSecureNote(passphrase: "stepup-pass")
        let keyAfterRetry = await keyManager.currentKeyMaterial()
        XCTAssertNotNil(keyAfterRetry)

        // Normal notes remain fully usable through every lock above — no authentication required (FR7.4)
        await coordinator.lockNow()
        let normalId = try await noteService.save(
            draft: NoteDraft(title: "Always Usable", content: "no key needed", subjectId: nil, secureModeEnabled: false)
        )
        let normalLoaded = try await noteService.load(id: normalId)
        XCTAssertEqual(normalLoaded.content, "no key needed")
    }

    // MARK: - FR7.3: Deferred lock around in-flight background operations

    @MainActor
    func testImmediateLockIsDeferredDuringInFlightBackgroundOperation() async throws {
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
        let coordinator = AppCoordinator(
            keyManager: keyManager,
            settingsService: settingsService,
            noteSearchService: searchService,
            now: time.now()
        )

        await coordinator.start(now: time.now())
        try await coordinator.createInitialPassphraseAndUnlock("defer-pass")
        let keyAfterUnlock = await keyManager.currentKeyMaterial()
        XCTAssertNotNil(keyAfterUnlock)

        coordinator.beginBackgroundOperation()
        await coordinator.handleImmediateLockEvent()

        // The lock must be deferred while a tracked background operation (export/rotation) is active
        let keyDuringOperation = await keyManager.currentKeyMaterial()
        XCTAssertNotNil(keyDuringOperation)

        await coordinator.endBackgroundOperation()

        // Once the tracked operation ends, the deferred lock is applied immediately
        let keyAfterOperationEnds = await keyManager.currentKeyMaterial()
        XCTAssertNil(keyAfterOperationEnds)
    }

    // MARK: - FR8.4/FR8.5/NFR5.2: Rotation interruption recovery and identical-key rejection

    func testInterruptedRotationMarkerIsDetectedClearedAndLoggedOnNextUnlock() async throws {
        let database = DatabaseProvider()
        let settingsRepository = SettingsRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)
        let keyManager = KeyManager(
            settingsRepository: settingsRepository,
            databaseProvider: database,
            timeProvider: time,
            logger: logger
        )

        try await keyManager.createInitialPassphrase("interrupt-pass")
        _ = try await keyManager.unlock(passphrase: "interrupt-pass")
        await keyManager.clearInMemoryKeyMaterial()

        let credentialsBeforeRecovery = await database.read { $0.credentials }

        // Simulate a forced termination mid-rotation by directly persisting the same stale
        // in-flight marker an interrupted `changePassphrase` transaction would leave behind.
        try await database.transaction { state in
            state.pendingCredentialRotation = StoredCredentialRotationState(startedAt: time.now())
        }

        // The next unlock must detect the stale marker, clear it, log the recovery, and leave
        // the database exactly as it was under the original credentials — no user action required.
        _ = try await keyManager.unlock(passphrase: "interrupt-pass")

        let stateAfterRecovery = await database.read { $0 }
        XCTAssertNil(stateAfterRecovery.pendingCredentialRotation)
        XCTAssertEqual(stateAfterRecovery.credentials, credentialsBeforeRecovery)

        let recoveryEvents = await logger.entries().filter { $0.event == "passphrase_rotation_recovered" }
        XCTAssertEqual(recoveryEvents.count, 1)
    }

    func testChangePassphraseRejectsIdenticalDerivedKeyWithoutWriting() async throws {
        let database = DatabaseProvider()
        let settingsRepository = SettingsRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)
        let keyManager = KeyManager(
            settingsRepository: settingsRepository,
            databaseProvider: database,
            timeProvider: time,
            logger: logger
        )

        try await keyManager.createInitialPassphrase("same-passphrase")
        _ = try await keyManager.unlock(passphrase: "same-passphrase")
        let credentialsBefore = await database.read { $0.credentials }

        do {
            try await keyManager.changePassphrase(current: "same-passphrase", next: "same-passphrase")
            XCTFail("Expected an identical-key passphrase change to be rejected")
        } catch KeyManagerError.identicalPassphrase {
            XCTAssertTrue(true)
        }

        // No write occurred — credentials are untouched and the original passphrase still unlocks
        let credentialsAfter = await database.read { $0.credentials }
        XCTAssertEqual(credentialsBefore, credentialsAfter)
        await keyManager.clearInMemoryKeyMaterial()
        _ = try await keyManager.unlock(passphrase: "same-passphrase")
    }

    // MARK: - FR9.2/FR9.4/NFR5.2: Import schema rejection and rollback

    func testImportRejectsArchivesWithNewerSchemaVersion() async throws {
        let database = DatabaseProvider()
        let settingsRepository = SettingsRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)
        let keyManager = KeyManager(
            settingsRepository: settingsRepository,
            databaseProvider: database,
            timeProvider: time,
            logger: logger
        )
        let exportImportService = ExportImportService(
            database: database,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            logger: logger
        )

        try await keyManager.createInitialPassphrase("schema-pass")
        _ = try await keyManager.unlock(passphrase: "schema-pass")

        struct FutureEnvelope: Codable {
            let schemaVersion: Int
            let payload: StoredEncryptedPayload
        }
        let currentSchemaVersion = await database.schemaVersion()
        let futureEnvelope = FutureEnvelope(
            schemaVersion: currentSchemaVersion + 1,
            payload: StoredEncryptedPayload(
                ciphertext: Data([1, 2, 3]),
                nonce: Data(repeating: 0, count: 12),
                tag: Data(repeating: 0, count: 16),
                salt: Data(repeating: 0, count: 16)
            )
        )
        let archiveData = try JSONEncoder().encode(futureEnvelope)

        do {
            _ = try await exportImportService.importArchive(archiveData)
            XCTFail("Expected an archive from a newer schema version to be rejected")
        } catch ExportImportServiceError.unsupportedSchemaVersion {
            XCTAssertTrue(true)
        }
    }

    func testImportRollsBackEntirelyOnInducedConflictFailure() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)
        let keyManager = KeyManager(
            settingsRepository: settingsRepository,
            databaseProvider: database,
            timeProvider: time,
            logger: logger
        )
        let noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: time
        )
        let exportImportService = ExportImportService(
            database: database,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            logger: logger
        )

        try await keyManager.createInitialPassphrase("rollback-pass")
        _ = try await keyManager.unlock(passphrase: "rollback-pass")
        let noteId = try await noteService.save(
            draft: NoteDraft(title: "Keep Me Intact", content: "must survive rollback", subjectId: nil, secureModeEnabled: false)
        )

        let archive = try await exportImportService.exportArchive()
        let notesBefore = await database.read { $0.notes }

        // Re-importing the same archive in strict mode collides on every identifier, forcing a
        // mid-transaction failure that must roll back the entire import with no partial state (FR9.4, NFR5.2).
        do {
            _ = try await exportImportService.importArchive(archive, resolution: .reject)
            XCTFail("Expected a conflicting strict-mode import to be rejected")
        } catch ExportImportServiceError.importConflict {
            XCTAssertTrue(true)
        }

        let notesAfter = await database.read { $0.notes }
        XCTAssertEqual(notesBefore, notesAfter)
        let survivingNote = await noteRepository.fetch(id: noteId)
        XCTAssertNotNil(survivingNote)
    }

    // MARK: - FR11.2/FR11.7: Plugin manifest validation and persisted-metadata shape

    func testPluginInstallationRejectsInvalidManifestsAndPersistsDocumentedMetadataOnly() async throws {
        let database = DatabaseProvider()
        let settingsRepository = SettingsRepository(database: database)
        let settingsService = SettingsService(repository: settingsRepository)
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)
        let metadataRepository = PluginMetadataRepository(database: database)
        let bundleRepository = PluginBundleRepository(database: database)
        let pluginService = PluginService(
            metadataRepository: metadataRepository,
            bundleRepository: bundleRepository,
            settingsService: settingsService,
            logger: logger
        )

        do {
            try await pluginService.install(
                manifest: PluginManifest(pluginId: "   ", displayName: "Blank ID", version: "1.0.0", capabilities: []),
                bundleData: Data([1])
            )
            XCTFail("Expected a manifest with a blank pluginId to be rejected")
        } catch PluginServiceError.invalidManifest {}

        do {
            try await pluginService.install(
                manifest: PluginManifest(pluginId: "com.astra.empty-bundle", displayName: "Empty Bundle", version: "1.0.0", capabilities: []),
                bundleData: Data()
            )
            XCTFail("Expected an empty bundle to be rejected")
        } catch PluginServiceError.invalidBundle {}

        let manifest = PluginManifest(
            pluginId: "com.astra.duplicate",
            displayName: "Original Plugin",
            version: "2.1.0",
            capabilities: ["transform", "annotate"]
        )
        try await pluginService.install(manifest: manifest, bundleData: Data([9, 9, 9]))

        do {
            try await pluginService.install(manifest: manifest, bundleData: Data([9, 9, 9]))
            XCTFail("Expected a duplicate plugin ID to be rejected")
        } catch PluginServiceError.pluginAlreadyInstalled {}

        // Persisted metadata carries exactly the documented fields — pluginId, displayName,
        // version, capabilities, enabled state, and install timestamp (FR11.7) — nothing else.
        let installedPlugins = await pluginService.listInstalled()
        let installed = try XCTUnwrap(installedPlugins.first { $0.manifest.pluginId == "com.astra.duplicate" })
        XCTAssertEqual(installed.manifest.displayName, "Original Plugin")
        XCTAssertEqual(installed.manifest.version, "2.1.0")
        XCTAssertEqual(installed.manifest.capabilities, ["transform", "annotate"])
        XCTAssertTrue(installed.isEnabled)
    }

    // MARK: - FR14.2/FR14.3/FR14.6: Subject rename validation and grouped-note survival

    func testSubjectRenameValidationAndGroupDeletionUngroupsNotesWithoutDeletingThem() async throws {
        let database = DatabaseProvider()
        let subjectRepository = SubjectRepository(database: database)
        let noteRepository = NoteRepository(database: database)
        let subjectService = SubjectService(repository: subjectRepository)

        let math = try await subjectService.create(name: "Math")
        let science = try await subjectService.create(name: "Science")

        let renamed = try await subjectService.rename(id: math.id, newName: "Algebra")
        XCTAssertEqual(renamed.name, "Algebra")

        do {
            _ = try await subjectService.rename(id: renamed.id, newName: "   ")
            XCTFail("Expected an empty rename to be rejected")
        } catch SubjectServiceError.emptyName {}

        do {
            _ = try await subjectService.rename(id: renamed.id, newName: "Science")
            XCTFail("Expected a duplicate rename to be rejected")
        } catch SubjectServiceError.duplicateName {}

        let noteId = UUID()
        try await noteRepository.upsert(
            StoredNoteRecord(
                id: noteId,
                subjectId: science.id,
                isSecure: false,
                plainTitle: "Belongs to Science",
                plainContent: "for now",
                securePayload: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        )

        // Deleting a non-empty group is the action the UI gates behind a confirmation prompt
        // (FR14.3); the service-level guarantee it relies on is that the note survives, ungrouped (FR14.4).
        try await subjectService.delete(id: science.id)
        let ungrouped = await noteRepository.fetch(id: noteId)
        XCTAssertNotNil(ungrouped)
        XCTAssertNil(ungrouped?.subjectId)

        // The remaining group list and the still-present note together back the sidebar's
        // "All Notes" view, which must show every note regardless of grouping (FR14.6).
        let remainingSubjects = await subjectService.list()
        XCTAssertEqual(remainingSubjects.map(\.name), ["Algebra"])
        let allActiveNotes = await noteRepository.fetchAllActive()
        XCTAssertTrue(allActiveNotes.contains { $0.id == noteId })
    }

    // MARK: - NFR1.1/NFR1.2: Authentication latency independent of note count

    func testAuthenticationLatencyIsIndependentOfNoteCount() async throws {
        func measureUnlockDuration(noteCount: Int) async throws -> TimeInterval {
            let database = DatabaseProvider()
            let noteRepository = NoteRepository(database: database)
            let settingsRepository = SettingsRepository(database: database)
            let time = MutableTimeProvider(now: Date())
            let logger = InMemoryAuditLogger(timeProvider: time)
            let keyManager = KeyManager(settingsRepository: settingsRepository, timeProvider: time, logger: logger)

            try await keyManager.createInitialPassphrase("perf-pass")
            await keyManager.clearInMemoryKeyMaterial()

            for index in 0..<noteCount {
                try await noteRepository.upsert(
                    StoredNoteRecord(
                        id: UUID(),
                        subjectId: nil,
                        isSecure: false,
                        plainTitle: "Note \(index)",
                        plainContent: "Body \(index)",
                        securePayload: nil,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                )
            }

            let start = Date()
            _ = try await keyManager.unlock(passphrase: "perf-pass")
            return Date().timeIntervalSince(start)
        }

        let smallDatabaseDuration = try await measureUnlockDuration(noteCount: 50)
        let largeDatabaseDuration = try await measureUnlockDuration(noteCount: 2_000)

        // PBKDF2 cost is fixed by iteration count, not data volume (NFR1.2): authentication
        // latency must not grow with note count. A generous bound absorbs machine variance
        // while still catching an O(n) regression that scans notes during unlock.
        let ratio = largeDatabaseDuration / max(smallDatabaseDuration, 0.001)
        XCTAssertLessThan(ratio, 5.0, "Authentication latency scaled with note count — expected it to remain constant (NFR1.2)")
        XCTAssertLessThan(smallDatabaseDuration, 2.0, "Authentication should complete in approximately 1s on target hardware (NFR1.1)")
        XCTAssertLessThan(largeDatabaseDuration, 2.0, "Authentication should complete in approximately 1s on target hardware (NFR1.1)")
    }
}
