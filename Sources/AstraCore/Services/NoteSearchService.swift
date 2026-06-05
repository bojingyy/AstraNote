import Foundation
import AstraData

public struct NoteSearchResult: Sendable, Equatable {
    public let noteId: UUID
    public let matchedTitle: String
    public let isSecure: Bool
}

public actor NoteSearchService {
    private let noteRepository: NoteRepositoryProtocol

    public init(noteRepository: NoteRepositoryProtocol, noteService _: NoteService) {
        self.noteRepository = noteRepository
    }

    public func searchTitle(query: String, isUnlocked: Bool) async -> [NoteSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedQuery.isEmpty {
            return []
        }

        let all = await noteRepository.fetchAllActive()
        var results: [NoteSearchResult] = []

        for note in all where !note.isSecure {
            guard let title = note.plainTitle else {
                continue
            }
            if title.lowercased().contains(normalizedQuery) {
                results.append(NoteSearchResult(noteId: note.id, matchedTitle: title, isSecure: false))
            }
        }

        for note in all where note.isSecure {
            guard let alias = note.secureTitleAlias else {
                continue
            }
            if alias.lowercased().contains(normalizedQuery) {
                results.append(NoteSearchResult(noteId: note.id, matchedTitle: alias, isSecure: true))
            }
        }

        return results
    }

    public func clearSecureCacheOnLock() {
        // Secure aliases are non-sensitive metadata persisted in storage.
    }

    public func secureCacheCount() -> Int {
        0
    }
}
