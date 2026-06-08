# AstraNotes Requirement Set

## Functional Requirements

**FR1.1** [Authentication] On first launch, the app shall enter a dedicated first-launch initialization branch that presents a passphrase creation dialog before any note data is stored or any other feature is accessible. This initialization branch shall block all note operations until a passphrase is successfully created and confirmed.

**FR1.2** [Authentication] On subsequent launches, the app shall open the workspace without requiring a whole-app unlock screen; secure-note content access shall require authentication at the moment a secure-mode operation needs the encryption key.

**FR1.3** [Authentication] After initial passphrase setup, the user may optionally enable biometric authentication as an alternative to the passphrase for secure-note step-up authentication.

**FR1.4** [Authentication] The authentication prompt for secure-note access shall present passphrase entry as the always-available path and, when biometric unlock is enabled and enrolled, an additional biometric action in the same prompt. If biometric authentication is unavailable, declined, or fails, the user shall be able to complete authentication with the passphrase field already present, without leaving the prompt.

**FR1.5** [Authentication] If biometric hardware or enrollment becomes unavailable after being enabled, biometric authentication attempts shall fail with a descriptive error (`biometricUnavailable` / `biometricUnlockDisabled`) while leaving the passphrase path in the same prompt fully usable.

**FR2.1** [Normal Note Lifecycle] The user shall be able to create, edit, and delete notes containing text; image and recording attachments are optional.

**FR2.2** [Normal Note Lifecycle] Normal notes shall be stored as plain text with no encryption applied.

**FR2.3** [Normal Note Lifecycle] Each note shall have a stable unique identifier preserved across edits.

**FR2.4** [Normal Note Lifecycle] All note writes shall be atomic: a failed write shall roll back and leave the previous record unchanged.

**FR2.5** [Normal Note Lifecycle] Deleting a normal note shall move it and its attachments to protected trash in a single ACID transaction; if the move fails, the note record shall remain intact.

**FR3.1** [Secure Note Lifecycle] The user shall be able to opt any note into secure mode via the secure toggle in the editor's toolbar.

**FR3.2** [Secure Note Lifecycle] Enabling secure mode shall not require any time-based policy fields; the note is protected immediately when saved.

**FR3.3** [Secure Note Lifecycle] When a secure note is saved, the title and content shall be encrypted on-device before any write to storage. Storage shall contain only ciphertext, nonce, tag, and salt — never plaintext title or content.

**FR3.4** [Secure Note Lifecycle] Each secure note shall retain its stable unique identifier across edits.

**FR3.5** [Secure Note Lifecycle] All secure note writes shall be atomic: a failed write shall roll back and leave the previous ciphertext unchanged.

**FR3.6** [Secure Note Lifecycle] If decryption of a secure note fails due to invalid ciphertext or authentication data, the stored record shall be preserved and a user-visible error shall be shown.

**FR3.7** [Secure Note Lifecycle] Deleting a secure note shall move the encrypted record and its attachments to protected trash in a single ACID transaction.

**FR3.8** [Secure Note Lifecycle] Opening a secure note, saving a new or changed secure note, or continuing a secure-note attachment operation shall require step-up authentication at the moment the encryption key is needed: the user must provide either the master passphrase or biometric authentication before decrypted content is shown or written. On successful authentication, the action that triggered the prompt shall resume automatically.

**FR4.1** [Secure Note Retention] Secure notes shall remain in the active note list until the user deletes them.

**FR4.2** [Secure Note Retention] Secure-note save and load flows shall preserve the encrypted record without any automatic time-based move to protected trash; the system shall not implement expiration, sweeping, launch-time checkpoints, or expiry notifications for secure notes.

**FR5.1** [Protected Trash] All deleted notes (normal and secure) shall be moved to protected trash, not deleted immediately.

**FR5.2** [Protected Trash] The trash view shall display all trashed items with the following semantics: (a) normal notes shall show title and deletion time; (b) secure notes shall show deletion time and a lock badge; (c) secure notes shall NOT show a readable title, only the lock badge, until restored.

**FR5.3** [Protected Trash] Secure notes in trash shall display with a lock badge as the primary visual indicator, populated from the note's persisted display alias rather than its encrypted title. If the user requests title details for a locked item, the app shall display a fixed message indicating the note is locked and cannot be previewed until restored and unlocked, without attempting any decryption.

