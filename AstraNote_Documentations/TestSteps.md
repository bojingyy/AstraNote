# AstraNote Comprehensive Test Plan

## Organization
Test cases are organized by epic/feature with positive, negative, and edge-case coverage, and each case carries its requirement reference. The plan covers all 83 requirements defined in Requirement.md (68 FR + 15 NFR).

---

## 1. First-Launch Initialization and Passphrase Creation (FR1.1)

**Test 1.1**: First launch → `UnlockView` appears in passphrase-creation mode (not entry mode).
**Test 1.2**: Verify all note operations are blocked until a passphrase is created and confirmed (no sidebar, editor, or settings access).
**Test 1.3**: Create and confirm a valid passphrase → workspace loads.
**Test 1.4**: Submit an empty or whitespace-only passphrase → rejected with a clear message.
**Test 1.5**: Passphrase and confirmation mismatch → re-entry is prompted.
**Test 1.6**: Confirm the passphrase is never written to disk, logs, or memory dumps in plaintext (NFR3.1).

---

## 2. Authentication and Step-Up Access (FR1.2-1.5, FR3.8, NFR1.1-1.3, NFR6.1-6.3)

### 2.1 Workspace Access on Relaunch (FR1.2)
**Test 2.1**: Relaunch with an existing passphrase → the workspace opens directly with no whole-app unlock screen.
**Test 2.2**: Normal notes are immediately readable and editable without any authentication step.

### 2.2 Step-Up Authentication for Secure Notes (FR3.8)
**Test 2.3**: Open a secure note → the authentication prompt appears before any decrypted content is shown.
**Test 2.4**: Save a new or edited secure note while the key is unavailable → the authentication prompt appears at save time.
**Test 2.5**: Add an attachment to a secure note while the key is unavailable → the authentication prompt appears before the write proceeds.
**Test 2.6**: Authenticate successfully from any of the above prompts → the triggering action (open/save/attach) resumes automatically without repeating it.
**Test 2.7**: Submit an incorrect passphrase at the prompt → rejected with an error; the prompt remains open for retry.

### 2.3 Authentication Prompt and Biometric Path (FR1.3-1.5)
**Test 2.8**: After at least one successful authentication, the user can enable biometric authentication from Settings.
**Test 2.9**: With biometrics enabled and enrolled, the prompt co-presents the passphrase field and a biometric action together.
**Test 2.10**: Decline or fail the biometric action → the passphrase field in the same prompt remains fully usable, with no separate fallback screen.
**Test 2.11**: Biometric hardware or enrollment becomes unavailable → a descriptive error (`biometricUnavailable` / `biometricUnlockDisabled`) is shown and the passphrase path is unaffected.

### 2.4 Rate Limiting and Audit Logging (NFR6.1-6.3)
**Test 2.12**: 5 failed attempts within 30 seconds → a 30-second lockout is enforced.
**Test 2.13**: A subsequent breach after the first lockout → the lockout doubles to 60 seconds.
**Test 2.14**: Repeated breaches → lockout progression caps at 60 minutes.
**Test 2.15**: Each lockout event is written to the audit log with a timestamp and reason.
**Test 2.16**: Authentication-failure audit entries contain only event names and small metadata — never the passphrase or note content.

### 2.5 Authentication Performance (NFR1.1-1.3)
**Test 2.17**: Passphrase verification and key derivation complete in approximately 1 second on target hardware (Apple Silicon M-series or Intel i5/i7 6th gen+, 8 GB RAM).
**Test 2.18**: Repeat the measurement against 100-, 1,000-, and 10,000-note databases → latency is statistically constant across all three; there is no whole-app unlock step that scales with note count.
**Test 2.19**: Confirm the measurement protocol excludes manual passphrase-typing time.

---

## 3. Normal Note Lifecycle (FR2.1-2.5, NFR5.1)

### 3.1 Create and Save
**Test 3.1**: Create a note with text content → it appears in the active list (FR2.1).
**Test 3.2**: Inspect storage → the note is persisted as plain text with no encryption applied (FR2.2).
**Test 3.3**: Verify the note carries a stable unique identifier immediately after creation (FR2.3).
**Test 3.4**: Induce a write failure during save → the transaction rolls back and the previous state is preserved (FR2.4, NFR5.1).
**Test 3.5**: Save a note with a large body of text → the write completes atomically.
**Test 3.6**: Issue several rapid saves in succession → every write remains atomic (FR2.4).

