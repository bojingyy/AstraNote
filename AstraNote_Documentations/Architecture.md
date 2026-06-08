# AstraNotes Architecture

## 1. Goal and Principles
- A local-first macOS notes app where notes are unencrypted by default and users can opt into per-note secure mode.
- One workspace screen for daily note work — no separate navigation hierarchy.
- Thin UI, actor-based service layer, repository persistence over an in-process transactional store.
- Strictly local: no cloud sync, no network plugin marketplace.

## 2. Implemented Feature Set
- First-launch passphrase creation (`UnlockView`) before any note data is stored. On every later launch the workspace opens directly — there is no whole-app unlock screen; only secure-note operations prompt for passphrase or biometric step-up authentication, in context, when needed.
- Two-pane workspace in `NotesWorkspaceView`:
  - Left: a single collapsible panel combining subject groups and the notes nested under each group (fold/unfold per group and for the whole panel; resizable divider).
  - Right: the note editor (title, subject picker, secure-mode toggle + alias field, rich text formatting toolbar, attachments list, save/delete actions).
- Create, edit, delete, and restore notes; create and delete subject groups (with confirmation when a group still contains notes — ungrouping its notes rather than deleting them).
- Normal notes are stored as plaintext; secure notes are encrypted (AES-256-GCM, per-note key derived via HKDF from the passphrase-derived master key) and identified in lists/search/trash by a non-sensitive, user-editable alias (default "Locked Note").
- Attachments: image and voice-recording attachments, with size limits (20 MB images / 50 MB recordings), Open/Reveal/Delete actions, and secure-note-aware authentication continuation when an attachment is added to a secure note that needs re-authentication first.
- Title search across normal note titles and secure note aliases (simple case-insensitive substring match over the in-memory active note list).
- Protected trash: deleting a note moves it (and its attachments) to trash; restoring a secure note requires an unlocked session; the trash list shows each secure note's actual alias with a lock icon.
- Rich text formatting: bold, italic, underline, font size, and a small preset color palette, applied to the current selection.
- Settings: plugin enable/disable (global toggle), biometric unlock enrollment, change passphrase (with full re-encryption of secure notes), and encrypted backup export/import.
- Plugin management UI: list installed plugins and toggle them on/off. (Install, remove, and action-execution are implemented and tested at the service layer — `PluginService.install/remove/execute/registerHandler` — but have **no UI entry point**; nothing in the running app calls them.)
- Encrypted, schema-versioned backup export/import (`ExportImportService` + a "Backup & Restore" section in Settings): produces/consumes a single encrypted archive of the entire local database, atomically merged with conflict-safe ID remapping on import.

### Implemented but not wired to the UI (dead at runtime)
These exist, build, and are covered by tests, but nothing in the running app ever exercises them:
- `SecureNotePolicyService`: a deliberate no-op. `validateSecureExpiration`, `handleLaunchTimeCheckpoint`, and `sweepExpiredSecureNotes` do nothing but log a "skipped" event and return an empty result — there is no time-based secure-note expiration in the runtime model. `NoteDraft.init` still accepts an `expirationUTC` parameter, but it is discarded and never persisted.
- `InMemoryNotificationService` / `NotificationServiceProtocol`: only records `ExpiryNotificationEvent`s in memory for tests; it is never invoked from the app (there is nothing to notify about, since expiration sweeping is a no-op). It does not post real macOS notifications.
- `InMemoryPlatformIntegration.publish(_:)`: nothing in the app ever calls `publish`, so the `PlatformEvent` stream that `AppCoordinator.bind(platformIntegration:)` subscribes to never actually emits real OS sleep/background/foreground events. In practice, in-memory key material is cleared only via the explicit `lockNow()`/`handleImmediateLockEvent()` paths the coordinator exposes (which are themselves not triggered by any current UI control), and via process restart (`start()` always begins a relaunch in `.locked` state if a passphrase exists).
- `SubjectService.rename(id:newName:)` / `SubjectRepository` rename support: implemented and validated (non-empty, unique name), but there is no rename control anywhere in `NotesWorkspaceView`.
- `InMemoryStorageProtection`: tracks a `[path: StorageProtectionClass]` dictionary purely in memory for tests/audit; it does **not** apply real macOS file-protection/Data Protection APIs to attachment files on disk. Attachment files are written as plain files in `~/Library/Application Support/AstraNotes/Attachments/`; the `isEncrypted` flag on `Attachment`/`StoredAttachmentRecord` records the note's secure-mode *intent* at creation time, not actual at-rest encryption of the attachment bytes.

