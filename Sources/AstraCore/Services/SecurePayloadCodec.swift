import Foundation

struct SecurePayloadCodec {
    private struct DTO: Codable {
        let title: String
        let content: String
    }

    static func encode(title: String, content: String) throws -> Data {
        try JSONEncoder().encode(DTO(title: title, content: content))
    }

    static func decode(_ data: Data) throws -> (title: String, content: String) {
        let decoded = try JSONDecoder().decode(DTO.self, from: data)
        return (decoded.title, decoded.content)
    }
}
