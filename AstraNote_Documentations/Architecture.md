# AstraNotes Architecture

## 1. Goal and Principles
- Build the easiest workable macOS notes app where notes are unencrypted by default and users can opt into secure mode per note.
- Keep UI simple: one Notability-style workspace screen for daily note work.
- Keep logic simple: thin UI, service-based core, repository persistence.
- Keep scope strict: local only, no cloud sync, and only simple plugin support in MVP.

## 2. MVP Scope (What We Build First)
- Unlock with passphrase; optional biometric unlock after first passphrase success.
- Tri-pane notes workspace:
	- Left: foldable subject sidebar.
	- Middle: note list/cards.
	- Right: note editor.
- Create, edit, delete, and restore notes.
- Normal notes are stored unencrypted; attachments are optional.
- Secure note mode is opt-in per note: encrypts the note, requires an expiration date and time, and routes deletion through protected trash.
- Title search in workspace: normal note titles are searched from storage; secure note titles are searchable only while app is unlocked using in-memory decrypted matching.
- Voice capture trigger in the editor top bar (record and attach flow can start simple).
- Encrypted export/import for local backup and restore with atomic import behavior.
- Settings for lock timeout, telemetry opt-in, plugin preference flags.
- Simple plugin support: install from local package, enable/disable, and run plugin actions through a small host API.

Out of MVP:
- Cloud sync.
- Complex plugin execution host.
- Network-capable plugin marketplace.
- Advanced plugin permission prompts and granular capability sandbox.
- Advanced rich-text tooling beyond a basic editor.

## 3. Module Map (Single Responsibility)

### AstraUI
- `AppState.swift`: session/view state, selected subject, selected note, pane collapse state.
- `NotesWorkspaceView.swift`: single composition root for note UI.
	- `WorkspaceTopBar`: new note, search, voice capture button, secure status.
	- `SubjectSidebarPane`: hierarchy and filters.
	- `NoteCollectionPane`: note cards and selection.
	- `NoteEditorPane`: main note editor pane (right side) with secure toggle, expiration date/time controls, and secure option button placed at the top-right of the editor toolbar.
- `TrashView.swift`: lists all trashed notes (both normal and secure); shows note title, deletion time, and lock badge for secure notes; provides Restore and Permanently Delete actions per item.
- `SettingsView.swift`: settings forms only.
- `PluginStoreView.swift`: simple plugin management UI (install local package, enable/disable, remove, view status).

### AstraCore
- `AppCoordinator.swift`: app lifecycle, lock/unlock routing, navigation state handoff.
- `KeyManager.swift`: passphrase handling, derived key lifecycle, key clearing on lock.
- `EncryptionService.swift`: encrypt/decrypt payload boundary.
- `NoteService.swift`: note CRUD orchestration; routes to encrypted or standard storage path based on note's secure flag.
- `NoteSearchService.swift`: title search orchestration for normal and secure notes (secure titles are matched in memory only while unlocked).
- `SecureNotePolicyService.swift`: secure-note rules (expiry checks, encryption enforcement, protected-delete decisions).
- `ProtectedTrashService.swift`: move/restore/permanent-delete logic.
- `SettingsService.swift`: validation + updates for settings.
- `ExportImportService.swift`: encrypted archive export/import orchestration included in MVP.
- `PluginService.swift`: minimal plugin host (manifest validation, enable/disable, safe plugin action execution, error isolation).

### AstraData
- `DatabaseProvider.swift`: connection, migration, transaction wrapper.
- `NoteRepository.swift`: note persistence for both standard and secure notes.
- `AttachmentRepository.swift`: attachment persistence matching the note's security mode.
- `ProtectedTrashRepository.swift`: protected trash records.
- `SettingsRepository.swift`: settings persistence.
- `PluginMetadataRepository.swift`: plugin metadata persistence.
- `PluginBundleRepository.swift`: local plugin package index/path metadata.

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
- Secure note title search never reads plaintext from persistent storage; search for secure titles runs only on in-memory decrypted data while unlocked.
- Plugins can call only the small host API exposed by `PluginService.swift`; plugins never access repositories directly.
- Plugin failures are contained and surfaced as user-visible errors without crashing note editing flows.

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
1. When user enables secure mode, an expiration date and time are required.
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