**FR5.4** [Protected Trash] The user shall be able to restore any trashed note back to the active note list.

**FR5.5** [Protected Trash] Restoring a secure note from trash shall require an active unlocked session (in-memory key material present); the app shall block the restore and present a clear message if the session is locked.

**FR5.6** [Protected Trash] The user shall be able to permanently delete any trashed note.

**FR5.7** [Protected Trash] Permanently deleting a secure note shall wipe its ciphertext and all linked attachment files with no recovery path.

**FR6.1** [Voice Capture] The editor's top bar shall provide a voice capture action that records audio via the system microphone (subject to permission) and attaches the result to the current note.

**FR6.2** [Voice Capture] Recorded audio shall be written to the app's container storage only after recording completes and before the attachment is linked to the note. The persisted attachment record shall carry an `isEncrypted` flag reflecting the owning note's secure-mode status at creation time; this flag is bookkeeping metadata and does not itself encrypt the audio bytes — attachment files are written as plain files in app storage for both normal and secure notes, and their confidentiality at rest depends on the host's disk-level encryption (e.g., FileVault) rather than on app-level per-file encryption.

**FR6.3** [Voice Capture] Recorded audio exceeding 50 MB shall be rejected before storage, with a message stating the size limit.

**FR13.1** [Image Attachment] The editor shall provide an attach-image action to select and attach a local image file from the computer's file system to a note; no camera capture or remote URL sources are supported.

**FR13.2** [Image Attachment] Attached images shall be written to the app's container storage as plain files, carrying the same `isEncrypted` bookkeeping flag and the same disk-level confidentiality model described in FR6.2 — image bytes are not separately encrypted at the app layer, regardless of the owning note's security mode.

**FR13.3** [Image Attachment] Images exceeding 20 MB shall be rejected before storage, with a message stating the limit.

**FR7.1** [Session Lock] Every app launch after initial setup shall begin in a locked state: in-memory key material shall never be persisted to or restored from disk, so each relaunch requires the passphrase to be re-derived (or the key recovered via biometrics) before any secure-note operation can proceed. This relaunch boundary is the lock guarantee every user session is anchored to.

**FR7.2** [Session Lock] The app shall define an immediate-lock path that clears in-memory key material in response to background and sleep platform events (app entering the background, OS preparing to sleep); user-interaction and foreground/wake events shall be recorded for observability without triggering a lock.

**FR7.3** [Session Lock] Background operations such as export or passphrase rotation shall be tracked as in-flight; an immediate-lock trigger that occurs while such an operation is active shall be deferred until the operation completes, and then applied.

**FR7.4** [Session Lock] However triggered, locking shall clear in-memory key material before any further secure-note operation is permitted. The workspace shall remain fully usable for normal notes after a lock; any subsequent secure-note operation shall re-trigger the step-up authentication flow described in FR3.8.

**FR8.1** [Passphrase Change and Key Rotation] The user shall be able to change the master passphrase at any time while unlocked.

**FR8.2** [Passphrase Change and Key Rotation] Changing the passphrase shall re-encrypt every secure note's payload using a key derived from the new passphrase.

**FR8.3** [Passphrase Change and Key Rotation] Key rotation shall be performed as a single atomic transaction: re-encrypting every secure note and committing the new credentials happen together, or neither happens. There is no intermediate, persisted state in which some records are under the old key and others under the new one.

**FR8.4** [Passphrase Change and Key Rotation] If the rotation transaction does not complete — for example, the app terminates mid-rotation — the atomic-transaction guarantee ensures the database is left exactly as it was under the original credentials, with no partially re-encrypted records. On the next unlock, the app shall detect and clear any stale in-flight rotation marker and log the recovery; the user is not required to take any action to reach a consistent state.

**FR8.5** [Passphrase Change and Key Rotation] If the new passphrase derives an identical key to the existing one, the app shall reject the change with a user-visible error stating that the new passphrase produces the same key as the current one; the user shall be prompted to choose a different passphrase, and no re-encryption or storage write shall be performed.

