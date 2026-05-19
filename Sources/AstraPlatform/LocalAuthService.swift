import Foundation

public enum LocalAuthError: Error, Equatable {
    case notEnrolled
    case authenticationFailed
}

public protocol LocalAuthServiceProtocol: Sendable {
    func enroll(secret: Data) async
    func authenticate(reason: String) async throws -> Data
    func clearEnrollment() async
}

public actor InMemoryLocalAuthService: LocalAuthServiceProtocol {
    private var enrolledSecret: Data?
    private var shouldAuthenticate = true

    public init() {}

    public func enroll(secret: Data) async {
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
