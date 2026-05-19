import CryptoKit
import Foundation
import Security

public enum EncryptionError: Error, Equatable {
    case invalidKeyLength
    case invalidPayload
    case authenticationFailed
}

public struct EncryptionService {
    public init() {}

    public func encrypt(plaintext: Data, keyMaterial: KeyMaterial) throws -> EncryptedPayload {
        guard keyMaterial.encryptionKey.count == 32 else {
            throw EncryptionError.invalidKeyLength
        }

        let salt = randomData(length: 16)
        let perNoteKeyData = derivePerNoteKey(baseKey: keyMaterial.encryptionKey, salt: salt)
        let symmetricKey = SymmetricKey(data: perNoteKeyData)
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plaintext, using: symmetricKey, nonce: nonce)

        return EncryptedPayload(
            ciphertext: sealed.ciphertext,
            nonce: Data(nonce),
            tag: sealed.tag,
            salt: salt
        )
    }

    public func decrypt(payload: EncryptedPayload, keyMaterial: KeyMaterial) throws -> Data {
        guard keyMaterial.encryptionKey.count == 32 else {
            throw EncryptionError.invalidKeyLength
        }
        guard payload.nonce.count == 12 else {
            throw EncryptionError.invalidPayload
        }

        do {
            let nonce = try AES.GCM.Nonce(data: payload.nonce)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: payload.ciphertext, tag: payload.tag)
            let perNoteKeyData = derivePerNoteKey(baseKey: keyMaterial.encryptionKey, salt: payload.salt)
            let symmetricKey = SymmetricKey(data: perNoteKeyData)
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw EncryptionError.authenticationFailed
        }
    }

    private func derivePerNoteKey(baseKey: Data, salt: Data) -> Data {
        let input = SymmetricKey(data: baseKey)
        let output = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: input,
            salt: salt,
            info: Data("AstraNotes-PerNoteKey".utf8),
            outputByteCount: 32
        )
        return output.withUnsafeBytes { Data($0) }
    }

    private func randomData(length: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Failed to generate secure random data")
        return Data(bytes)
    }
}