**FR8.6** [Passphrase Change and Key Rotation] Normal notes are unaffected by passphrase change. Attachment files are likewise not re-encrypted during rotation, consistent with FR6.2/FR13.2 — they were never encrypted at the app layer in the first place.

**FR9.1** [Export and Import] Export shall produce an encrypted archive containing all note records and required metadata, tagged with the current schema version and protected by the user's key material. Runtime-only and sensitive fields (credentials, in-flight rotation state, clock-protection bookkeeping) shall be stripped from the snapshot before encryption.

**FR9.2** [Export and Import] Import shall accept only archives whose schema version is not newer than the local schema version; archives created by a newer app version shall be rejected with an error identifying the mismatch.

**FR9.3** [Export and Import] If an imported archive contains subject, note, attachment, trash, or plugin identifiers that conflict with existing local records, the default resolution shall assign fresh unique identifiers to the imported records (rewriting all cross-references consistently) so imported data merges alongside existing data without overwriting it. A stricter mode that rejects the import outright on any identifier collision shall also be available.

**FR9.4** [Export and Import] Import shall be performed inside a single atomic transaction: any failure during decoding, decryption, or merge shall roll back the entire operation with no partial state committed, leaving the prior database state intact, and the user shall be shown a descriptive error.

**FR10.1** [Settings] The app shall allow the user to configure exactly two settings: a global plugin enable/disable toggle (disabling it prevents all plugins from running without removing installed plugin records) and biometric-unlock enablement. The settings model intentionally excludes telemetry opt-in and lock-timeout options, as neither concept exists in this design.

**FR10.2** [Settings] All settings changes shall be validated before commit; invalid values shall be rejected with a user-visible message.

**FR10.3** [Notification Presentation] User-facing operation feedback in the workspace (success, warning, error) shall be presented as transient pop-up notifications that auto-dismiss after about 5 seconds; inline message text under the editor input area shall not be used for this feedback.

**FR11.1** [Simple Plugin Support] The app shall allow the user to install a plugin from a local package file, supplying the plugin's identity fields and the bundle's raw bytes through a file picker.

**FR11.2** [Simple Plugin Support] On installation, the app shall validate the plugin manifest's `pluginId`, `displayName`, `version`, and `capabilities`, and shall reject manifests that fail validation, bundles that cannot be read, and plugin IDs that are already installed — each with a descriptive error — before the plugin is registered.

**FR11.3** [Simple Plugin Support] The app shall allow the user to enable, disable, install, and remove plugins from the plugin management UI, with confirmation required before removal.

**FR11.4** [Simple Plugin Support] Plugins shall run only through the host API exposed by the plugin service; plugins shall never read or write repositories directly.

**FR11.5** [Simple Plugin Support] The plugin host shall provide a gated action-execution surface — global- and per-plugin-enablement checks, a registered async-handler contract, and a bounded execution timeout — as a service-layer capability available for future extension. Triggering plugin actions from the user interface requires an in-process plugin runtime capable of loading and running bundle code, which is outside the scope of this release; no UI control for execution is provided.

**FR11.6** [Simple Plugin Support] When invoked, plugin execution shall be timeout-guarded: a handler that fails, times out, or throws shall surface a typed error to its caller and be audit-logged, without crashing the host or corrupting note data, regardless of which surface (if any) ultimately invokes it.

**FR11.7** [Simple Plugin Support] The app shall persist installed-plugin metadata — plugin ID, display name, version, capabilities, enabled state, and install timestamp — with the plugin's bundle bytes stored separately, keyed by plugin ID.

**FR12.1** [Title Search] The workspace top bar shall provide a title search input that filters note list results by query text.

**FR12.2** [Title Search] Normal note titles shall be searched directly against their stored plaintext title.

**FR12.3** [Title Search] Secure note titles shall never be persisted in plaintext and shall never be decrypted for indexing or matching. Each secure note instead carries a separate, non-sensitive `secureTitleAlias` — a user-supplied display label (defaulting to "Locked Note") — that is persisted alongside the ciphertext and serves as the searchable and displayable surrogate for the real title.

**FR12.4** [Title Search] Title search shall match secure notes against their `secureTitleAlias` only, using the same case-insensitive substring comparison applied to normal-note titles; the search path shall hold no decrypted title data in memory at any point.

