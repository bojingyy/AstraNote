import Foundation
import LocalAuthentication
import Security

public enum LocalAuthError: Error, Equatable {
    case biometricUnavailable
    case notEnrolled
    case userFallback
    case cancelled
    case authenticationFailed
    case enrollmentFailed
    case secureStorageFailed
}

public protocol LocalAuthServiceProtocol: Sendable {
    func enroll(secret: Data) async throws
    func authenticate(reason: String) async throws -> Data
    func clearEnrollment() async
}

public actor SystemLocalAuthService: LocalAuthServiceProtocol {
    private let service: String
    private let account: String

    public init(
        service: String = "com.astranotes.local-auth",
        account: String = "biometric-unlock-secret"
    ) {
        self.service = service
        self.account = account
    }

    public func enroll(secret: Data) async throws {
        try ensureBiometricsAvailable()

        _ = SecItemDelete(baseQuery as CFDictionary)

        let attributes: [String: Any] = baseQuery.merging([
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: secret
        ]) { _, newValue in
            newValue
        }

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw LocalAuthError.enrollmentFailed
        }
    }

    public func authenticate(reason: String) async throws -> Data {
        try ensureLocalAuthenticationAvailable()
        try await evaluateBiometrics(reason: reason)

        var query = baseQuery
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let secret = item as? Data else {
                throw LocalAuthError.secureStorageFailed
            }
            return secret
        case errSecItemNotFound:
            throw LocalAuthError.notEnrolled
        case errSecAuthFailed, errSecUserCanceled, errSecInteractionNotAllowed:
            throw LocalAuthError.authenticationFailed
        default:
            throw LocalAuthError.secureStorageFailed
        }
    }

    public func clearEnrollment() async {
        _ = SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func ensureBiometricsAvailable() throws {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error, error.domain == LAError.errorDomain {
                switch LAError.Code(rawValue: error.code) {
                case .biometryNotEnrolled:
                    throw LocalAuthError.notEnrolled
                case .biometryNotAvailable, .passcodeNotSet:
                    throw LocalAuthError.biometricUnavailable
                default:
                    throw LocalAuthError.authenticationFailed
                }
            }

            throw LocalAuthError.biometricUnavailable
        }
    }

    private func ensureLocalAuthenticationAvailable() throws {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error, error.domain == LAError.errorDomain {
                switch LAError.Code(rawValue: error.code) {
                case .biometryNotEnrolled:
                    throw LocalAuthError.notEnrolled
                case .biometryNotAvailable, .passcodeNotSet:
                    throw LocalAuthError.biometricUnavailable
                default:
                    throw LocalAuthError.authenticationFailed
                }
            }

            throw LocalAuthError.biometricUnavailable
        }
    }

    private func evaluateBiometrics(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Use Passphrase"

        do {
            let success = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: success)
                    }
                }
            }

            guard success else {
                throw LocalAuthError.authenticationFailed
            }
        } catch let error as LAError {
            switch error.code {
            case .biometryNotAvailable, .passcodeNotSet:
                throw LocalAuthError.biometricUnavailable
            case .biometryNotEnrolled:
                throw LocalAuthError.notEnrolled
            case .userFallback:
                throw LocalAuthError.userFallback
            case .userCancel, .systemCancel, .appCancel:
                throw LocalAuthError.cancelled
            default:
                throw LocalAuthError.authenticationFailed
            }
        } catch {
            throw LocalAuthError.authenticationFailed
        }
    }
}

public actor InMemoryLocalAuthService: LocalAuthServiceProtocol {
    private var enrolledSecret: Data?
    private var shouldAuthenticate = true

    public init() {}

    public func enroll(secret: Data) async throws {
        enrolledSecret = secret
    }

    public func authenticate(reason: String) async throws -> Data {
        guard let enrolledSecret else {
            throw LocalAuthError.notEnrolled
        }
        guard shouldAuthenticate else {
            throw LocalAuthError.authenticationFailed
        }
        return enrolledSecret
    }

    public func clearEnrollment() async {
        enrolledSecret = nil
    }

    public func setAuthenticationResult(_ shouldAuthenticate: Bool) async {
        self.shouldAuthenticate = shouldAuthenticate
    }
}
