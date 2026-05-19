import Foundation

public protocol SubjectRepositoryProtocol: Sendable {
    func create(name: String) async throws -> StoredSubjectRecord
    func rename(id: UUID, newName: String) async throws -> StoredSubjectRecord?
    func deleteAndUngroupNotes(id: UUID) async throws -> Bool
    func listAll() async -> [StoredSubjectRecord]
    func existsName(_ name: String, excluding: UUID?) async -> Bool
    func fetch(id: UUID) async -> StoredSubjectRecord?
}

public actor SubjectRepository: SubjectRepositoryProtocol {
    private let database: DatabaseProvider

    public init(database: DatabaseProvider) {
        self.database = database
    }

    public func create(name: String) async throws -> StoredSubjectRecord {
        try await database.transaction { state in
            let record = StoredSubjectRecord(
                id: UUID(),
                name: name,
                displayOrder: state.subjects.count,
                createdAt: Date()
            )
            state.subjects[record.id] = record
            return record
        }
    }

    public func rename(id: UUID, newName: String) async throws -> StoredSubjectRecord? {
        try await database.transaction { state in
            guard var existing = state.subjects[id] else {
                return nil
            }
            existing.name = newName
            state.subjects[id] = existing
            return existing
        }
    }

    public func deleteAndUngroupNotes(id: UUID) async throws -> Bool {
        try await database.transaction { state in
            guard state.subjects.removeValue(forKey: id) != nil else {
                return false
            }
            for (noteId, var note) in state.notes where note.subjectId == id {
                note.subjectId = nil
                note.updatedAt = Date()
                state.notes[noteId] = note
            }
            return true
        }
    }

    public func listAll() async -> [StoredSubjectRecord] {
        await database.read { state in
            state.subjects.values.sorted { lhs, rhs in
                if lhs.displayOrder == rhs.displayOrder {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.displayOrder < rhs.displayOrder
            }
        }
    }

    public func existsName(_ name: String, excluding: UUID? = nil) async -> Bool {
        await database.read { state in
            let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return state.subjects.values.contains { subject in
                if let excluding, subject.id == excluding {
                    return false
                }
                return subject.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
            }
        }
    }

    public func fetch(id: UUID) async -> StoredSubjectRecord? {
        await database.read { $0.subjects[id] }
    }
}
