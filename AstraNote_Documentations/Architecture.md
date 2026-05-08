# AstraNotes Architecture

## 1. Goal and Principles
- Build the workable macOS notes app where notes are unencrypted by default and users can opt into secure mode per note.
- Keep UI simple: one Notability-style workspace screen for daily note work.
- Keep logic simple: thin UI, service-based core, repository persistence.
- Keep scope strict: local only, no cloud sync, and only simple plugin support in MVP.

## 2. MVP Scope (What We Build First)
- Unlock with passphrase; optional biometric unlock after first passphrase success.
- Tri-pane notes workspace:
	- Left: foldable subject sidebar.
	- Middle: note list/cards.
	- Right: note editor.
- Create, rename, and delete subject groups (folders) in the subject sidebar.
- Create, edit, delete, and restore notes.
- Normal notes are stored unencrypted; attachments are optional and limited to images and recordings.
- Secure note mode is opt-in per note: encrypts the note, requires an expiration date and time, and routes deletion through protected trash.
- Title search in workspace: normal note titles are searched from storage; secure note titles are searchable only while app is unlocked using in-memory decrypted matching.
- Voice capture trigger in the editor top bar (record and attach flow can start simple).
- Encrypted export/import for local backup and restore with atomic import behavior.
- Settings for lock timeout, telemetry opt-in, and a global plugin enable/disable toggle.
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
- `UnlockView.swift`: passphrase entry screen and first-launch passphrase creation screen; routes to biometric prompt when biometric unlock is enabled.
- `NotesWorkspaceView.swift`: single composition root for note UI.
	- `WorkspaceTopBar`: new note, search, voice capture button, secure status.
	- `SubjectSidebarPane`: hierarchy and filters; inline controls to create, rename, and delete subject groups.
	- `NoteCollectionPane`: note cards and selection.
	- `NoteEditorPane`: main note editor pane (right side) with secure toggle, expiration date/time controls, and secure option button placed at the top-right of the editor toolbar.
- `TrashView.swift`: lists all trashed notes (both normal and secure); shows note title, deletion time, and lock badge for secure notes; provides Restore and Permanently Delete actions per item.
- `SettingsView.swift`: settings forms only.
- `PluginStoreView.swift`: simple plugin management UI (install local package, enable/disable, remove, view status).

### AstraCore
- `AppCoordinator.swift`: app lifecycle, lock/unlock routing, navigation state handoff.
- `KeyManager.swift`: passphrase handling, derived key lifecycle, key clearing on lock, rate limiting and lockout enforcement on consecutive unlock failures.
- `EncryptionService.swift`: encrypt/decrypt payload boundary.
- `SubjectService.swift`: subject group CRUD (create, rename, delete); enforces non-empty name and prevents deletion of non-empty groups without confirmation.
- `NoteService.swift`: note CRUD orchestration; routes to encrypted or standard storage path based on note's secure flag.
- `NoteSearchService.swift`: title search orchestration for normal and secure notes (secure titles are matched in memory only while unlocked).
- `SecureNotePolicyService.swift`: secure-note rules (expiry checks, encryption enforcement, protected-delete decisions).
- `ProtectedTrashService.swift`: move/restore/permanent-delete logic.
- `SettingsService.swift`: validation + updates for settings.
- `ExportImportService.swift`: encrypted archive export/import orchestration included in MVP.
- `PluginService.swift`: minimal plugin host (manifest validation, enable/disable, safe plugin action execution, error isolation).

### AstraData
- `DatabaseProvider.swift`: connection, migration, transaction wrapper.
- `SubjectRepository.swift`: subject group persistence (id, name, display order).
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
0. On first launch, `AppCoordinator` detects no passphrase is set and routes to `UnlockView` for passphrase creation; no note data is stored until a passphrase is established.
1. `AppCoordinator` checks lock state.
2. `KeyManager` validates passphrase or biometric path; tracks consecutive failures and enforces rate-limited lockout after the threshold is exceeded.
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

### 5.7 Subject Group Management Flow
1. User creates a new subject group by tapping the add button in `SubjectSidebarPane` and entering a name.
2. `SubjectService` validates the name is non-empty and unique, then persists via `SubjectRepository`.
3. User can rename a subject group inline; `SubjectService` validates and updates the record.
4. User can delete a subject group; `SubjectService` requires confirmation if the group contains notes, then deletes the group record; notes in that group become ungrouped (`subjectId` set to null).
5. `AppState` updates selected subject and sidebar state after each operation.