**FR12.5** [Title Search] Because matching never touches decrypted content, the availability of secure notes in search results shall be independent of lock state: a secure note is searchable by its alias whether the app session is locked or unlocked.

**FR14.1** [Subject Groups] The user shall be able to create a new subject group (folder) from the subject sidebar by providing a non-empty, unique name.

**FR14.2** [Subject Groups] The user shall be able to rename an existing subject group; the new name shall be validated as non-empty and unique before the change is committed.

**FR14.3** [Subject Groups] The user shall be able to delete a subject group; if the group contains notes, the app shall prompt for confirmation before proceeding.

**FR14.4** [Subject Groups] When a subject group is deleted, its notes shall not be deleted; they shall become ungrouped (no subject assigned).

**FR14.5** [Subject Groups] The user shall be able to assign a note to a subject group and move it between groups.

**FR14.6** [Subject Groups] The subject sidebar shall display all subject groups and an "All Notes" filter that shows every note regardless of group.

---

## Non-Functional Requirements

**NFR1.1** [Authentication Performance] Passphrase verification and key derivation (PBKDF2-HMAC-SHA256, 100,000 iterations) shall complete within approximately 1 second on Apple Silicon M-series or Intel Core i5/i7 (6th gen or later) hardware with 8 GB RAM.

**NFR1.2** [Authentication Performance] Because this cost is fixed by the iteration count rather than by data volume, authentication latency shall remain constant whether the database holds 100, 1,000, or 10,000 notes — there is no whole-app unlock step whose duration scales with note count; the workspace is loaded and rendered independently of authentication.

**NFR1.3** [Authentication Performance] Manual passphrase entry time is excluded from this measurement.

**NFR2.1** [UI Responsiveness] Encryption, database I/O, and plugin action execution shall run asynchronously through actor-isolated services and shall never block the main UI thread.

**NFR2.2** [UI Responsiveness] The app shall maintain 60 FPS responsiveness during normal use.

**NFR3.1** [Secure Note Data Confidentiality] Decrypted secure note content shall never be written to disk, logs, caches, or exports; persisted records shall contain only ciphertext, authentication data, salt, and the non-sensitive display alias.

**NFR3.2** [Secure Note Data Confidentiality] Decrypted secure content shall be held in memory only transiently, for display while a note is open in the active unlocked session, and shall be reset when the editor moves away from that note or the session locks. Secure-note title search shall rely solely on the persisted, non-sensitive `secureTitleAlias` and shall never hold decrypted titles in memory, so there is no decrypted-title cache to manage or clear.

**NFR4.1** [Data Integrity] Secure note records shall use authenticated encryption (AES-GCM) so tampered or replayed ciphertext fails verification explicitly.

**NFR4.2** [Data Integrity] A verification failure shall surface a user-visible error and leave the stored record unchanged.

**NFR5.1** [Reliability and Recovery] All database writes — including note edits and deletions, passphrase rotation, and backup import — shall be performed inside ACID transactions that commit in full or leave the previous state completely intact on failure.

**NFR5.2** [Reliability and Recovery] The two scenarios with the highest blast radius shall have explicit, tested recovery paths: (a) an interrupted passphrase rotation shall leave every secure note under its original credentials, with any stale in-flight rotation marker detected, cleared, and logged on the next unlock; (b) an interrupted import shall roll back in its entirety, leaving the prior database state intact, with the user shown a descriptive error. In both cases, the user reaches a consistent, usable state without manual intervention.

**NFR6.1** [Rate Limiting and Audit Logging] After 5 consecutive failed unlock attempts within 30 seconds, the app shall enforce a 30-second lockout that doubles with each subsequent breach, up to a maximum of 60 minutes.

**NFR6.2** [Rate Limiting and Audit Logging] Each lockout event shall be audit-logged.

**NFR6.3** [Rate Limiting and Audit Logging] Authentication failures, passphrase-rotation outcomes, plugin lifecycle events (install/remove/execute), and export/import completions shall be audit-logged with event names and small non-content metadata only — never note titles, content, or passphrases.

**NFR7.1** [Privacy by Omission] Consistent with the strictly-local design principle, the app shall collect and transmit no telemetry or usage analytics of any kind; no operational metrics leave the device, and none are gathered in the first place.