### 3.2 Edit and Update
**Test 3.7**: Edit note content repeatedly → the identifier remains stable across every edit (FR2.3).
**Test 3.8**: Edit and save multiple times, including an induced failure → all writes remain atomic and the previous state is recoverable (FR2.4).

### 3.3 Delete and Trash
**Test 3.9**: Delete a normal note → it and its attachments move to protected trash in a single transaction (FR2.5, NFR5.1).
**Test 3.10**: Restore a normal note from trash → it returns to the active list with identical content.
**Test 3.11**: Permanently delete a normal note → the record is removed.
**Test 3.12**: Induce a failure during the move-to-trash transaction → the note remains in the active list, unchanged (FR2.5).

---

## 4. Secure Note Lifecycle and Encryption (FR3.1-3.8, NFR3.1-3.2, NFR4.1-4.2)

### 4.1 Enable Secure Mode and Display Alias
**Test 4.1**: Toggle secure mode from the editor toolbar → secure controls appear with no expiration or scheduling fields (FR3.1, FR3.2).
**Test 4.2**: Assign a custom display alias to a secure note (e.g., "Finance Vault") and save (FR12.3).
**Test 4.3**: Save a secure note → it is encrypted immediately, with no time-based validation performed (FR3.2, FR3.3).

### 4.2 Encryption and Storage
**Test 4.4**: Inspect the persisted record for a saved secure note → it contains only ciphertext, nonce, authentication tag, and salt — never plaintext title or content (FR3.3).
**Test 4.5**: Verify the secure note's identifier remains stable across edits (FR3.4).
**Test 4.6**: Induce a write failure during a secure-note save → the transaction rolls back and the previous ciphertext is preserved (FR3.5, NFR5.1).

### 4.3 Decryption Failure and Authenticated-Encryption Integrity
**Test 4.7**: Corrupt a stored secure note's ciphertext → opening it fails, a clear error is shown, and the stored record is left unchanged (FR3.6, NFR4.2).
**Test 4.8**: Mutate the stored authentication tag or nonce → AES-GCM verification fails explicitly rather than producing corrupted plaintext (NFR4.1).
**Test 4.9**: Attempt to decrypt with an incorrect key → verification fails and the record remains intact (NFR4.1, NFR4.2).

### 4.4 Decrypted-Content Memory Lifecycle
**Test 4.10**: Open a secure note, then navigate away from it → its decrypted content is cleared from memory (NFR3.2).
**Test 4.11**: Inspect logs, caches, and exports after working with secure notes → no decrypted content appears in any of them (NFR3.1).

### 4.5 Secure Note Deletion
**Test 4.12**: Delete a secure note → the encrypted record and its attachments move to trash in a single transaction (FR3.7, NFR5.1).

---

## 5. Secure Note Retention (FR4.1-4.2)

**Test 5.1**: Create a secure note and leave it in the active list → it remains there indefinitely with no automatic move to trash (FR4.1).
**Test 5.2**: Close and relaunch the app → the secure note remains in the active list (FR4.1).
**Test 5.3**: Confirm the absence of any expiration, sweeping, launch-time-checkpoint, or expiry-notification mechanism for secure notes (FR4.2).
**Test 5.4**: Roll the device clock forward and backward → secure-note availability is unaffected, since no time-based retention policy exists to react to it (FR4.2).

---

## 6. Protected Trash Management (FR5.1-5.7)

### 6.1 Trash Display and Lock Semantics
**Test 6.1**: Delete a normal note → trash shows its title, deletion time, and Restore/Permanently-Delete actions (FR5.2).
**Test 6.2**: Delete a secure note → trash shows its deletion time and a lock badge populated from its display alias, with no decrypted title visible (FR5.2, FR5.3).
**Test 6.3**: Request title details for a locked trash item → a fixed "locked, cannot be previewed until restored and unlocked" message is shown, with no decryption attempted (FR5.3).

### 6.2 Restore Flow
**Test 6.4**: Restore a normal note → it returns to the active list with its original content (FR5.4).
**Test 6.5**: Restore a secure note while the session is unlocked → it returns to the active list and decrypts correctly (FR5.4, FR3.8).
**Test 6.6**: Attempt to restore a secure note while the session is locked → the operation is blocked with a clear message (FR5.5).

### 6.3 Permanent Delete
**Test 6.7**: Permanently delete a normal note → the record is removed from storage (FR5.6).
**Test 6.8**: Permanently delete a secure note → its ciphertext and all linked attachment files are wiped beyond recovery (FR5.7).
**Test 6.9**: Confirm permanent deletion is not recoverable through any restore path.

---

