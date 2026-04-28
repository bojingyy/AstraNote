# AstraNotes Architecture

## 1. Goal and Principles
- Build the easiest workable macOS notes app where notes are unencrypted by default and users can opt into secure mode per note.
- Keep UI simple: one Notability-style workspace screen for daily note work.
- Keep logic simple: thin UI, service-based core, repository persistence.
- Keep scope strict: local only, no cloud sync, no advanced plugin runtime in MVP.

## 2. MVP Scope (What We Build First)
- Unlock with passphrase; optional biometric unlock after first passphrase success.
- Tri-pane notes workspace:
	- Left: foldable subject sidebar.
	- Middle: note list/cards.
	- Right: note editor.
- Create, edit, delete, and restore notes.
- Normal notes are stored unencrypted; attachments are optional.
- Secure note mode is opt-in per note: encrypts the note, requires an expiration date, and routes deletion through protected trash.
- Voice capture trigger in the editor top bar (record and attach flow can start simple).
- Encrypted export/import for local backup and restore with atomic import behavior.
- Settings for lock timeout, telemetry opt-in, plugin preference flags.

Out of MVP:
- Cloud sync.
- Complex plugin execution host.
- Advanced rich-text tooling beyond a basic editor.

## 3. Module Map (Single Responsibility)

### AstraUI
- `AppState.swift`: session/view state, selected subject, selected note, pane collapse state.
- `NotesWorkspaceView.swift`: single composition root for note UI.
	- `WorkspaceTopBar`: new note, search, voice capture button, secure status.
	- `SubjectSidebarPane`: hierarchy and filters.
	- `NoteCollectionPane`: note cards and selection.
	- `NoteEditorPane`: main note editor pane (right side) with secure toggle, expiration controls, and secure option button placed at the top-right of the editor toolbar.
- `TrashView.swift`: lists all trashed notes (both normal and secure); shows note title, deletion time, and lock badge for secure notes; provides Restore and Permanently Delete actions per item.
- `SettingsView.swift`: settings forms only.
- `PluginStoreView.swift`: metadata-level plugin management UI (no heavy runtime logic in MVP).

### AstraCore
- `AppCoordinator.swift`: app lifecycle, lock/unlock routing, navigation state handoff.
- `KeyManager.swift`: passphrase handling, derived key lifecycle, key clearing on lock.
- `EncryptionService.swift`: encrypt/decrypt payload boundary.
- `NoteService.swift`: note CRUD orchestration; routes to encrypted or standard storage path based on note's secure flag.
- `SecureNotePolicyService.swift`: secure-note rules (expiry checks, encryption enforcement, protected-delete decisions).
- `ProtectedTrashService.swift`: move/restore/permanent-delete logic.
- `SettingsService.swift`: validation + updates for settings.
- `ExportImportService.swift`: encrypted archive export/import orchestration included in MVP.
- `PluginService.swift`: trust metadata checks and enable/disable state (minimal in MVP).

### AstraData
- `DatabaseProvider.swift`: connection, migration, transaction wrapper.
- `NoteRepository.swift`: note persistence for both standard and secure notes.
- `AttachmentRepository.swift`: attachment persistence matching the note's security mode.
- `ProtectedTrashRepository.swift`: protected trash records.
- `SettingsRepository.swift`: settings persistence.
- `PluginMetadataRepository.swift`: plugin metadata persistence.

### AstraPlatform
- `LocalAuthService.swift`: biometric API integration.
- `StorageProtection.swift`: protected directories and file-protection checks.
- `NotificationService.swift`: local expiry notifications.
- `TimeProvider.swift`: UTC source + last-known-time protection.
- `Logging.swift`: non-sensitive audit/diagnostic logging.
- `PlatformIntegration.swift`: app sleep/background/foreground events.

### AstraCore/Models
- `Note.swift`, `EncryptedPayload.swift`, `Attachment.swift`, `KeyMaterial.swift`, `PluginManifest.swift`.

## 4. Runtime Boundaries (Clear and Enforceable)
- UI never performs encryption or direct database writes.
- Core services never depend on SwiftUI views.
- Repositories store standard notes as-is and secure notes as ciphertext only; the storage path is determined by the note's secure flag.
- Platform wrappers isolate OS APIs from UI and repository layers.
- Secure-note decisions happen in `SecureNotePolicyService.swift`, not in view logic.

