# AstraNotes Architecture

## 1. Goal and Principles
- A local-first macOS notes app where notes are unencrypted by default and users can opt into per-note secure mode.
- One workspace screen for daily note work — no separate navigation hierarchy.
- Thin UI, actor-based service layer, repository persistence over an in-process transactional store.
- Strictly local: no cloud sync, no network plugin marketplace.


## 2. Module Map

### AstraUI
- `AstraNotesApp.swift`: app entry point and `NSApplicationDelegate` (activation policy, app icon assignment from `AstraNotes_Logo.png`).
- `AppEnvironment.swift`: composition root — constructs and owns every repository, service, and the `AppCoordinator`; injects them into the view tree.
- `ContentView.swift`: root view; switches on `AppCoordinator.SessionState` (`.firstLaunchSetup` → `UnlockView`, `.locked`/`.unlocked` → `NotesWorkspaceView`); owns the one-time coordinator `start()`/`bind()` call and forwards every action closure from services to the workspace.
- `UnlockView.swift`: passphrase entry/creation screen. The routing reaches it **only** in `.firstLaunchSetup`; there is no later-launch unlock screen.
- `NotesWorkspaceView.swift`: the single, large composition root for all note UI (~1,300 lines). There are no separate `WorkspaceTopBar`/`SubjectSidebarPane`/`NoteCollectionPane`/`NoteEditorPane`/`WorkspaceToastOverlay`/`TrashView` types — all of that UI (header bar + search, the combined subject/notes left panel, the editor pane, toast notifications, the trash sheet, the secure-access-prompt sheet, the subject-deletion confirmation alert) is implemented inline as sections and `.sheet`/`.alert` modifiers within this one view, backed by private `@State` and helper structs (`NoteListItem`, `SubjectGroup`, `ToastMessage`, `PendingAttachment`, `PendingSecureAccessAction`).
- `SettingsView.swift`: settings form — plugin/biometric toggles, Change Passphrase section, Backup & Restore (export/import) section, and the embedded `PluginStoreView`.
- `PluginStoreView.swift`: lists installed plugins with enable/disable toggles, an "Install Plugin…" sheet (`InstallPluginSheet`, with `NSOpenPanel` bundle-file picker), and a per-row Remove button with confirmation. (Plugin execution has no UI surface by design — see 5.6.)
- `RichTextEditor.swift`: `NSViewRepresentable` wrapper around `NSTextView` powering the rich text editor and its formatting toolbar.
- `WorkspaceAttachmentSupport.swift`: `WorkspaceAttachmentImport` (file picker, copy-into-app-storage, Open/Reveal via `NSWorkspace`) and `AudioRecordingController` (microphone permission + `AVAudioRecorder`-based voice capture).
- `SecureFieldTestView.swift`: an unused preview/debug view (only referenced by its own SwiftUI preview; not part of any navigation path).