## 7. Voice Capture (FR6.1-6.3)

**Test 7.1**: Trigger the voice-capture action in the editor's top bar → recording begins via the system microphone (FR6.1).
**Test 7.2**: Complete a recording → the audio file is written to app-container storage only after recording finishes and before it is linked to the note (FR6.2).
**Test 7.3**: Inspect the persisted attachment record → it carries an `isEncrypted` flag reflecting the owning note's secure-mode status at creation time (FR6.2).
**Test 7.4**: Confirm the audio bytes themselves are stored as a plain file regardless of the owning note's secure-mode status — the flag is bookkeeping metadata, and confidentiality at rest depends on the host's disk-level encryption (FR6.2).
**Test 7.5**: Record audio exceeding 50 MB → rejected before storage with a message stating the size limit (FR6.3).
**Test 7.6**: Boundary check — a recording at exactly 50 MB is accepted (FR6.3).

---

## 8. Image Attachment (FR13.1-13.3)

**Test 8.1**: Trigger the attach-image action → a local file picker appears, with no camera-capture or remote-URL option (FR13.1).
**Test 8.2**: Select a local image file → it is written to app-container storage as a plain file, carrying the `isEncrypted` bookkeeping flag described in FR6.2 (FR13.2).
**Test 8.3**: Confirm image bytes are not separately encrypted at the app layer regardless of the owning note's security mode (FR13.2).
**Test 8.4**: Attach an image exceeding 20 MB → rejected before storage with a message stating the limit (FR13.3).
**Test 8.5**: Boundary check — an image at exactly 20 MB is accepted (FR13.3).
**Test 8.6**: Attach both an image and a voice recording to the same note → both link and persist correctly.
**Test 8.7**: Delete a note that has attachments → the note and its attachments move to trash together (FR2.5 / FR3.7).

---

## 9. Session Lock (FR7.1-7.4)

**Test 9.1**: Relaunch the app after it has been quit → the session begins locked, and the first secure-note operation triggers re-authentication (FR7.1).
**Test 9.2**: Confirm in-memory key material is never persisted to or restored from disk across a relaunch (FR7.1).
**Test 9.3**: Send the app to the background → the immediate-lock path clears in-memory key material right away (FR7.2).
**Test 9.4**: Trigger an OS sleep event → the same immediate-lock path fires (FR7.2).
**Test 9.5**: Generate user-interaction and foreground/wake events → they are recorded for observability and do not themselves trigger a lock (FR7.2).
**Test 9.6**: Start an export or passphrase rotation, then background the app or trigger sleep mid-operation → the lock is deferred until the operation finishes, then applied immediately (FR7.3).
**Test 9.7**: After a lock (by any trigger), confirm normal notes remain fully usable and any secure-note action re-triggers the step-up authentication flow from FR3.8 (FR7.4).
**Test 9.8**: Confirm the absence of an inactivity-timeout mechanism and of any draft-persistence-on-lock behavior — the lock boundary is anchored solely to relaunch and to background/sleep platform events (FR7.1-FR7.4).

---

## 10. Passphrase Change and Key Rotation (FR8.1-8.6, NFR5.1-5.2)

**Test 10.1**: Initiate a passphrase change from Settings while the session is unlocked (FR8.1).
**Test 10.2**: Complete the change → every secure note is re-encrypted under the new key and the new credentials are committed together, in a single atomic transaction (FR8.2, FR8.3).
**Test 10.3**: Confirm there is no observable intermediate state in which some secure notes are under the old key and others under the new one (FR8.3).
**Test 10.4**: Confirm normal notes and attachment files are untouched by the rotation (FR8.6).
**Test 10.5**: Force-terminate the app mid-rotation and relaunch → the database is left exactly as it was under the original credentials, with no partially re-encrypted records (FR8.4, NFR5.2).
**Test 10.6**: On the next unlock after an interrupted rotation, confirm any stale in-flight rotation marker is detected, cleared, and logged automatically, with no action required from the user (FR8.4, NFR5.2).
**Test 10.7**: Submit a new passphrase that derives an identical key to the current one → the change is rejected with a clear error, no re-encryption or write occurs, and the user is prompted to choose a different passphrase (FR8.5).

---

## 11. Export and Import (FR9.1-9.4, NFR5.1-5.2)

