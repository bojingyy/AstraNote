import Foundation
import Security
import AstraData
import AstraPlatform

public enum KeyManagerError: Error, Equatable {
    case passphraseNotInitialized
    case passphraseAlreadyInitialized
    case lockoutActive(remainingSeconds: Int)
    case invalidPassphrase
    case identicalPassphrase
}

public actor KeyManager {
    private struct Constants {
        static let iterations = 100_000
        static let keyLength = 32
        static let lockoutWindowSeconds: TimeInterval = 30
        static let baseLockoutSeconds: TimeInterval = 30
        static let maxLockoutSeconds: TimeInterval = 60 * 60
    }

    private let settingsRepository: SettingsRepositoryProtocol
    private let timeProvider: TimeProvider
    private let logger: AuditLogging

    private var inMemoryKeyMaterial: KeyMaterial?
    private var failedAttempts: [Date] = []
    private var lockoutUntil: Date?
    private var currentLockoutDuration: TimeInterval = 0

    public init(
        settingsRepository: SettingsRepositoryProtocol,
        timeProvider: TimeProvider = SystemTimeProvider(),
        logger: AuditLogging
    ) {
        self.settingsRepository = settingsRepository
        self.timeProvider = timeProvider
        self.logger = logger
    }

    public func hasPassphrase() async -> Bool {
        await settingsRepository.loadCredentials() != nil
    }

    public func createInitialPassphrase(_ passphrase: String) async throws {
        if await hasPassphrase() {
            throw KeyManagerError.passphraseAlreadyInitialized
        }

        let salt = randomData(length: 16)
        let hash = deriveKey(passphrase: passphrase, salt: salt, iterations: Constants.iterations)
        let credentials = StoredCredentialState(salt: salt, hash: hash, iterations: Constants.iterations)
        try await settingsRepository.saveCredentials(credentials)
        inMemoryKeyMaterial = KeyMaterial(encryptionKey: hash)
    }

    public func unlock(passphrase: String) async throws -> KeyMaterial {
        if let lockoutUntil {
            let remaining = lockoutUntil.timeIntervalSince(timeProvider.now())
            if remaining > 0 {
                throw KeyManagerError.lockoutActive(remainingSeconds: Int(ceil(remaining)))
            }
            self.lockoutUntil = nil
        }

        guard let credentials = await settingsRepository.loadCredentials() else {
            throw KeyManagerError.passphraseNotInitialized
        }

        let derived = deriveKey(passphrase: passphrase, salt: credentials.salt, iterations: credentials.iterations)
        guard derived == credentials.hash else {
            try await registerFailedAttempt()
            throw KeyManagerError.invalidPassphrase
        }

        resetRateLimitingState()
        let keyMaterial = KeyMaterial(encryptionKey: derived)
        inMemoryKeyMaterial = keyMaterial
        return keyMaterial
    }

    public func currentKeyMaterial() -> KeyMaterial? {
        inMemoryKeyMaterial
    }

    public func clearInMemoryKeyMaterial() {
        inMemoryKeyMaterial = nil
    }

    public func changePassphrase(current: String, next: String) async throws {
        guard !next.isEmpty else {
            throw KeyManagerError.invalidPassphrase
        }

        guard let credentials = await settingsRepository.loadCredentials() else {
            throw KeyManagerError.passphraseNotInitialized
        }

        let oldDerived = deriveKey(passphrase: current, salt: credentials.salt, iterations: credentials.iterations)
        guard oldDerived == credentials.hash else {
            throw KeyManagerError.invalidPassphrase
        }

        let newDerived = deriveKey(passphrase: next, salt: credentials.salt, iterations: credentials.iterations)
        guard newDerived != oldDerived else {
            throw KeyManagerError.identicalPassphrase
        }

        try await settingsRepository.saveCredentials(
            StoredCredentialState(salt: credentials.salt, hash: newDerived, iterations: credentials.iterations)
        )
        inMemoryKeyMaterial = KeyMaterial(encryptionKey: newDerived)
    }

    private func registerFailedAttempt() async throws {
        let now = timeProvider.now()
        failedAttempts = failedAttempts.filter { now.timeIntervalSince($0) <= Constants.lockoutWindowSeconds }
        failedAttempts.append(now)

        if failedAttempts.count >= 5 {
            currentLockoutDuration = currentLockoutDuration == 0
                ? Constants.baseLockoutSeconds
                : min(currentLockoutDuration * 2, Constants.maxLockoutSeconds)
            lockoutUntil = now.addingTimeInterval(currentLockoutDuration)
            failedAttempts.removeAll(keepingCapacity: false)

            await logger.log(
                level: .warning,
                event: "unlock_lockout",
                metadata: [
                    "durationSeconds": String(Int(currentLockoutDuration))
                ]
            )
        } else {
            await logger.log(level: .warning, event: "unlock_failed", metadata: [:])
        }
    }

    private func resetRateLimitingState() {
        failedAttempts.removeAll(keepingCapacity: false)
        lockoutUntil = nil
        currentLockoutDuration = 0
    }

    private func deriveKey(passphrase: String, salt: Data, iterations: Int) -> Data {
        PBKDF2.deriveSHA256(
            password: Data(passphrase.utf8),
            salt: salt,
            iterations: iterations,
            keyLength: Constants.keyLength
        )
    }

    private func randomData(length: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Failed to generate secure random data")
        return Data(bytes)
    }
}