### AstraCore
- `AppCoordinator.swift`: `@MainActor` `ObservableObject` exposing `SessionState` (`.firstLaunchSetup` / `.locked` / `.unlocked`); orchestrates first-launch routing, unlock/biometric unlock, in-context secure-note re-authentication, passphrase change, immediate-lock handling (gated on active background operations), biometric enrollment refresh, and platform-event subscription.
- `Services/Security/KeyManager.swift`: passphrase lifecycle — PBKDF2-HMAC-SHA256 key derivation (100,000 iterations, 32-byte key, random 16-byte salt), in-memory-only key material (never persisted/restored from disk), rate limiting (lockout after 5 failed attempts within a 30s window, exponential backoff from 30s up to 1 hour), and `changePassphrase` (validates the current passphrase, rejects an identical new passphrase, re-derives a new key, and re-encrypts every secure note's payload inside one atomic transaction with rollback-safe pending-rotation tracking recovered on next launch).
- `Services/Crypto/EncryptionService.swift` + `PBKDF2.swift`: AES-GCM encrypt/decrypt boundary and PBKDF2 key derivation primitives.
- `Services/SecurePayloadCodec.swift`: encodes/decodes the `{title, content}` plaintext bundle that gets encrypted for secure notes.
- `Services/SubjectService.swift`: subject CRUD — enforces non-empty, unique names; `delete` ungroups the subject's notes rather than deleting them; `rename` is validated and exposed via a Rename control in `NotesWorkspaceView`.
- `Services/NoteService.swift`: note CRUD orchestration — routes save/load through plaintext or encrypted payload paths based on `secureModeEnabled`/`isSecure`; manages secure-title-alias normalization (default "Locked Note"); owns attachment add/list/delete (`addImageAttachment`, `addVoiceAttachment`, `listAttachments`, `deleteAttachment` — the last removes the DB record and best-effort deletes the underlying file).
- `Services/NoteSearchService.swift`: simple in-memory substring search over `NoteRepository.fetchAllActive()` — matches normal notes by `plainTitle` and secure notes by `secureTitleAlias` only; `clearSecureCacheOnLock`/`secureCacheCount` are intentional no-ops because there is no decrypted-title cache to clear.
- `Services/ProtectedTrashService.swift`: move/restore/permanent-delete orchestration — `listTrashItems` builds `TrashItemView`s (including each secure note's real `secureTitleAlias` for display); `restore` requires active key material for secure notes (`restoreRequiresUnlockedSession`); `secureTitlePreviewMessage` returns a fixed "locked" explanation for secure items and the plain title otherwise.
- `Services/SettingsService.swift`: thin validation/update wrapper over `SettingsRepository` for `pluginsEnabled` and `biometricUnlockEnabled`; the settings model is intentionally scoped to these two fields, with no telemetry opt-in or lock-timeout settings.
- `Services/ExportImportService.swift`: encrypted archive export/import — see Section 5.11.
- `Services/PluginService.swift`: manifest validation, install/remove/list/enable-disable, and timeout-guarded action execution through a registered handler map (`registerHandler`/`execute`). `listInstalled`/`setEnabled`/`install`/`remove` are reachable from the UI; `registerHandler`/`execute` are service-layer-only surfaces with no UI entry point (see 5.6).
- `Models/CoreModels.swift`: `EncryptedPayload`, `KeyMaterial`, `Attachment`/`AttachmentType`, `NoteDraft`, `NoteView`, `NoteSummary`, `Subject`, `AppSettings`, `PluginManifest`/`InstalledPlugin`/`PluginActionRequest`/`PluginActionResult`, `ImportConflictResolution`/`ImportResult`.

### AstraData
- `Database/DatabaseProvider.swift`: in-process actor-backed transactional store (`read`/`transaction`) over a single `DatabaseState` value; optionally persists a JSON snapshot to `~/Library/Application Support/AstraNotes/database-state.json` after every successful mutation, and reloads it on init.
- `Models/PersistenceModels.swift`: `StoredEncryptedPayload`, `StoredNoteRecord`, `StoredAttachmentRecord`, `StoredSubjectRecord`, `StoredSettingsRecord`, `StoredTrashRecord`, `StoredCredentialState`/`StoredCredentialRotationState`, `StoredPluginMetadataRecord`/`StoredPluginBundleRecord`, and the aggregate `DatabaseState`.
- `Repositories/`: `NoteRepository`, `SubjectRepository`, `AttachmentRepository` (incl. `fetch(id:)`/`remove(id:)` for attachment deletion), `ProtectedTrashRepository`, `SettingsRepository`, `PluginMetadataRepository`, `PluginBundleRepository` — each a thin actor wrapper translating between `DatabaseState` collections and typed protocol APIs.

### AstraPlatform
- `LocalAuthService.swift`: `SystemLocalAuthService` — real Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) + `LocalAuthentication` (Touch ID/Face ID) integration for biometric enrollment/authentication/clear.
- `TimeProvider.swift`: `SystemTimeProvider` (UTC clock abstraction used throughout for testability).
- `AuditLogger.swift`: `AuditLogging`/in-memory implementation — sanitized, non-sensitive event logging (e.g. `unlock_failed`, `unlock_lockout`, `passphrase_rotated`, `plugin_installed`, `export_completed`).
- `PlatformIntegration.swift`: `PlatformEvent` enum + `InMemoryPlatformIntegration`, a pub/sub stream that `AppCoordinator` subscribes to for background/sleep/wake-driven lock behavior (see 5.9). The design defines `publish` as the integration point for a platform-event source; this build does not connect a producer to it, so the subscription is present without an active emitter.

## 4. Runtime Boundaries
- UI never performs encryption or direct database writes; it calls into actor-isolated services via injected async closures.
- Core services never depend on SwiftUI; `AppCoordinator` is the only `@MainActor`/`ObservableObject` type, and it depends only on `AstraPlatform`/`AstraCore` types.
- Repositories store standard notes as plaintext fields and secure notes as `securePayload` ciphertext only (`plainTitle`/`plainContent` are nil for secure notes); `NoteService` decides the storage path from `secureModeEnabled`/`isSecure`.
- `KeyManager` is the single source of truth for in-memory key material; it is never persisted to or restored from disk — every relaunch with an existing passphrase starts in `.locked`, requiring fresh derivation.
- Secure note title search never touches decrypted titles; `NoteSearchService` matches secure notes by their persisted, non-sensitive `secureTitleAlias` only.
- Plugins reach the app only through `PluginService`'s manifest/action surface; they never touch repositories directly. Execution is timeout-guarded, and failures are logged and surfaced as typed errors without crashing note flows; the UI does not provide an entry point for triggering execution (see 5.6).

## 4.1 Confidentiality Enforcement (Data Flow Assertions)
- **Disk persistence**: Decrypted secure note content is never written to disk. `StoredNoteRecord` persists only `securePayload` (ciphertext + nonce + tag + salt) and the non-sensitive `secureTitleAlias` for secure notes. Only `EncryptionService`, driven by `NoteService`/`KeyManager`, performs decrypt operations, and results are held only transiently in `@State` for UI display.
- **Logging**: `AuditLogger` records only event names and small, non-content metadata (counts, durations, plugin/note IDs); note titles, content, and passphrases are never logged.
- **Caching**: `NoteSearchService` holds no decrypted-title cache — it re-reads `secureTitleAlias` from storage on every search and its "clear on lock" hook is a documented no-op because there is nothing to clear.
- **Exports**: `ExportImportService.exportArchive()` strips runtime-only/sensitive fields (credentials, pending rotation state, clock-protection fields) from the snapshot, then encrypts the entire JSON snapshot with the user's key material before wrapping it in the archive envelope — the exported file contains no plaintext secure-note content.
- **UI display**: Decrypted secure content lives only in `@State` on `NotesWorkspaceView` while the note is open; selecting away or beginning a new draft resets those fields (`clearEditorForNewNote`/`beginNewDraft`).
- **Attachments — caveat**: Attachment *files* are stored as plain files on disk. macOS provides no per-file Data Protection API equivalent to iOS's, so there is no OS-level per-file protection for the app to apply; the confidentiality guarantee for attachments rests on the host's disk encryption (e.g. FileVault), not on app-level encryption of the attachment bytes.
- **Plugins**: Plugin actions reach the app only through `PluginService.execute`, gated on global enablement, per-plugin enablement, and a registered handler. The UI provides no entry point for triggering execution (see 5.6) — exposing one would require an in-process plugin runtime, which is outside this architecture's scope.

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
2. The design includes no time-based secure-note expiration, sweeping, launch-time checkpoint, or expiry-notification behavior. Secure notes carry no expiration metadata, and the architecture defines no policy service, sweep mechanism, or notification path for this concern.
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
1. **What the UI does**: `PluginStoreView` (embedded in Settings) lists installed plugins (`listInstalled`), lets the user toggle each one's enabled state (`setEnabled`), **install a new plugin**, and **remove an installed plugin**:
   - **Install Plugin…** opens a sheet (`InstallPluginSheet`) with text fields for Plugin ID / Display Name / Version / comma-separated Capabilities and an `NSOpenPanel` "Choose Bundle File…" control that reads the chosen file's raw bytes as the bundle payload. Submitting calls `PluginService.install(manifest:bundleData:)`, maps `invalidManifest`/`invalidBundle`/`pluginAlreadyInstalled` to friendly messages, and refreshes the list on success.
   - Each plugin row has a trash-icon **Remove** button gated by a confirmation alert ("Remove Plugin? ... This cannot be undone."), calling `PluginService.remove(pluginId:)` and refreshing the list.
2. **Execution surface stops at the service layer**: `registerHandler`/`execute` define global- and per-plugin-enablement gating, a registered async-handler contract, and a 2-second timeout race via `withThrowingTaskGroup`. The architecture deliberately does not extend this surface into the UI: `registerHandler` takes an in-process Swift closure, and the design includes no plugin runtime that loads code from an installed bundle to produce one. Surfacing "execute" in the UI would require designing and building an entire plugin runtime (loading, sandboxing, running bundle code) — a substantially larger undertaking than adding a control, and one this architecture does not take on.

### 5.7 Subject Group Management
1. Creating a subject: the user enters a name in the left-panel "New subject" field; `SubjectService.create` trims, validates non-empty/unique, and persists via `SubjectRepository`.
2. Deleting a subject: if the group still has notes, a confirmation alert ("Delete Subject?") warns that its notes will be ungrouped; `SubjectService.delete` always ungroups the notes (`subjectId = nil`) rather than deleting them, then removes the subject record.
3. Renaming: each real subject's group header has a **Rename** button that opens a confirmation alert (`pendingSubjectRename`) containing a `TextField` (`renameSubjectText`) pre-filled with the current name; submitting calls `SubjectService.rename(id:newName:)` via `renameSubjectAction`, which validates non-empty/unique names (errors mapped to friendly messages through `mapError`), shows a toast on success, and refreshes the workspace.

### 5.8 Title Search
1. The user types into the search field in the left panel's header and presses Enter or **Search**.
2. `NoteSearchService.searchTitle` does a simple case-insensitive substring match: normal notes by `plainTitle`, secure notes by `secureTitleAlias`. It reads fresh from `NoteRepository.fetchAllActive()` each time — there is no cache to invalidate, which is why `clearSecureCacheOnLock`/`secureCacheCount` are no-ops.
3. **Reset** clears the query and search results and reloads the full workspace list.

### 5.9 Lock / Key-Clearing Behavior
1. `AppCoordinator` exposes `lockNow()` (clears in-memory key material and calls the search service's no-op cache clear) and `handleImmediateLockEvent()` (defers the lock until any in-flight background operation — tracked via `beginBackgroundOperation`/`endBackgroundOperation` — completes, then calls `lockNow()`).
2. `bind(platformIntegration:)` subscribes to `PlatformEvent`s (`appDidBackground`/`osWillSleep` → immediate lock; `userInteraction`/`appDidForeground`/`osDidWake` → record interaction). `InMemoryPlatformIntegration.publish` is the integration point where a platform-event source would feed this subscription; this design does not connect a producer to it, so the subscription is defined without an active emitter. The design likewise omits any inactivity-timeout mechanism or associated setting.
3. Within a session, in-memory key material is cleared only via `lockNow`/`handleImmediateLockEvent`/`publish` — paths that depend on the dormant platform-event producer described in point 2. The lock boundary every user relies on in practice is the relaunch path from 5.1.2: every relaunch starts in `.locked` and requires the passphrase to be re-derived.
4. Whichever way the key is cleared, the workspace remains usable for normal notes; any subsequent secure-note operation re-triggers the in-context authentication flow from 5.1.3.

### 5.10 Passphrase Change / Key Rotation
1. The user enters current/new/confirm passphrases in the Settings "Change Passphrase" section; client-side validation requires the new passphrase to be non-empty and match its confirmation.
2. `AppCoordinator.changePassphrase` → `KeyManager.changePassphrase`: re-derives the old key from the current passphrase and verifies it, derives a candidate new key and rejects it if identical to the old one (`KeyManagerError.identicalPassphrase`), then opens a single database transaction that re-checks the stored credentials, **re-encrypts every secure note's `securePayload`** under the new key, and writes the new `StoredCredentialState` — all inside one atomic commit, with a `pendingCredentialRotation` marker that `recoverPendingRotationIfNeeded` clears (and logs as recovered) on the next unlock if the process was interrupted mid-rotation.
3. **Attachments are not re-encrypted** during rotation, consistent with attachment files not being encrypted at the app layer (see 4.1).
4. On success, in-memory key material is replaced and (if biometrics are enabled) re-enrolled; `SettingsView` shows a success message and clears the fields. Errors map to friendly text for `invalidPassphrase`, `identicalPassphrase`, `passphraseNotInitialized`, and `migrationUnavailable`.

### 5.11 Backup Export / Import
1. **UI**: Settings → "Backup & Restore" → **Export Backup…** / **Import Backup…**, each driving an `NSSavePanel`/`NSOpenPanel`.
2. **Export**: `ExportImportService.exportArchive()` requires unlocked key material, snapshots the database, strips sensitive/runtime-only fields (credentials, pending rotation, clock-protection state), JSON-encodes the snapshot, encrypts the whole thing with the user's key (AES-GCM), and wraps it with a schema version into an `ExportEnvelope`. `SettingsView` writes the resulting `Data` atomically to the chosen file.
3. **Import**: also requires unlocked key material. The service decodes the envelope, rejects archives with a schema version newer than the local one (`unsupportedSchemaVersion`), decrypts and decodes the inner snapshot, and merges it into the live database inside a single atomic transaction. With the default `regenerateIncomingIdentifiers` resolution, any colliding subject/note/attachment/trash/plugin IDs are remapped to fresh UUIDs (with all cross-references rewritten consistently) so imported data merges alongside existing data without overwriting it; a `.reject` mode is also available that aborts on any ID collision.
4. `SettingsView` reports the result (`importedNotes`/`importedSubjects`/`importedPlugins` counts) or maps `keyMaterialUnavailable` / `invalidArchive` / `unsupportedSchemaVersion` / `importConflict` to user-facing messages.

## 6. Data Contracts (as persisted / passed across boundaries)
- **Subject** (`Subject` / `StoredSubjectRecord`): `id`, `name`, `displayOrder`, `createdAt`.
- **Note** (`StoredNoteRecord`): `id`, `subjectId?`, `isSecure`, `plainTitle?`, `plainContent?`, `securePayload?` (`StoredEncryptedPayload`: ciphertext/nonce/tag/salt), `secureTitleAlias?`, `createdAt`, `updatedAt`. For normal notes `plainTitle`/`plainContent` are populated and `securePayload`/`secureTitleAlias` are nil; for secure notes the reverse.
- **NoteDraft** (UI → service): `id?`, `title`, `content`, `subjectId?`, `secureModeEnabled`, `secureTitleAlias?`. There is no expiration field; this design does not model note expiration.
- **Attachment** (`Attachment` / `StoredAttachmentRecord`): `id`, `noteId`, `type` (`.image` | `.recording`), `storagePath`, `byteSize`, `isEncrypted` (records the owning note's secure-mode *intent* at creation time — not real at-rest file encryption), `createdAt`.
- **Trash record** (`StoredTrashRecord` / `TrashItemView`): `id`/`trashId`, `sourceNote` (full `StoredNoteRecord`, including `secureTitleAlias`), `attachments`, `deletedAt`; `TrashItemView` additionally exposes `isSecure`, `displayTitle?` (normal notes only), `secureTitleAlias?` (secure notes only), and `lockBadgeVisible`.
- **Settings** (`AppSettings` / `StoredSettingsRecord`): `pluginsEnabled`, `biometricUnlockEnabled`. The model carries no telemetry opt-in or lock-timeout fields.
- **Credentials** (`StoredCredentialState`): `salt`, `hash`, `iterations`; plus transient `StoredCredentialRotationState(startedAt:)` while a passphrase change is in flight.
- **Plugin manifest** (`PluginManifest`): `pluginId`, `displayName`, `version`, `capabilities`.
- **Installed plugin** (`InstalledPlugin` / `StoredPluginMetadataRecord`): `pluginId`, `displayName`, `version`, `capabilities`, `isEnabled`, `installedAt`; bundle bytes live separately in `StoredPluginBundleRecord(pluginId:bundleData:)`.
- **Import result** (`ImportResult`): `importedNotes`, `importedSubjects`, `importedPlugins`; resolution strategy is `ImportConflictResolution.reject` or `.regenerateIncomingIdentifiers`.
- **Database snapshot** (`DatabaseState`): `schemaVersion`, `notes`, `attachments`, `subjects`, `trash`, `pluginMetadata`, `pluginBundles`, `settings`, plus runtime-only `credentials?`, `pendingCredentialRotation?`, `lastKnownUTC?`, `rollbackGuardUntilUTC?` (the last four are stripped before export/import merge).
