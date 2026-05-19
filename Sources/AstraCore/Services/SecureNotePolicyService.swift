import Foundation
import AstraData
import AstraPlatform

public struct ExpirationSweepResult: Sendable, Equatable {
    public let expiredMovedCount: Int
    public let rollbackGuardActive: Bool
    public let deferredUntilUTC: Date?

    public init(expiredMovedCount: Int, rollbackGuardActive: Bool, deferredUntilUTC: Date?) {
        self.expiredMovedCount = expiredMovedCount
        self.rollbackGuardActive = rollbackGuardActive
        self.deferredUntilUTC = deferredUntilUTC
    }
}

public actor SecureNotePolicyService {
    private let noteRepository: NoteRepositoryProtocol
    private let noteService: NoteService
    private let settingsRepository: SettingsRepositoryProtocol
    private let notificationService: NotificationServiceProtocol
    private let logger: AuditLogging
    private let timeProvider: TimeProvider

    public init(
        noteRepository: NoteRepositoryProtocol,
        noteService: NoteService,
        settingsRepository: SettingsRepositoryProtocol,
        notificationService: NotificationServiceProtocol,
        logger: AuditLogging,
        timeProvider: TimeProvider = SystemTimeProvider()
    ) {
        self.noteRepository = noteRepository
        self.noteService = noteService
        self.settingsRepository = settingsRepository
        self.notificationService = notificationService
        self.logger = logger
        self.timeProvider = timeProvider
    }

    public func validateSecureExpiration(_ expirationUTC: Date) throws {
        let now = timeProvider.now()
        if expirationUTC <= now {
            throw NoteServiceError.secureModeExpirationInPast
        }
    }

    public func handleLaunchTimeCheckpoint() async throws -> ExpirationSweepResult {
        let now = timeProvider.now()
        let lastKnownUTC = await settingsRepository.loadLastKnownUTC()

        if let lastKnownUTC, now < lastKnownUTC {
            try await settingsRepository.saveRollbackGuardUntilUTC(lastKnownUTC)
            await logger.log(
                level: .warning,
                event: "time_rollback_guard_activated",
                metadata: [
                    "lastKnownUTC": ISO8601DateFormatter().string(from: lastKnownUTC),
                    "currentUTC": ISO8601DateFormatter().string(from: now)
                ]
            )
            return ExpirationSweepResult(expiredMovedCount: 0, rollbackGuardActive: true, deferredUntilUTC: lastKnownUTC)
        }

        try await settingsRepository.saveLastKnownUTC(now)
        try await clearRollbackGuardIfElapsed(currentUTC: now)
        return try await sweepExpiredSecureNotes(isForeground: true)
    }

    public func sweepExpiredSecureNotes(isForeground: Bool) async throws -> ExpirationSweepResult {
        let now = timeProvider.now()
        if let guardUntil = await settingsRepository.loadRollbackGuardUntilUTC(), now < guardUntil {
            return ExpirationSweepResult(expiredMovedCount: 0, rollbackGuardActive: true, deferredUntilUTC: guardUntil)
        }

        try await clearRollbackGuardIfElapsed(currentUTC: now)
        let notes = await noteRepository.fetchAllActive()
        let expiredSecureNotes = notes.filter { record in
            guard record.isSecure, let expiration = record.expirationUTC else {
                return false
            }
            return expiration <= now
        }

        var moved = 0
        for note in expiredSecureNotes {
            if try await noteService.delete(noteId: note.id) {
                moved += 1
                await notificationService.notifySecureNoteExpired(noteId: note.id, isForeground: isForeground)
            }
        }

        return ExpirationSweepResult(expiredMovedCount: moved, rollbackGuardActive: false, deferredUntilUTC: nil)
    }

    private func clearRollbackGuardIfElapsed(currentUTC: Date) async throws {
        if let guardUntil = await settingsRepository.loadRollbackGuardUntilUTC(), currentUTC >= guardUntil {
            try await settingsRepository.saveRollbackGuardUntilUTC(nil)
        }
    }
}
