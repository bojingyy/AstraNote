import XCTest
@testable import AstraPlatform

final class AstraPlatformTests: XCTestCase {
    func testAuditLoggingRedactsSensitiveFields() async {
        let time = MutableTimeProvider(now: Date())
        let logger = InMemoryAuditLogger(timeProvider: time)

        await logger.log(
            level: .warning,
            event: "unlock_failed",
            metadata: ["title": "secret", "reason": "bad passphrase"]
        )

        let entry = await logger.entries().last
        XCTAssertEqual(entry?.metadata["title"], "<redacted>")
        XCTAssertEqual(entry?.metadata["reason"], "bad passphrase")
    }

    func testMutableTimeProviderAdvance() {
        let start = Date()
        let time = MutableTimeProvider(now: start)
        time.advance(seconds: 15)
        XCTAssertEqual(Int(time.now().timeIntervalSince(start)), 15)
    }

    func testLocalAuthEnrollmentAndStorageProtection() async throws {
        let localAuth = InMemoryLocalAuthService()
        let storageProtection = InMemoryStorageProtection()
        let secret = Data("secret".utf8)

        await localAuth.enroll(secret: secret)
        let recovered = try await localAuth.authenticate(reason: "test")
        XCTAssertEqual(recovered, secret)

        try await storageProtection.protect(path: "/tmp/file", classification: .complete)
        let protection = await storageProtection.protectionClass(for: "/tmp/file")
        XCTAssertEqual(protection, .complete)
    }
}
