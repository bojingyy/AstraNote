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

    func testPhase3And4SecureTrashAndSearchFlow() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let trashRepository = ProtectedTrashRepository(database: database)
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
        let policyService = SecureNotePolicyService(
            noteService: noteService,
            logger: logger,
            timeProvider: clock
        )
        let searchService = NoteSearchService(noteRepository: noteRepository, noteService: noteService)
        let trashService = ProtectedTrashService(trashRepository: trashRepository, keyManager: keyManager)

        try await keyManager.createInitialPassphrase("phase34")
        _ = try await keyManager.unlock(passphrase: "phase34")

        let secureId = try await noteService.save(
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

        let launchResult = try await policyService.handleLaunchTimeCheckpoint()
        XCTAssertEqual(launchResult.expiredMovedCount, 0)

        clock.advance(seconds: 30)
        let sweep = try await policyService.sweepExpiredSecureNotes(isForeground: true)
        XCTAssertEqual(sweep.expiredMovedCount, 0)

        let activeSecureNote = await noteRepository.fetch(id: secureId)
        XCTAssertNotNil(activeSecureNote)

        let trashItems = await trashService.listTrashItems()
        XCTAssertTrue(trashItems.isEmpty)

        let lockedSearch = await searchService.searchTitle(query: "secure", isUnlocked: false)
        XCTAssertTrue(lockedSearch.isEmpty)
    }

    @MainActor
    func testPhase5RotationExportPluginAndBiometricFlow() async throws {
        let database = DatabaseProvider()
        let noteRepository = NoteRepository(database: database)
        let attachmentRepository = AttachmentRepository(database: database)
        let subjectRepository = SubjectRepository(database: database)
        let settingsRepository = SettingsRepository(database: database)
        let pluginMetadataRepository = PluginMetadataRepository(database: database)
        let pluginBundleRepository = PluginBundleRepository(database: database)
        let clock = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: clock)
        let localAuth = InMemoryLocalAuthService()

        let keyManager = KeyManager(
            settingsRepository: settingsRepository,
            databaseProvider: database,
            timeProvider: clock,
            logger: logger
        )
        let noteService = NoteService(
            notes: noteRepository,
            attachments: attachmentRepository,
            subjects: subjectRepository,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            timeProvider: clock,
            storageProtection: InMemoryStorageProtection()
        )
        let searchService = NoteSearchService(noteRepository: noteRepository, noteService: noteService)
        let settingsService = SettingsService(repository: settingsRepository)
        let coordinator = AppCoordinator(
            keyManager: keyManager,
            settingsService: settingsService,
            noteSearchService: searchService,
            localAuthService: localAuth,
            now: clock.now()
        )
        let exportImportService = ExportImportService(
            database: database,
            keyManager: keyManager,
            encryptionService: EncryptionService(),
            logger: logger
        )
        let pluginService = PluginService(
            metadataRepository: pluginMetadataRepository,
            bundleRepository: pluginBundleRepository,
            settingsService: settingsService,
            logger: logger
        )

        await coordinator.start(now: clock.now())
        try await coordinator.createInitialPassphraseAndUnlock("phase5-old")
        try await coordinator.updateBiometricUnlock(enabled: true)

        let secureId = try await noteService.save(
            draft: NoteDraft(
                title: "Phase 5 Secure",
                content: "integrated payload",
                subjectId: nil,
                secureModeEnabled: true,
                expirationUTC: clock.now().addingTimeInterval(600)
            )
        )

        try await pluginService.install(
            manifest: PluginManifest(
                pluginId: "com.astra.integration",
                displayName: "Integration Plugin",
                version: "1.0.0",
                capabilities: ["annotate"]
            ),
            bundleData: Data("bundle".utf8)
        )
        await pluginService.registerHandler(pluginId: "com.astra.integration") { request in
            PluginActionResult(output: "annotated: \(request.input)")
        }

        try await coordinator.changePassphrase(current: "phase5-old", next: "phase5-new")
        let archive = try await exportImportService.exportArchive()
        let importResult = try await exportImportService.importArchive(archive)
        XCTAssertGreaterThanOrEqual(importResult.importedNotes, 1)

        let pluginResult = try await pluginService.execute(
            pluginId: "com.astra.integration",
            request: PluginActionRequest(action: "annotate", input: "astra")
        )
        XCTAssertEqual(pluginResult.output, "annotated: astra")

        await coordinator.lockNow()
        try await coordinator.unlockWithBiometrics()
        let loaded = try await noteService.load(id: secureId)
        XCTAssertEqual(loaded.content, "integrated payload")
    }
}