**Test 11.1**: Export from Settings → produces a single encrypted, schema-tagged archive containing all note records and required metadata, protected by the user's key material (FR9.1).
**Test 11.2**: Inspect the archive's pre-encryption snapshot → sensitive and runtime-only fields (credentials, in-flight rotation state, clock-protection bookkeeping) are stripped before encryption (FR9.1).
**Test 11.3**: Import an archive whose schema version is not newer than the local schema → it proceeds (FR9.2).
**Test 11.4**: Import an archive created by a newer app version → rejected with an error identifying the schema mismatch (FR9.2).
**Test 11.5**: Import an archive whose identifiers collide with existing local records under default settings → imported records receive fresh identifiers, cross-references are rewritten consistently, and existing data is untouched (FR9.3).
**Test 11.6**: Repeat with strict conflict-resolution mode enabled → the import is rejected outright on any identifier collision (FR9.3).
**Test 11.7**: Induce a failure partway through decoding, decryption, or merge → the entire import rolls back, the prior database state remains intact, and the user sees a descriptive error (FR9.4, NFR5.1, NFR5.2).

---

## 12. Title Search (FR12.1-12.5, NFR3.2)

**Test 12.1**: Type a query into the workspace's top-bar search field → the note list filters as the query changes (FR12.1).
**Test 12.2**: Search for a normal note's title → it is matched directly against its stored plaintext title (FR12.2).
**Test 12.3**: Search for a secure note by its display alias → it is matched against the persisted, non-sensitive `secureTitleAlias`, never against a decrypted title (FR12.3, FR12.4).
**Test 12.4**: Instrument the search path → confirm it never decrypts or holds decrypted title data in memory at any point (FR12.4, NFR3.2).
**Test 12.5**: Lock the session and repeat the same alias search → identical results are returned (FR12.5).
**Test 12.6**: Toggle between locked and unlocked states and repeat alias searches → results are identical in both states, confirming search availability is independent of lock state (FR12.5).

---

## 13. Subject Group Management (FR14.1-14.6)

### 13.1 Create Subject Group
**Test 13.1**: Use the sidebar's create action → a creation dialog appears (FR14.1).
**Test 13.2**: Enter a unique, non-empty name → the group is created and appears in the sidebar (FR14.1).
**Test 13.3**: Submit an empty name → rejected (FR14.1).
**Test 13.4**: Submit a name that duplicates an existing group → rejected (FR14.1).

### 13.2 Rename Subject Group
**Test 13.5**: Rename a group with a unique, non-empty name → committed (FR14.2).
**Test 13.6**: Attempt to rename to an empty or duplicate name → rejected (FR14.2).

### 13.3 Delete Subject Group
**Test 13.7**: Delete an empty group → removed without confirmation (FR14.3).
**Test 13.8**: Delete a group containing notes → a confirmation prompt appears; confirming deletes the group and leaves its notes ungrouped, while canceling leaves both the group and its assignments intact (FR14.3, FR14.4).

### 13.4 Assign and Move Notes
**Test 13.9**: Assign a note to a subject group → it appears under that group (FR14.5).
**Test 13.10**: Move a note from one group to another → it appears in the new group and disappears from the old one (FR14.5).
**Test 13.11**: Select "All Notes" → every note is shown regardless of group assignment (FR14.6).

---

## 14. Simple Plugin Support (FR11.1-11.7)

### 14.1 Installation and Validation
**Test 14.1**: Install a plugin from a local package via the file picker (FR11.1).
**Test 14.2**: Confirm the manifest is validated against `pluginId`, `displayName`, `version`, and `capabilities` before registration (FR11.2).
**Test 14.3**: Attempt to install a malformed manifest, an unreadable bundle, or a plugin ID that is already installed → each is rejected with a descriptive error (FR11.2).
**Test 14.4**: Inspect persisted plugin records → metadata includes plugin ID, display name, version, capabilities, enabled state, and install timestamp, with bundle bytes stored separately and keyed by plugin ID (FR11.7).

### 14.2 Lifecycle Management
**Test 14.5**: Enable, disable, and remove a plugin from the management UI, with a confirmation step required before removal (FR11.3).
**Test 14.6**: Toggle the global plugin switch off → all plugins stop running while their installed records remain intact (FR10.1).

### 14.3 Execution Surface (Service Layer)
**Test 14.7**: Invoke `execute` against a registered handler → global- and per-plugin-enablement checks are applied before the handler runs (FR11.5).
**Test 14.8**: Register a handler that fails, times out, or throws → a typed error is surfaced to the caller and the failure is audit-logged, without crashing the host or corrupting note data (FR11.6, NFR6.3).
**Test 14.9**: Confirm there is no UI control that triggers plugin execution in this release — the gated execution surface is reachable only at the service layer (FR11.5).
**Test 14.10**: Confirm plugins interact with notes only through the host API and never read or write repositories directly (FR11.4).