## 5. Primary User Flows

### 5.1 Unlock
1. `AppCoordinator` checks lock state.
2. `KeyManager` validates passphrase or biometric path.
3. On success, in-memory keys are available to core services.
4. On lock, keys are cleared and editor content is masked.

### 5.2 Create/Edit Note
1. UI sends draft to `NoteService`.
2. `NoteService` checks the note's secure flag.
3. If secure is off: standard payload is persisted via `NoteRepository` transaction.
4. If secure is on: `EncryptionService` encrypts the payload; ciphertext is persisted via `NoteRepository` transaction.
5. UI refreshes list and editor state from service result.

### 5.3 Secure Note Expiration
1. When user enables secure mode, an expiration date is required.
2. `SecureNotePolicyService` validates and stores policy data alongside the encrypted note.
3. On checks (active use + app launch), expired notes move via `ProtectedTrashService`.
4. `NotificationService` informs user; the note is no longer accessible after expiration.

### 5.4 Trash Flow (Normal Note)
1. User deletes a normal note.
2. `ProtectedTrashService` moves the note to protected trash via `ProtectedTrashRepository`.
3. `TrashView` shows the item with title, deletion time, and Restore / Permanently Delete actions.
4. Restore moves the note back to the active note list.
5. Permanently Delete removes the record entirely.

### 5.5 Trash Flow (Secure Note)
1. Secure note reaches its expiration or the user triggers deletion.
2. `SecureNotePolicyService` confirms eligibility and `ProtectedTrashService` moves the encrypted record to protected trash.
3. `TrashView` shows the item with a lock badge instead of readable title (title remains encrypted).
4. Restore requires app unlock; `KeyManager` must have active keys to decrypt the note back into the active list.
5. Permanently Delete wipes the ciphertext and all associated attachments; the note becomes unrecoverable.

## 6. Minimal Data Contracts
- Normal note record: `id`, `isSecure: false`, title/content as plain text, timestamps.
- Secure note record: `id`, `isSecure: true`, encrypted title/content payload, nonce, salt, timestamps, expiration date (required).
- Attachment record: `id`, `noteId`, payload stored according to the note's security mode.
- Trash record: source note id, `isSecure`, deletion time, retention metadata; encrypted payload retained for secure notes until permanent delete.
- Settings: lock timeout, telemetry opt-in, plugin prefs.

## 7. Implementation Plan (Lowest-Risk Order)

Phase 1: Foundation
- Implement `DatabaseProvider`, repositories, and migrations.
- Implement `KeyManager` + `EncryptionService` with test vectors.

Phase 2: Core Note Lifecycle
- Implement `NoteService` CRUD with encrypted persistence.
- Implement `NotesWorkspaceView` basic tri-pane with create/edit/delete.

Phase 3: Secure Note Features
- Implement `SecureNotePolicyService` and `ProtectedTrashService`.
- Add secure toggle, expiry UI, lock badges, and expiration processing.
- Implement `TrashView` with browse, restore, and permanent-delete for both normal and secure notes.

Phase 4: Platform Hardening
- Add biometric unlock (`LocalAuthService`), auto-lock hooks (`PlatformIntegration`), notifications (`NotificationService`).
- Add audit-safe logging and time rollback protection (`TimeProvider`).
- Add `ExportImportService` flow for encrypted archive backup and atomic restore.

Phase 5: Optional Features
- Add minimal plugin metadata flow and settings refinements.

## 8. Done Criteria (Practical)
- Normal notes are stored as plain text and are accessible without authentication overhead.
- Secure notes are encrypted, require an expiration date, and route through protected trash on deletion or expiry.
- Workspace supports sidebar fold/unfold without losing selection context.
- Secure notes expire correctly and move to protected trash.
- Lock/unlock clears and restores key-dependent access correctly.
- Trash view lists all trashed items; secure notes show a lock badge instead of readable title.
- Restoring a secure note from trash requires active app unlock.
- Permanently deleting a secure note wipes ciphertext and attachments with no recovery path.
- Failure paths return explicit user-visible errors.