### 5.8 Title Search Flow (Normal + Secure)
1. User types a search query in `WorkspaceTopBar`.
2. `NoteSearchService` queries normal note titles directly from `NoteRepository`.
3. If app is unlocked, `NoteSearchService` also matches secure note titles from in-memory decrypted title cache.
4. If app is locked, secure note titles are excluded from search results.
5. On lock event, `KeyManager` clears key material and `NoteSearchService` clears secure title cache.

### 5.9 Auto-Lock Flow
1. `PlatformIntegration` detects OS sleep, app backgrounding, or reports inactivity to `AppCoordinator`.
2. `AppCoordinator` checks whether the inactivity timer has exceeded the configured timeout from `SettingsService`, or whether a platform sleep/background event has triggered immediate lock.
3. Background operations (export, key rotation) do not count as user activity and do not reset the inactivity timer.
4. If a secure note is actively being edited, `NoteService` encrypts and persists unsaved draft content via `EncryptionService` before the lock transition completes.
5. `KeyManager` clears all in-memory key material.
6. `NoteSearchService` clears the in-memory secure title cache.
7. `AppCoordinator` routes UI to `UnlockView`; the editor pane content is masked.

### 5.10 Passphrase Change / Key Rotation Flow
1. User initiates passphrase change from `SettingsView`.
2. `KeyManager` validates the new passphrase and derives new key material.
3. If the new derived key is identical to the existing key, `KeyManager` returns an error to `SettingsView` informing the user that the new passphrase produces the same key as the current one and prompts them to choose a different passphrase; no re-encryption or storage write is performed.
4. `KeyManager` retains the old key material until all re-encryption is confirmed complete.
5. `NoteService` and `EncryptionService` iterate over all secure notes and attachments, re-encrypting each record under the new key; each write is an atomic transaction.
6. On completion, `KeyManager` removes the old key material.
7. If re-encryption is interrupted (crash, force quit), the retained old key allows `AppCoordinator` to detect the partial migration on next launch. The app shall always attempt to complete the remaining re-encryption first. Only if the completion attempt itself fails (e.g., a write error occurs) shall the app roll back all partially migrated records to the old key and restore the previous passphrase. In either outcome, the user is informed of the result before normal access is granted.
8. Normal notes are not affected by this flow.

### 5.11 Export / Import Flow
1. User initiates export from `SettingsView`; `ExportImportService` assembles an encrypted archive of all note records and required metadata, tagged with the current schema version and protected by the user's passphrase.
2. The archive is written atomically to a user-selected local path.
3. User initiates import from `SettingsView`; `ExportImportService` validates the archive signature, schema version, and passphrase before any data is written.
4. If the schema version is incompatible, import is rejected with an error identifying the mismatch.
5. `ExportImportService` resolves note ID conflicts by assigning new unique identifiers to imported notes; existing local records are not overwritten.
6. The entire import is wrapped in a single ACID transaction; if storage is exhausted or any write fails mid-import, the full operation rolls back with no partial state committed, and the user is informed with guidance to free storage before retrying.

## 6. Minimal Data Contracts
- Subject group record: `id`, `name`, `displayOrder`, timestamps.
- Normal note record: `id`, `subjectId` (nullable), `isSecure: false`, title/content as plain text, timestamps.
- Secure note record: `id`, `subjectId` (nullable), `isSecure: true`, encrypted title/content payload, nonce, salt, timestamps, expiration timestamp (required; date + time).
- Attachment record: `id`, `noteId`, `type` (image | recording), payload stored according to the note's security mode.
- Trash record: source note id, `isSecure`, deletion time, retention metadata; encrypted payload retained for secure notes until permanent delete.
- Settings: lock timeout, telemetry opt-in, plugin enabled (global on/off toggle).
- Plugin manifest: `pluginId`, `name`, `version`, `supportedAppVersion`, `entryAction`, `capabilities`.
- Plugin metadata: `pluginId`, install path/hash, enabled flag, last run status, last error.
- Search session cache (memory only): decrypted secure titles for active unlocked session; never persisted.
