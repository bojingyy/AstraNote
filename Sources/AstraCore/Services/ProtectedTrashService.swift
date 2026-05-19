import Foundation
import AstraData

public struct TrashItemView: Sendable, Equatable {
    public let trashId: UUID
    public let sourceNoteId: UUID
    public let isSecure: Bool
    public let displayTitle: String?
    public let deletionTime: Date
    public let lockBadgeVisible: Bool
}

public enum ProtectedTrashServiceError: Error, Equatable {
    case restoreRequiresUnlockedSession
    case trashItemNotFound
}

public actor ProtectedTrashService {
    private let trashRepository: ProtectedTrashRepositoryProtocol
    private let keyManager: KeyManager

    public init(trashRepository: ProtectedTrashRepositoryProtocol, keyManager: KeyManager) {
        self.trashRepository = trashRepository
        self.keyManager = keyManager
    }

    public func listTrashItems() async -> [TrashItemView] {
        let records = await trashRepository.listAll()
        return records.map { record in
            TrashItemView(
                trashId: record.id,
                sourceNoteId: record.sourceNote.id,
                isSecure: record.sourceNote.isSecure,
                displayTitle: record.sourceNote.isSecure ? nil : record.sourceNote.plainTitle,
                deletionTime: record.deletedAt,
                lockBadgeVisible: record.sourceNote.isSecure
            )
        }
    }

    public func secureTitlePreviewMessage(trashId: UUID) async throws -> String? {
        guard let record = await trashRepository.listAll().first(where: { $0.id == trashId }) else {
            throw ProtectedTrashServiceError.trashItemNotFound
        }
        if record.sourceNote.isSecure {
            return "This secure note is locked and cannot be previewed until restored and unlocked."
        }
        return record.sourceNote.plainTitle
    }

    @discardableResult
    public func restore(trashId: UUID) async throws -> Bool {
        let records = await trashRepository.listAll()
        guard let record = records.first(where: { $0.id == trashId }) else {
            throw ProtectedTrashServiceError.trashItemNotFound
        }

        if record.sourceNote.isSecure, await keyManager.currentKeyMaterial() == nil {
            throw ProtectedTrashServiceError.restoreRequiresUnlockedSession
        }

        let restored = try await trashRepository.restore(trashId: trashId)
        if !restored {
            throw ProtectedTrashServiceError.trashItemNotFound
        }
        return true
    }

    @discardableResult
    public func permanentlyDelete(trashId: UUID) async throws -> Bool {
        let deleted = try await trashRepository.permanentlyDelete(trashId: trashId)
        if !deleted {
            throw ProtectedTrashServiceError.trashItemNotFound
        }
        return true
    }
}
