# AstraNotes Requirement Set

## Functional Requirements

**FR1.1** [Unlock] On first launch, the app shall prompt the user to create a master passphrase before any note data is stored.

**FR1.2** [Unlock] On subsequent launches, the app shall require the master passphrase to start a session.

**FR1.3** [Unlock] After a successful passphrase unlock, the user may optionally enable biometric unlock for future sessions.

**FR1.4** [Unlock] Biometric unlock shall fall back to passphrase if biometrics are unavailable, rejected, or fail three consecutive times.

**FR1.5** [Unlock] If biometric hardware becomes unavailable after enrollment, passphrase fallback shall activate automatically.

**FR1.6** [Unlock] The consecutive biometric failure counter shall reset to zero after any successful unlock.

**FR2.1** [Normal Note Lifecycle] The user shall be able to create, edit, and delete notes containing text; attachments are optional.

**FR2.2** [Normal Note Lifecycle] Normal notes shall be stored as plain text with no encryption applied.

**FR2.3** [Normal Note Lifecycle] Each note shall have a stable unique identifier preserved across edits.

**FR2.4** [Normal Note Lifecycle] All note writes shall be atomic: a failed write shall roll back and leave the previous record unchanged.

**FR2.5** [Normal Note Lifecycle] Deleting a normal note shall move it and its attachments to protected trash in a single ACID transaction; if the move fails, the note record shall remain intact.

**FR3.1** [Secure Note Lifecycle] The user shall be able to opt any note into secure mode via the secure toggle in the editor top-right toolbar.

**FR3.2** [Secure Note Lifecycle] Enabling secure mode shall require the user to set both expiration date and expiration time.

**FR3.8** [Secure Note Lifecycle] The app shall reject an expiration timestamp that is in the past.

**FR3.3** [Secure Note Lifecycle] When a secure note is saved, the title and content shall be encrypted on-device before any write to storage. Storage shall contain only ciphertext, nonce, and salt.

**FR3.4** [Secure Note Lifecycle] Each secure note shall retain its stable unique identifier across edits.

**FR3.5** [Secure Note Lifecycle] All secure note writes shall be atomic: a failed write shall roll back and leave the previous ciphertext unchanged.

**FR3.6** [Secure Note Lifecycle] If decryption of a secure note fails due to invalid ciphertext or authentication data, the stored record shall be preserved and a user-visible error shall be shown.

**FR3.7** [Secure Note Lifecycle] Deleting a secure note shall move the encrypted record and its attachments to protected trash in a single ACID transaction.

**FR4.1** [Secure Note Expiration] The app shall check secure note expiration on every launch and periodically during active use.

**FR4.6** [Secure Note Expiration] The expiration timestamp shall be interpreted in device local time at selection and stored as UTC for comparison.

**FR4.2** [Secure Note Expiration] A note that expired while the app was not running shall be treated as expired on the next launch.

**FR4.3** [Secure Note Expiration] When a secure note expires, it shall be removed from the active note list and moved to protected trash automatically.

**FR4.4** [Secure Note Expiration] The app shall show an in-app banner for expiry events in the foreground, and a scheduled local notification when backgrounded or not running.

**FR4.5** [Secure Note Expiration] The app shall store the last known UTC timestamp on each launch. If the current device time is earlier than that stored value, no secure note shall be treated as unexpired.

**FR4.7** [Secure Note Expiration] The secure note editor shall provide explicit date and time controls so the user can choose the exact expiration moment.

**FR5.1** [Protected Trash] All deleted notes (normal and secure) shall be moved to protected trash, not deleted immediately.

**FR5.2** [Protected Trash] The trash view shall display all trashed items with title, deletion time, and a lock badge for secure notes.

**FR5.3** [Protected Trash] Secure notes in trash shall not show a readable title; only a lock badge is shown until restored.

**FR5.4** [Protected Trash] The user shall be able to restore any trashed note back to the active note list.

**FR5.5** [Protected Trash] Restoring a secure note from trash shall require an active unlocked session; the app shall block restore if locked.

**FR5.6** [Protected Trash] The user shall be able to permanently delete any trashed note.

**FR5.7** [Protected Trash] Permanently deleting a secure note shall wipe its ciphertext and all linked attachments with no recovery path.

**FR6.1** [Voice Capture] The editor top bar shall provide a voice capture button to record audio.

**FR6.2** [Voice Capture] Recorded audio shall be stored in the app container with complete file protection.

**FR6.3** [Voice Capture] Audio exceeding 10 minutes or 50 MB shall be rejected before storage with a message stating the applicable limit.

**FR7.1** [Auto-Lock] The app shall auto-lock after no user input for longer than the configured timeout (default 5 minutes).

**FR7.2** [Auto-Lock] The app shall auto-lock when the OS sleeps or the app enters the background.

**FR7.3** [Auto-Lock] Background operations such as export or key rotation shall not count as user activity and shall not reset the inactivity timer.

**FR7.4** [Auto-Lock] On lock, all in-memory key material shall be cleared before re-authentication is required.

**FR7.5** [Auto-Lock] If auto-lock fires while a secure note is being edited, the app shall encrypt and persist unsaved changes as a draft before completing the lock transition.

**FR8.1** [Passphrase Change and Key Rotation] The user shall be able to change the master passphrase at any time.

**FR8.2** [Passphrase Change and Key Rotation] Changing the passphrase shall trigger re-encryption of all secure notes and their attachments using keys derived from the new passphrase.

**FR8.3** [Passphrase Change and Key Rotation] The old key material shall be retained until every secure record is confirmed re-encrypted; only then shall the old key be removed.