Out of scope (by design):
- Cloud sync, a plugin marketplace, granular plugin permission/sandbox prompts, advanced rich-text tooling beyond the basic toolbar, and any form of per-note export (e.g. PDF) — none of this exists in the codebase.

## 3. Module Map (as implemented)

### AstraUI
- `AstraNotesApp.swift`: app entry point and `NSApplicationDelegate` (activation policy, app icon assignment from `AstraNotes_Logo.png`).
- `AppEnvironment.swift`: composition root — constructs and owns every repository, service, and the `AppCoordinator`; injects them into the view tree.
- `ContentView.swift`: root view; switches on `AppCoordinator.SessionState` (`.firstLaunchSetup` → `UnlockView`, `.locked`/`.unlocked` → `NotesWorkspaceView`); owns the one-time coordinator `start()`/`bind()` call and forwards every action closure from services to the workspace.
- `UnlockView.swift`: passphrase entry/creation screen. In practice it is reachable **only** in `.firstLaunchSetup` (no later-launch unlock screen exists in the routing).
- `NotesWorkspaceView.swift`: the single, large composition root for all note UI (~1,300 lines). There are no separate `WorkspaceTopBar`/`SubjectSidebarPane`/`NoteCollectionPane`/`NoteEditorPane`/`WorkspaceToastOverlay`/`TrashView` types — all of that UI (header bar + search, the combined subject/notes left panel, the editor pane, toast notifications, the trash sheet, the secure-access-prompt sheet, the subject-deletion confirmation alert) is implemented inline as sections and `.sheet`/`.alert` modifiers within this one view, backed by private `@State` and helper structs (`NoteListItem`, `SubjectGroup`, `ToastMessage`, `PendingAttachment`, `PendingSecureAccessAction`).
- `SettingsView.swift`: settings form — plugin/biometric toggles, Change Passphrase section, Backup & Restore (export/import) section, and the embedded `PluginStoreView`.
- `PluginStoreView.swift`: lists installed plugins with an enable/disable toggle only (no install/remove UI).
- `RichTextEditor.swift`: `NSViewRepresentable` wrapper around `NSTextView` powering the rich text editor and its formatting toolbar.
- `WorkspaceAttachmentSupport.swift`: `WorkspaceAttachmentImport` (file picker, copy-into-app-storage, Open/Reveal via `NSWorkspace`) and `AudioRecordingController` (microphone permission + `AVAudioRecorder`-based voice capture).
- `SecureFieldTestView.swift`: an unused preview/debug view (only referenced by its own SwiftUI preview; not part of any navigation path).

