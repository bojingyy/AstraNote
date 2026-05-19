import Foundation
import Combine

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

    private var lastUserInteractionAt: Date
    private var activeBackgroundOperations: Int = 0
    private var lockPendingAfterBackgroundOperation = false

    public init(
        keyManager: KeyManager,
        settingsService: SettingsService,
        noteSearchService: NoteSearchService,
        now: Date = Date()
    ) {
        self.keyManager = keyManager
        self.settingsService = settingsService
        self.noteSearchService = noteSearchService
        self.lastUserInteractionAt = now
    }

    public func start(now: Date = Date()) async {
        lastUserInteractionAt = now
        let hasPassphrase = await keyManager.hasPassphrase()
        sessionState = hasPassphrase ? .locked : .firstLaunchSetup
    }

    public func createInitialPassphraseAndUnlock(_ passphrase: String) async throws {
        try await keyManager.createInitialPassphrase(passphrase)
        sessionState = .unlocked
        registerUserInteraction(now: Date())
    }

    public func unlock(passphrase: String) async throws {
        _ = try await keyManager.unlock(passphrase: passphrase)
        sessionState = .unlocked
        registerUserInteraction(now: Date())
    }

    public func lockNow() async {
        await keyManager.clearInMemoryKeyMaterial()
        await noteSearchService.clearSecureCacheOnLock()
        sessionState = .locked
    }

    public func handleImmediateLockEvent() async {
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

    public func evaluateInactivityAutoLock(now: Date = Date()) async {
        guard sessionState == .unlocked else {
            return
        }

        let settings = await settingsService.load()
        let idleSeconds = now.timeIntervalSince(lastUserInteractionAt)
        guard idleSeconds > TimeInterval(settings.lockTimeoutSeconds) else {
            return
        }

        if activeBackgroundOperations > 0 {
            lockPendingAfterBackgroundOperation = true
            return
        }

        await lockNow()
    }
}