### 5.6 Plugin Action Flow (Simple MVP)
1. User installs a local plugin package from `PluginStoreView`.
2. `PluginService` validates manifest structure and records plugin metadata.
3. User enables plugin and triggers a supported action (for example, a text transform on current note content).
4. `PluginService` executes the action through the host API with timeout and error guard.
5. On success, `NoteService` applies the returned result through normal save flow; on failure, app shows error and keeps current note state unchanged.

### 5.7 Title Search Flow (Normal + Secure)
1. User types a search query in `WorkspaceTopBar`.
2. `NoteSearchService` queries normal note titles directly from `NoteRepository`.
3. If app is unlocked, `NoteSearchService` also matches secure note titles from in-memory decrypted title cache.
4. If app is locked, secure note titles are excluded from search results.
5. On lock event, `KeyManager` clears key material and `NoteSearchService` clears secure title cache.

## 6. Minimal Data Contracts
- Normal note record: `id`, `isSecure: false`, title/content as plain text, timestamps.
- Secure note record: `id`, `isSecure: true`, encrypted title/content payload, nonce, salt, timestamps, expiration timestamp (required; date + time).
- Attachment record: `id`, `noteId`, payload stored according to the note's security mode.
- Trash record: source note id, `isSecure`, deletion time, retention metadata; encrypted payload retained for secure notes until permanent delete.
- Settings: lock timeout, telemetry opt-in, plugin prefs.
- Plugin manifest: `pluginId`, `name`, `version`, `supportedAppVersion`, `entryAction`, `capabilities`.
- Plugin metadata: `pluginId`, install path/hash, enabled flag, last run status, last error.
- Search session cache (memory only): decrypted secure titles for active unlocked session; never persisted.

## 7. Implementation Plan (Lowest-Risk Order)

Phase 1: Foundation
- Implement `DatabaseProvider`, repositories, and migrations.
- Implement `KeyManager` + `EncryptionService` with test vectors.

Phase 2: Core Note Lifecycle
- Implement `NoteService` CRUD with encrypted persistence.
- Implement `NotesWorkspaceView` basic tri-pane with create/edit/delete.
- Implement title search for normal notes in `WorkspaceTopBar` + `NoteSearchService`.

Phase 3: Secure Note Features
- Implement `SecureNotePolicyService` and `ProtectedTrashService`.
- Add secure toggle, expiry date/time UI, lock badges, and expiration processing.
- Implement `TrashView` with browse, restore, and permanent-delete for both normal and secure notes.
- Extend title search to include secure notes via unlocked in-memory matching and cache clear on lock.

Phase 4: Platform Hardening
- Add biometric unlock (`LocalAuthService`), auto-lock hooks (`PlatformIntegration`), notifications (`NotificationService`).
- Add audit-safe logging and time rollback protection (`TimeProvider`).
- Add `ExportImportService` flow for encrypted archive backup and atomic restore.

Phase 5: Simple Plugin Support
- Add local plugin install/remove and enable/disable in `PluginStoreView`.
- Implement minimal `PluginService` host API and action execution guardrails.
- Persist plugin metadata and status in plugin repositories.

## 8. Done Criteria (Practical)
- Normal notes are stored as plain text and are accessible without authentication overhead.
- Secure notes are encrypted, require an expiration date and time, and route through protected trash on deletion or expiry.
- Workspace supports sidebar fold/unfold without losing selection context.
- Secure notes expire correctly and move to protected trash.
- Lock/unlock clears and restores key-dependent access correctly.
- Trash view lists all trashed items; secure notes show a lock badge instead of readable title.
- Restoring a secure note from trash requires active app unlock.
- Permanently deleting a secure note wipes ciphertext and attachments with no recovery path.
- Failure paths return explicit user-visible errors.
- User can install a local plugin package, enable or disable it, and run at least one supported plugin action from the app.
- Plugin action failures do not crash the app and do not corrupt note data.
- Title search returns matching normal note titles at any time.
- Secure note titles are searchable only while unlocked and are never stored as plaintext in persistent storage.