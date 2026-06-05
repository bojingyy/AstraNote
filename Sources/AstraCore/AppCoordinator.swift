import Foundation
import Combine
import AstraPlatform

public enum AppCoordinatorError: Error, Equatable {
    case biometricUnavailable
    case biometricUnlockDisabled
}

@MainActor
public final class AppCoordinator: ObservableObject {
    public enum SessionState: Equatable {
        case firstLaunchSetup
        case locked
        case unlocked
    }

    @Published public private(set) var sessionState: SessionState = .locked

    private let keyManager: KeyManager
    private let settingsService: SettingsService
    private let noteSearchService: NoteSearchService
    private let localAuthService: LocalAuthServiceProtocol?

    private var lastUserInteractionAt: Date
    private var activeBackgroundOperations: Int = 0
    private var lockPendingAfterBackgroundOperation = false
    private var platformEventsTask: Task<Void, Never>?

    public init(
        keyManager: KeyManager,
        settingsService: SettingsService,
        noteSearchService: NoteSearchService,
        localAuthService: LocalAuthServiceProtocol? = nil,
        now: Date = Date()
    ) {
        self.keyManager = keyManager
        self.settingsService = settingsService
        self.noteSearchService = noteSearchService
        self.localAuthService = localAuthService
        self.lastUserInteractionAt = now
    }

    public func start(now: Date = Date()) async {
        // Keep startup idempotent for the current process.
        guard sessionState != .firstLaunchSetup else {
            return
        }
        lastUserInteractionAt = now
        let hasPassphrase = await keyManager.hasPassphrase()
        if hasPassphrase {
            // Key material is NOT restored from disk on startup; it must be re-derived
            // by the user unlocking. Use .locked so secure operations prompt auth while
            // normal-note work remains available in the workspace.
            sessionState = .locked
        } else {
            sessionState = .firstLaunchSetup
        }
    }

    public func createInitialPassphraseAndUnlock(_ passphrase: String) async throws {
        try await keyManager.createInitialPassphrase(passphrase)
        sessionState = .unlocked
        registerUserInteraction(now: Date())
        await refreshBiometricEnrollmentIfNeeded()
    }

    public func unlock(passphrase: String) async throws {
        _ = try await keyManager.unlock(passphrase: passphrase)
        sessionState = .unlocked
        registerUserInteraction(now: Date())
        await refreshBiometricEnrollmentIfNeeded()
    }

    public func unlockWithBiometrics() async throws {
        guard let localAuthService else {
            throw AppCoordinatorError.biometricUnavailable
        }

        let settings = await settingsService.load()
        guard settings.biometricUnlockEnabled else {
            throw AppCoordinatorError.biometricUnlockDisabled
        }

        let recoveredKey = try await localAuthService.authenticate(reason: "Unlock AstraNotes")
        _ = try await keyManager.unlockWithRecoveredKey(recoveredKey)
        sessionState = .unlocked
        registerUserInteraction(now: Date())
    }

    public func reauthenticateForSecureNote(passphrase: String) async throws {
        _ = try await keyManager.unlock(passphrase: passphrase)
        registerUserInteraction(now: Date())
    }

    public func reauthenticateForSecureNoteWithBiometrics() async throws {
        guard let localAuthService else {
            throw AppCoordinatorError.biometricUnavailable
        }

        let settings = await settingsService.load()
        guard settings.biometricUnlockEnabled else {
            throw AppCoordinatorError.biometricUnlockDisabled
        }

        let recoveredKey = try await localAuthService.authenticate(reason: "Access Secure Note")
        _ = try await keyManager.unlockWithRecoveredKey(recoveredKey)
        registerUserInteraction(now: Date())
    }

    public func changePassphrase(current: String, next: String) async throws {
        try await keyManager.changePassphrase(current: current, next: next)
        await refreshBiometricEnrollmentIfNeeded()
    }

    public func lockNow() async {
        await keyManager.clearInMemoryKeyMaterial()
        await noteSearchService.clearSecureCacheOnLock()
    }

    public func handleImmediateLockEvent() async {
        if activeBackgroundOperations > 0 {
            lockPendingAfterBackgroundOperation = true
            return
        }
        await lockNow()
    }

    public func registerUserInteraction(now: Date = Date()) {
        lastUserInteractionAt = now
    }

    public func beginBackgroundOperation() {
        activeBackgroundOperations += 1
    }

    public func endBackgroundOperation() async {
        activeBackgroundOperations = max(0, activeBackgroundOperations - 1)
        if activeBackgroundOperations == 0 && lockPendingAfterBackgroundOperation {
            lockPendingAfterBackgroundOperation = false
            await lockNow()
        }
    }

    public func bind(platformIntegration: PlatformIntegrationProtocol) {
        platformEventsTask?.cancel()
        platformEventsTask = Task { [weak self] in
            guard let self else {
                return
            }

            for await event in platformIntegration.stream() {
                await self.handlePlatformEvent(event)
            }
        }
    }

    public func updateBiometricUnlock(enabled: Bool) async throws {
        if enabled {
            try await enrollCurrentKeyMaterialForBiometrics()
            try await settingsService.setBiometricUnlockEnabled(true)
        } else {
            await localAuthService?.clearEnrollment()
            try await settingsService.setBiometricUnlockEnabled(false)
        }
    }

    public func evaluateInactivityAutoLock(now: Date = Date()) async {
        guard sessionState != .firstLaunchSetup else {
            return
        }

        let settings = await settingsService.load()
        let effectiveLockTimeoutSeconds = min(max(settings.lockTimeoutSeconds, 30), 3600)
        let idleSeconds = now.timeIntervalSince(lastUserInteractionAt)
        guard idleSeconds > TimeInterval(effectiveLockTimeoutSeconds) else {
            return
        }

        if activeBackgroundOperations > 0 {
            lockPendingAfterBackgroundOperation = true
            return
        }

        await lockNow()
    }

    private func handlePlatformEvent(_ event: PlatformEvent) async {
        switch event {
        case .appDidBackground, .osWillSleep:
            await handleImmediateLockEvent()
        case .userInteraction:
            registerUserInteraction(now: Date())
        case .appDidForeground, .osDidWake:
            registerUserInteraction(now: Date())
        }
    }

    private func refreshBiometricEnrollmentIfNeeded() async {
        guard let localAuthService else {
            return
        }

        let settings = await settingsService.load()
        guard settings.biometricUnlockEnabled else {
            return
        }

        guard let keyMaterial = await keyManager.currentKeyMaterial() else {
            return
        }

        try? await localAuthService.enroll(secret: keyMaterial.encryptionKey)
    }

    private func enrollCurrentKeyMaterialForBiometrics() async throws {
        guard let localAuthService else {
            throw AppCoordinatorError.biometricUnavailable
        }

        guard let keyMaterial = await keyManager.currentKeyMaterial() else {
            throw AppCoordinatorError.biometricUnavailable
        }

        try await localAuthService.enroll(secret: keyMaterial.encryptionKey)
    }
}
