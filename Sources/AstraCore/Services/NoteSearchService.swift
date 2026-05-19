import Foundation
import AstraData

public struct NoteSearchResult: Sendable, Equatable {
    public let noteId: UUID
    public let matchedTitle: String
    public let isSecure: Bool
}

public actor NoteSearchService {
    private let noteRepository: NoteRepositoryProtocol
    private let noteService: NoteService

    private var secureTitleCache: [UUID: String] = [:]

    public init(noteRepository: NoteRepositoryProtocol, noteService: NoteService) {
        self.noteRepository = noteRepository
        self.noteService = noteService
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

        guard isUnlocked else {
            return results
        }

        await ensureSecureCacheLoaded(notes: all)
        for (noteId, title) in secureTitleCache where title.lowercased().contains(normalizedQuery) {
            results.append(NoteSearchResult(noteId: noteId, matchedTitle: title, isSecure: true))
        }

        return results
    }

    public func clearSecureCacheOnLock() {
        secureTitleCache.removeAll(keepingCapacity: false)
    }

    public func secureCacheCount() -> Int {
        secureTitleCache.count
    }

    private func ensureSecureCacheLoaded(notes: [StoredNoteRecord]) async {
        let secureIds = notes.filter(\.isSecure).map(\.id)
        if secureTitleCache.keys.count == secureIds.count && secureIds.allSatisfy({ secureTitleCache[$0] != nil }) {
            return
        }

        secureTitleCache.removeAll(keepingCapacity: true)
        for noteId in secureIds {
            if let loaded = try? await noteService.load(id: noteId) {
                secureTitleCache[noteId] = loaded.title
            }
        }
    }
}