**FR8.4** [Passphrase Change and Key Rotation] If re-encryption is interrupted, the app shall detect the partial migration on next launch, complete or roll back using the retained old key, and inform the user before allowing normal access.

**FR8.5** [Passphrase Change and Key Rotation] If the new passphrase derives an identical key to the existing one, the app shall skip re-encryption and return success without unnecessary I/O.

**FR8.6** [Passphrase Change and Key Rotation] Normal notes are unaffected by passphrase change.

**FR9.1** [Export and Import] Export shall produce an encrypted archive containing all note records and required metadata, tagged with the current schema version and protected by the user's passphrase.

**FR9.2** [Export and Import] Import shall accept only encrypted archives with a compatible schema version; incompatible versions shall be rejected with an error identifying the mismatch.

**FR9.3** [Export and Import] If an imported archive contains note IDs that conflict with existing local records, imported notes shall receive new unique identifiers; existing local notes shall not be overwritten.

**FR9.4** [Export and Import] Import shall be all-or-nothing: if storage is exhausted mid-import, the entire operation shall roll back with no partial state committed, and the user shall be informed with guidance to free storage before retrying.

**FR10.1** [Settings] The app shall allow the user to configure lock timeout, telemetry opt-in, and plugin preference flags.

**FR10.2** [Settings] All settings changes shall be validated before commit; invalid values shall be rejected with a user-visible message.

**FR11.1** [Simple Plugin Support] The app shall allow the user to install a plugin from a local package file.

**FR11.2** [Simple Plugin Support] On installation, the app shall validate plugin manifest structure (`pluginId`, name, version, supported app version, entry action, capabilities) before enabling the plugin.

**FR11.3** [Simple Plugin Support] The app shall allow the user to enable, disable, and remove installed plugins from the plugin management UI.

**FR11.4** [Simple Plugin Support] Enabled plugins shall run only through the host API exposed by `PluginService`; plugins shall not read or write repositories directly.

**FR11.5** [Simple Plugin Support] The app shall support at least one plugin action type in MVP: text transformation on the current note content.

**FR11.6** [Simple Plugin Support] If a plugin action succeeds, the returned result shall be applied through normal note save flow.

**FR11.7** [Simple Plugin Support] If a plugin action fails, times out, or throws an error, the app shall preserve current note state, show a user-visible error, and continue running.

**FR11.8** [Simple Plugin Support] The app shall persist plugin metadata including enabled state, install path/hash, last run status, and last error.

**FR12.1** [Title Search] The workspace top bar shall provide a title search input that filters note list results by query text.

**FR12.2** [Title Search] Normal note titles shall be searchable directly from stored title data.

**FR12.3** [Title Search] Secure note titles shall remain encrypted at rest and shall not be stored as plaintext for search indexing.

**FR12.4** [Title Search] Secure note titles shall be searchable only when the app is unlocked, using in-memory decrypted title matching for the active session.

**FR12.5** [Title Search] When the app locks, all in-memory decrypted secure title search data shall be cleared immediately.

**FR12.6** [Title Search] While the app is locked, secure notes shall be excluded from title search results.

---

## Non-Functional Requirements

**NFR1.1** [Unlock Performance] Unlock shall complete within 1 second on Apple Silicon M-series or Intel Core i5/i7 (6th gen or later) with 8 GB RAM and SSD, loaded with 1,000 notes.

**NFR1.2** [Unlock Performance] Unlock should complete within 2 seconds at 10,000 notes.

**NFR1.3** [Unlock Performance] Manual passphrase entry time is excluded from this measurement.

**NFR2.1** [UI Responsiveness] Encryption, database I/O, transcription, and plugin action execution shall run asynchronously and must not block the main UI thread.

**NFR2.2** [UI Responsiveness] The app shall maintain 60 FPS responsiveness during normal use.

**NFR3.1** [Secure Note Data Confidentiality] Decrypted secure note content shall never be written to disk, logs, caches, or exports.

**NFR3.2** [Secure Note Data Confidentiality] Decrypted secure material, including secure note titles used for search, shall be held in memory only for the active unlocked session and cleared on lock.

**NFR4.1** [Data Integrity] Secure note records shall use authenticated encryption so tampered or replayed ciphertext fails verification explicitly.

**NFR4.2** [Data Integrity] A verification failure shall surface a user-visible error and leave the stored record unchanged.

**NFR5.1** [Reliability and Recovery] All database writes shall use ACID transactions.

**NFR5.2** [Reliability and Recovery] Failed migrations shall roll back and leave the previous state intact.

**NFR5.3** [Reliability and Recovery] Corrupted database or partial-migration states shall surface clear in-app recovery instructions.

**NFR6.1** [Rate Limiting and Audit Logging] After 5 consecutive failed unlock attempts within 30 seconds, the app shall enforce a 30-second lockout that doubles with each subsequent breach, up to a maximum of 60 minutes.

**NFR6.2** [Rate Limiting and Audit Logging] Each lockout event shall be audit-logged.

**NFR6.3** [Rate Limiting and Audit Logging] Authentication failures, plugin manifest validation failures, and plugin runtime failures shall be audit-logged without exposing note content.

**NFR7.1** [Telemetry Privacy] Telemetry shall be opt-in and limited to non-sensitive operational metrics.

**NFR7.2** [Telemetry Privacy] Note text, note titles, and content-derived data shall never be included in telemetry.

**NFR8.1** [Accessibility] All core workflows (note browsing, editing, lock/unlock, trash, settings) shall support VoiceOver and full keyboard navigation.

**NFR9.1** [Internationalization] The app shall ship in English first.

**NFR9.2** [Internationalization] The codebase shall use a localization architecture that supports adding new languages without rewriting features.