---

## 15. Settings and Notifications (FR10.1-10.3)

**Test 15.1**: Open Settings → exactly two configurable items are present: global plugin enablement and biometric-unlock enablement (FR10.1).
**Test 15.2**: Confirm there is no telemetry opt-in setting and no lock-timeout setting anywhere in Settings (FR10.1).
**Test 15.3**: Submit an invalid settings value → rejected with a user-visible message before commit (FR10.2).
**Test 15.4**: Trigger a success, warning, and error condition in the workspace → each appears as a transient pop-up notification that auto-dismisses after about five seconds (FR10.3).
**Test 15.5**: Confirm operation feedback is never rendered as inline text beneath the editor's input area (FR10.3).

---

## 16. Data Integrity and Reliability (NFR4.1-4.2, NFR5.1-5.2)

**Test 16.1**: Tamper with stored ciphertext, nonce, or authentication tag for a secure note → AES-GCM verification fails explicitly (NFR4.1).
**Test 16.2**: Confirm a verification failure surfaces a clear, user-visible error and leaves the stored record byte-for-byte unchanged (NFR4.2).
**Test 16.3**: Induce a failure mid-transaction during a note edit, a note deletion, a passphrase rotation, and a backup import → each rolls back to the prior `DatabaseState` with no partial writes observable (NFR5.1).
**Test 16.4**: Run the interrupted-rotation recovery scenario end to end → the database returns to a consistent state under the original credentials with the stale marker cleared and logged (NFR5.2).
**Test 16.5**: Run the interrupted-import recovery scenario end to end → the import rolls back completely and the user sees a descriptive error (NFR5.2).

---

## 17. Performance and Responsiveness (NFR1.1-1.3, NFR2.1-2.2)

**Test 17.1**: Authentication completes in approximately 1 second on Apple Silicon and Intel i5/i7 (6th gen+) reference hardware (NFR1.1).
**Test 17.2**: Authentication latency is statistically constant across 100-, 1,000-, and 10,000-note databases (NFR1.2).
**Test 17.3**: Manual passphrase-typing time is excluded from the measurement (NFR1.3).
**Test 17.4**: Trace concurrency during encryption, database writes, and plugin execution → none of them block the main UI thread (NFR2.1).
**Test 17.5**: Capture frame timing during note editing, encrypted saves, attachment handling, and plugin execution → 60 FPS is sustained (NFR2.2).

---

## 18. Confidentiality and Privacy Boundaries (NFR3.1-3.2, NFR6.3, NFR7.1)

**Test 18.1**: Inspect persisted secure-note records directly → only ciphertext, authentication tag, salt, and the display alias are present (NFR3.1).
**Test 18.2**: Inspect audit logs, caches, and export archives after a full feature pass → no decrypted content appears in any of them (NFR3.1).
**Test 18.3**: Open a secure note, navigate away, then lock the session → decrypted content is cleared from memory at each step (NFR3.2).
**Test 18.4**: Confirm the search path relies solely on `secureTitleAlias` and never holds decrypted titles, consistent with section 12 (NFR3.2).
**Test 18.5**: Inspect audit-log entries for authentication failures, rotation outcomes, plugin lifecycle events, and export/import completions → each contains an event name and small metadata only, never note content, titles, or passphrases (NFR6.3).
**Test 18.6**: Capture all outbound network and instrumentation activity during a full end-to-end feature pass (unlock, edit, attach, search, export, plugin install) → zero telemetry or analytics payloads are observed (NFR7.1).

---

## Test Execution Strategy
- **Automation**: authentication, note/subject CRUD, trash, search, export/import, passphrase rotation, and plugin install/execute flows.
- **Manual**: UI responsiveness spot checks, plugin failure-mode walkthroughs, attachment size-limit boundary checks, settings validation.
- **Performance**: representative Apple Silicon and Intel i5/i7 (6th gen+) hardware across 100-, 1,000-, and 10,000-note datasets.
- **Integration**: cross-feature flows that combine secure notes, attachments, session locking, search, and passphrase rotation.
- **Regression**: re-run authentication, CRUD, and core security flows after every change that touches `AstraCore` or `AstraData`.

**Metrics**: the documented code-coverage target is met for `AstraCore` and `AstraData` services, every NFR benchmark is achieved, no decrypted content is observed in logs/caches/exports, every ACID transaction path is validated under induced failure, and the telemetry negative assertion (NFR7.1) returns a clean result.
