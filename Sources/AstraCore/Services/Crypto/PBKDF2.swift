import CryptoKit
import Foundation

enum PBKDF2 {
    static func deriveSHA256(password: Data, salt: Data, iterations: Int, keyLength: Int) -> Data {
        precondition(iterations > 0, "iterations must be > 0")
        precondition(keyLength > 0, "keyLength must be > 0")

        let hashLength = 32
        let blockCount = Int(ceil(Double(keyLength) / Double(hashLength)))

        var derived = Data(capacity: blockCount * hashLength)
        for blockIndex in 1...blockCount {
            var block = f(password: password, salt: salt, iterations: iterations, blockIndex: UInt32(blockIndex))
            derived.append(block)
            block.removeAll(keepingCapacity: false)
        }

        return derived.prefix(keyLength)
    }

    private static func f(password: Data, salt: Data, iterations: Int, blockIndex: UInt32) -> Data {
        var index = blockIndex.bigEndian
        let indexData = withUnsafeBytes(of: &index) { Data($0) }

        var u = hmacSHA256(key: password, data: salt + indexData)
        var output = u

        guard iterations > 1 else {
            return output
        }

        for _ in 2...iterations {
            u = hmacSHA256(key: password, data: u)
            xorInPlace(lhs: &output, rhs: u)
        }

        return output
    }

    private static func hmacSHA256(key: Data, data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let digest = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(digest)
    }

    private static func xorInPlace(lhs: inout Data, rhs: Data) {
        for index in lhs.indices {
            lhs[index] ^= rhs[index]
        }
    }
}
