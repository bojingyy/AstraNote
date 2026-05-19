import Foundation
import AstraData

public enum SubjectServiceError: Error, Equatable {
    case emptyName
    case duplicateName
    case notFound
}

public actor SubjectService {
    private let repository: SubjectRepositoryProtocol

    public init(repository: SubjectRepositoryProtocol) {
        self.repository = repository
    }

    public func create(name: String) async throws -> Subject {
        let normalized = normalize(name)
        guard !normalized.isEmpty else {
            throw SubjectServiceError.emptyName
        }
        if await repository.existsName(normalized, excluding: nil) {
            throw SubjectServiceError.duplicateName
        }

        return Subject(stored: try await repository.create(name: normalized))
    }

    public func rename(id: UUID, newName: String) async throws -> Subject {
        let normalized = normalize(newName)
        guard !normalized.isEmpty else {
            throw SubjectServiceError.emptyName
        }
        if await repository.existsName(normalized, excluding: id) {
            throw SubjectServiceError.duplicateName
        }
        guard let renamed = try await repository.rename(id: id, newName: normalized) else {
            throw SubjectServiceError.notFound
        }
        return Subject(stored: renamed)
    }

    @discardableResult
    public func delete(id: UUID) async throws -> Bool {
        let deleted = try await repository.deleteAndUngroupNotes(id: id)
        if !deleted {
            throw SubjectServiceError.notFound
        }
        return true
    }

    public func list() async -> [Subject] {
        await repository.listAll().map { Subject(stored: $0) }
    }

    private func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