### AstraCore
- `AppCoordinator.swift`: `@MainActor` `ObservableObject` exposing `SessionState` (`.firstLaunchSetup` / `.locked` / `.unlocked`); orchestrates first-launch routing, unlock/biometric unlock, in-context secure-note re-authentication, passphrase change, immediate-lock handling (gated on active background operations), biometric enrollment refresh, and platform-event subscription. There is **no inactivity-timeout auto-lock** — that mechanism (and the corresponding `lockTimeoutSeconds` setting) has been removed from the codebase.
- `Services/Security/KeyManager.swift`: passphrase lifecycle — PBKDF2-HMAC-SHA256 key derivation (100,000 iterations, 32-byte key, random 16-byte salt), in-memory-only key material (never persisted/restored from disk), rate limiting (lockout after 5 failed attempts within a 30s window, exponential backoff from 30s up to 1 hour), and `changePassphrase` (validates the current passphrase, rejects an identical new passphrase, re-derives a new key, and re-encrypts every secure note's payload inside one atomic transaction with rollback-safe pending-rotation tracking recovered on next launch).
- `Services/Crypto/EncryptionService.swift` + `PBKDF2.swift`: AES-GCM encrypt/decrypt boundary and PBKDF2 key derivation primitives.
- `Services/SecurePayloadCodec.swift`: encodes/decodes the `{title, content}` plaintext bundle that gets encrypted for secure notes.
- `Services/SubjectService.swift`: subject CRUD — enforces non-empty, unique names; `delete` ungroups the subject's notes rather than deleting them; `rename` exists and is validated but is not exposed in the UI.
- `Services/NoteService.swift`: note CRUD orchestration — routes save/load through plaintext or encrypted payload paths based on `secureModeEnabled`/`isSecure`; manages secure-title-alias normalization (default "Locked Note"); owns attachment add/list/delete (`addImageAttachment`, `addVoiceAttachment`, `listAttachments`, `deleteAttachment` — the last removes the DB record and best-effort deletes the underlying file).
- `Services/NoteSearchService.swift`: simple in-memory substring search over `NoteRepository.fetchAllActive()` — matches normal notes by `plainTitle` and secure notes by `secureTitleAlias` only; `clearSecureCacheOnLock`/`secureCacheCount` are intentional no-ops because there is no decrypted-title cache to clear.
- `Services/SecureNotePolicyService.swift`: a **deliberate no-op** boundary for secure-note time-based policy — all three of its public methods log a "skipped" event and return empty/zero results. Retained as an extension point, not an active rule engine.
- `Services/ProtectedTrashService.swift`: move/restore/permanent-delete orchestration — `listTrashItems` builds `TrashItemView`s (including each secure note's real `secureTitleAlias` for display); `restore` requires active key material for secure notes (`restoreRequiresUnlockedSession`); `secureTitlePreviewMessage` returns a fixed "locked" explanation for secure items and the plain title otherwise.
- `Services/SettingsService.swift`: thin validation/update wrapper over `SettingsRepository` for `pluginsEnabled` and `biometricUnlockEnabled` (telemetry and lock-timeout settings have been removed from the model entirely).
- `Services/ExportImportService.swift`: encrypted archive export/import — see Section 5.11.
- `Services/PluginService.swift`: manifest validation, install/remove/list/enable-disable, and timeout-guarded action execution through a registered handler map (`registerHandler`/`execute`). Only `listInstalled`/`setEnabled` are reachable from the UI today.
- `Models/CoreModels.swift`: `EncryptedPayload`, `KeyMaterial`, `Attachment`/`AttachmentType`, `NoteDraft`, `NoteView`, `NoteSummary`, `Subject`, `AppSettings`, `PluginManifest`/`InstalledPlugin`/`PluginActionRequest`/`PluginActionResult`, `ImportConflictResolution`/`ImportResult`.

### AstraData
- `Database/DatabaseProvider.swift`: in-process actor-backed transactional store (`read`/`transaction`) over a single `DatabaseState` value; optionally persists a JSON snapshot to `~/Library/Application Support/AstraNotes/database-state.json` after every successful mutation, and reloads it on init.
- `Models/PersistenceModels.swift`: `StoredEncryptedPayload`, `StoredNoteRecord`, `StoredAttachmentRecord`, `StoredSubjectRecord`, `StoredSettingsRecord`, `StoredTrashRecord`, `StoredCredentialState`/`StoredCredentialRotationState`, `StoredPluginMetadataRecord`/`StoredPluginBundleRecord`, and the aggregate `DatabaseState`.
- `Repositories/`: `NoteRepository`, `SubjectRepository`, `AttachmentRepository` (incl. `fetch(id:)`/`remove(id:)` for attachment deletion), `ProtectedTrashRepository`, `SettingsRepository`, `PluginMetadataRepository`, `PluginBundleRepository` — each a thin actor wrapper translating between `DatabaseState` collections and typed protocol APIs.

### AstraPlatform
- `LocalAuthService.swift`: `SystemLocalAuthService` — real Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) + `LocalAuthentication` (Touch ID/Face ID) integration for biometric enrollment/authentication/clear.
- `StorageProtection.swift`: `InMemoryStorageProtection` — an in-memory `[path: StorageProtectionClass]` tracker; **not** a real OS file-protection integration (see callout in Section 2).
- `NotificationService.swift`: `InMemoryNotificationService` — in-memory event log only; not wired to real macOS notifications, and never invoked at runtime (see callout in Section 2).
- `TimeProvider.swift`: `SystemTimeProvider` (UTC clock abstraction used throughout for testability).
- `AuditLogger.swift`: `AuditLogging`/in-memory implementation — sanitized, non-sensitive event logging (e.g. `unlock_failed`, `unlock_lockout`, `passphrase_rotated`, `plugin_installed`, `export_completed`).
- `PlatformIntegration.swift`: `PlatformEvent` enum + `InMemoryPlatformIntegration` pub/sub stream; `publish` is never called anywhere in the app (see callout in Section 2).

## 4. Runtime Boundaries
- UI never performs encryption or direct database writes; it calls into actor-isolated services via injected async closures.
- Core services never depend on SwiftUI; `AppCoordinator` is the only `@MainActor`/`ObservableObject` type, and it depends only on `AstraPlatform`/`AstraCore` types.
- Repositories store standard notes as plaintext fields and secure notes as `securePayload` ciphertext only (`plainTitle`/`plainContent` are nil for secure notes); `NoteService` decides the storage path from `secureModeEnabled`/`isSecure`.
- `KeyManager` is the single source of truth for in-memory key material; it is never persisted to or restored from disk — every relaunch with an existing passphrase starts in `.locked`, requiring fresh derivation.
- Secure note title search never touches decrypted titles; `NoteSearchService` matches secure notes by their persisted, non-sensitive `secureTitleAlias` only.
- Plugins reach the app only through `PluginService`'s manifest/action surface; they never touch repositories directly. Execution is timeout-guarded and failures are logged and surfaced as typed errors without crashing note flows — though, as noted, no UI path currently triggers plugin execution.
- `SecureNotePolicyService` is intentionally inert; it exists as a seam for future time-based secure-note rules without being part of any active decision path today.

## 4.1 Confidentiality Enforcement (Data Flow Assertions)
- **Disk persistence**: Decrypted secure note content is never written to disk. `StoredNoteRecord` persists only `securePayload` (ciphertext + nonce + tag + salt) and the non-sensitive `secureTitleAlias` for secure notes. Only `EncryptionService`, driven by `NoteService`/`KeyManager`, performs decrypt operations, and results are held only transiently in `@State` for UI display.
- **Logging**: `AuditLogger` records only event names and small, non-content metadata (counts, durations, plugin/note IDs); note titles, content, and passphrases are never logged.
- **Caching**: `NoteSearchService` holds no decrypted-title cache — it re-reads `secureTitleAlias` from storage on every search and its "clear on lock" hook is a documented no-op because there is nothing to clear.
- **Exports**: `ExportImportService.exportArchive()` strips runtime-only/sensitive fields (credentials, pending rotation state, clock-protection fields) from the snapshot, then encrypts the entire JSON snapshot with the user's key material before wrapping it in the archive envelope — the exported file contains no plaintext secure-note content.
- **UI display**: Decrypted secure content lives only in `@State` on `NotesWorkspaceView` while the note is open; selecting away or beginning a new draft resets those fields (`clearEditorForNewNote`/`beginNewDraft`).
- **Attachments — caveat**: Attachment *files* are stored as plain files on disk; `InMemoryStorageProtection` only records an intended classification in memory and applies no real OS-level file protection. The confidentiality guarantee for attachments rests on the host's disk encryption (e.g. FileVault), not on app-level encryption of the attachment bytes.
- **Plugins**: Plugin actions would receive content only through `PluginService.execute`, gated on global enablement, per-plugin enablement, and a registered handler — but no UI path invokes this today.

## 5. Primary User Flows

### 5.1 First Launch / Unlock
1. On first launch, `AppCoordinator.start()` finds no stored passphrase and sets `.firstLaunchSetup`; `ContentView` shows `UnlockView`, which collects and confirms a new passphrase via `createInitialPassphraseAndUnlock`. This derives and stores credentials, sets `.unlocked`, and (if biometrics are already enabled in settings) enrolls the new key for Touch ID/Face ID.
2. On every later launch, `start()` finds an existing passphrase and sets `.locked` — **key material is intentionally not restored from disk**; `ContentView` routes `.locked` straight to `NotesWorkspaceView` (no unlock screen). Plain notes are immediately usable.
3. The first time a secure-mode operation needs the encryption key (opening a secure note, saving a new/changed secure note, or continuing a secure-note attachment), `NotesWorkspaceView` shows the in-context secure-access sheet (`isShowingSecureAccessPrompt`), offering passphrase entry (`reauthenticateForSecureNote`) or biometrics (`reauthenticateForSecureNoteWithBiometrics`, only if enabled and enrolled). On success, the original pending action (`pendingSecureAccessAction`: `.openSecureNote` / `.saveSecureDraft` / `.continueAttachment`) is retried automatically.
4. `KeyManager` enforces rate limiting: 5 failed attempts within 30 seconds trigger an escalating lockout (30s, doubling up to 1 hour), surfaced as `KeyManagerError.lockoutActive(remainingSeconds:)`.

### 5.2 Create / Edit Note
1. The editor pane builds a `NoteDraft` from the current title/content/subject/secure-mode/alias and calls `saveDraftAction` → `NoteService.save`.
2. `NoteService` checks `draft.secureModeEnabled`. If off, it persists `plainTitle`/`plainContent` directly. If on, it requires `KeyManager.currentKeyMaterial()`; if the key is unavailable it throws `keyMaterialUnavailable`, which the workspace catches and turns into the secure-access prompt (`.saveSecureDraft`) — except when only the alias/subject of an *existing* secure note changed, in which case `updateSecureMetadataAction` updates that metadata without requiring the key (no re-encryption needed).
3. On success the workspace refreshes the note list, reselects the saved note, and shows a toast.

### 5.3 Secure Note Lifecycle
1. Enabling secure mode on save encrypts the note immediately; there is no separate "convert to secure" step.
2. `SecureNotePolicyService` is wired into `AppEnvironment` but is a deliberate no-op — there is no time-based expiration, sweeping, or launch-time checkpoint behavior in the running app, regardless of what `NoteDraft.expirationUTC` callers might pass (it is accepted but discarded).
3. Secure notes remain active until explicitly deleted (→ protected trash) or permanently removed from trash.
4. Opening a secure note, or any operation that needs to decrypt its payload, goes through the same in-context step-up authentication described in 5.1.3.

### 5.4 Trash Flow (Normal Note)
1. User deletes a normal note from the editor; `NoteService.delete` moves it (and its attachments) into protected trash via `ProtectedTrashRepository`.
2. The workspace optimistically inserts a `TrashItemView` into the trash sheet's list and then reloads from `ProtectedTrashService.listTrashItems()`.
3. The trash sheet shows title, deletion time, and **Restore** / **Delete Permanently** actions.
4. Restore returns the note to the active list; Permanently Delete removes the record (and trashed attachments) entirely.

### 5.5 Trash Flow (Secure Note)
1. Deleting a secure note moves the encrypted record (ciphertext intact) to protected trash.
2. The trash sheet shows a lock icon plus the note's **actual `secureTitleAlias`** (not a generic placeholder) — `TrashItemView.secureTitleAlias` is populated from the stored record, and the optimistic insert path threads the alias through immediately so it's correct even before the list reloads.
3. "Why Locked?" surfaces a fixed explanatory message via `secureTrashPreviewAction` without decrypting anything.
4. Restoring requires an unlocked session (`ProtectedTrashServiceError.restoreRequiresUnlockedSession` if `KeyManager.currentKeyMaterial()` is nil); the workspace maps this to "Unlock AstraNotes to restore secure notes from trash."
5. Permanently deleting wipes the ciphertext and associated attachment files; the note becomes unrecoverable.

### 5.6 Plugin Management (UI) vs. Plugin Execution (service-only)
1. **What the UI does**: `PluginStoreView` (embedded in Settings) lists installed plugins (`listInstalled`) and lets the user toggle each one's enabled state (`setEnabled`). That is the entire plugin surface reachable from the app today.
2. **What exists but isn't wired up**: `PluginService.install(manifest:bundleData:)` (manifest/bundle validation, duplicate-install rejection), `remove(pluginId:)`, `registerHandler`/`execute` (global- and per-plugin-enablement checks, a registered async handler, and a 2-second timeout race via `withThrowingTaskGroup`) are fully implemented and exercised by tests, but no view ever calls them — there is no install picker, no remove button, and nothing that registers a handler or triggers an action.

### 5.7 Subject Group Management
1. Creating a subject: the user enters a name in the left-panel "New subject" field; `SubjectService.create` trims, validates non-empty/unique, and persists via `SubjectRepository`.
2. Deleting a subject: if the group still has notes, a confirmation alert ("Delete Subject?") warns that its notes will be ungrouped; `SubjectService.delete` always ungroups the notes (`subjectId = nil`) rather than deleting them, then removes the subject record.
3. Renaming: `SubjectService.rename`/`SubjectRepository` support it and validate uniqueness, but **no UI control exists** to invoke it.

### 5.8 Title Search
1. The user types into the search field in the left panel's header and presses Enter or **Search**.
2. `NoteSearchService.searchTitle` does a simple case-insensitive substring match: normal notes by `plainTitle`, secure notes by `secureTitleAlias`. It reads fresh from `NoteRepository.fetchAllActive()` each time — there is no cache to invalidate, which is why `clearSecureCacheOnLock`/`secureCacheCount` are no-ops.
3. **Reset** clears the query and search results and reloads the full workspace list.

### 5.9 Lock / Key-Clearing Behavior
1. `AppCoordinator` exposes `lockNow()` (clears in-memory key material and calls the search service's no-op cache clear) and `handleImmediateLockEvent()` (defers the lock until any in-flight background operation — tracked via `beginBackgroundOperation`/`endBackgroundOperation` — completes, then calls `lockNow()`).
2. `bind(platformIntegration:)` subscribes to `PlatformEvent`s (`appDidBackground`/`osWillSleep` → immediate lock; `userInteraction`/`appDidForeground`/`osDidWake` → record interaction) — but **`InMemoryPlatformIntegration.publish` is never called anywhere in the app**, so this stream never actually emits in the running process. There is also no inactivity-timeout polling (that mechanism, and its settings field, were removed).
3. In practice, the only way in-memory key material gets cleared during a session is if some future code path calls `lockNow`/`handleImmediateLockEvent`/`publish` — none currently does. Relaunching the app always returns to `.locked` (per 5.1.2), which is the de facto "lock" the user experiences.
4. Whichever way the key is cleared, the workspace remains usable for normal notes; any subsequent secure-note operation re-triggers the in-context authentication flow from 5.1.3.

### 5.10 Passphrase Change / Key Rotation
1. The user enters current/new/confirm passphrases in the Settings "Change Passphrase" section; client-side validation requires the new passphrase to be non-empty and match its confirmation.
2. `AppCoordinator.changePassphrase` → `KeyManager.changePassphrase`: re-derives the old key from the current passphrase and verifies it, derives a candidate new key and rejects it if identical to the old one (`KeyManagerError.identicalPassphrase`), then opens a single database transaction that re-checks the stored credentials, **re-encrypts every secure note's `securePayload`** under the new key, and writes the new `StoredCredentialState` — all inside one atomic commit, with a `pendingCredentialRotation` marker that `recoverPendingRotationIfNeeded` clears (and logs as recovered) on the next unlock if the process was interrupted mid-rotation.
3. **Attachments are not re-encrypted** during rotation — consistent with the fact that attachment files are not encrypted at the app layer in the first place (see Section 2/4.1 caveats).
4. On success, in-memory key material is replaced and (if biometrics are enabled) re-enrolled; `SettingsView` shows a success message and clears the fields. Errors map to friendly text for `invalidPassphrase`, `identicalPassphrase`, `passphraseNotInitialized`, and `migrationUnavailable`.

### 5.11 Backup Export / Import
1. **UI**: Settings → "Backup & Restore" → **Export Backup…** / **Import Backup…**, each driving an `NSSavePanel`/`NSOpenPanel`.
2. **Export**: `ExportImportService.exportArchive()` requires unlocked key material, snapshots the database, strips sensitive/runtime-only fields (credentials, pending rotation, clock-protection state), JSON-encodes the snapshot, encrypts the whole thing with the user's key (AES-GCM), and wraps it with a schema version into an `ExportEnvelope`. `SettingsView` writes the resulting `Data` atomically to the chosen file.
3. **Import**: also requires unlocked key material. The service decodes the envelope, rejects archives with a schema version newer than the local one (`unsupportedSchemaVersion`), decrypts and decodes the inner snapshot, and merges it into the live database inside a single atomic transaction. With the default `regenerateIncomingIdentifiers` resolution, any colliding subject/note/attachment/trash/plugin IDs are remapped to fresh UUIDs (with all cross-references rewritten consistently) so imported data merges alongside existing data without overwriting it; a `.reject` mode is also available that aborts on any ID collision.
4. `SettingsView` reports the result (`importedNotes`/`importedSubjects`/`importedPlugins` counts) or maps `keyMaterialUnavailable` / `invalidArchive` / `unsupportedSchemaVersion` / `importConflict` to user-facing messages.

## 6. Data Contracts (as persisted / passed across boundaries)
- **Subject** (`Subject` / `StoredSubjectRecord`): `id`, `name`, `displayOrder`, `createdAt`.
- **Note** (`StoredNoteRecord`): `id`, `subjectId?`, `isSecure`, `plainTitle?`, `plainContent?`, `securePayload?` (`StoredEncryptedPayload`: ciphertext/nonce/tag/salt), `secureTitleAlias?`, `createdAt`, `updatedAt`. For normal notes `plainTitle`/`plainContent` are populated and `securePayload`/`secureTitleAlias` are nil; for secure notes the reverse.
- **NoteDraft** (UI → service): `id?`, `title`, `content`, `subjectId?`, `secureModeEnabled`, `secureTitleAlias?`. (`expirationUTC` is accepted by the initializer for source compatibility but is never stored or used.)
- **Attachment** (`Attachment` / `StoredAttachmentRecord`): `id`, `noteId`, `type` (`.image` | `.recording`), `storagePath`, `byteSize`, `isEncrypted` (records the owning note's secure-mode *intent* at creation time — not real at-rest file encryption), `createdAt`.
- **Trash record** (`StoredTrashRecord` / `TrashItemView`): `id`/`trashId`, `sourceNote` (full `StoredNoteRecord`, including `secureTitleAlias`), `attachments`, `deletedAt`; `TrashItemView` additionally exposes `isSecure`, `displayTitle?` (normal notes only), `secureTitleAlias?` (secure notes only), and `lockBadgeVisible`.
- **Settings** (`AppSettings` / `StoredSettingsRecord`): `pluginsEnabled`, `biometricUnlockEnabled`. (Telemetry opt-in and lock-timeout fields have been removed entirely.)
- **Credentials** (`StoredCredentialState`): `salt`, `hash`, `iterations`; plus transient `StoredCredentialRotationState(startedAt:)` while a passphrase change is in flight.
- **Plugin manifest** (`PluginManifest`): `pluginId`, `displayName`, `version`, `capabilities`.
- **Installed plugin** (`InstalledPlugin` / `StoredPluginMetadataRecord`): `pluginId`, `displayName`, `version`, `capabilities`, `isEnabled`, `installedAt`; bundle bytes live separately in `StoredPluginBundleRecord(pluginId:bundleData:)`.
- **Import result** (`ImportResult`): `importedNotes`, `importedSubjects`, `importedPlugins`; resolution strategy is `ImportConflictResolution.reject` or `.regenerateIncomingIdentifiers`.
- **Database snapshot** (`DatabaseState`): `schemaVersion`, `notes`, `attachments`, `subjects`, `trash`, `pluginMetadata`, `pluginBundles`, `settings`, plus runtime-only `credentials?`, `pendingCredentialRotation?`, `lastKnownUTC?`, `rollbackGuardUntilUTC?` (the last four are stripped before export/import merge).
