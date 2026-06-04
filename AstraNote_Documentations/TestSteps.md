# AstraNote Comprehensive Test Plan

## Organization
Test cases are organized by epic/feature with positive, negative, and edge case coverage. All 96 requirements (76 FR + 20 NFR) mapped to test cases. Tests follow functional areas and include requirement references.

---

## 1. First-Launch Initialization and Passphrase Creation (FR1.1)

**Test 1.1**: First-launch → verify `UnlockView` appears with passphrase creation screen (not entry screen).
**Test 1.2**: Verify all note operations disabled until passphrase created (no sidebar, editor, settings access).
**Test 1.3**: Create valid passphrase, confirm, verify workspace loads.
**Test 1.4**: Attempt passphrase with empty/whitespace input → rejection with message.
**Test 1.5**: Passphrase entry and confirmation mismatch → re-entry prompt.
**Test 1.6**: Verify passphrase stored securely (never plaintext in logs/memory dumps).

---

## 2. Unlock and Session Management (FR1.1-1.6, NFR1.1-1.3, NFR6.1-6.3)

### 2.1 Passphrase Unlock (FR1.2, NFR1.1-1.3)
**Test 2.1**: Enter correct passphrase, verify unlock within 1 second (1,000 notes; NFR1.1).
**Test 2.2**: Unlock with 10,000 notes within 2 seconds (NFR1.2).
**Test 2.3**: Verify passphrase entry time excluded from measurement (NFR1.3).
**Test 2.4**: Wrong passphrase → rejection with error.
**Test 2.5**: Failed unlock increments consecutive failure counter.

### 2.2 Rate Limiting and Lockout (NFR6.1-6.3)
**Test 2.6**: 5 failed unlock attempts in 30 seconds → 30-second lockout enforced (NFR6.1).
**Test 2.7**: Next 5 failures after first lockout → 60-second lockout (doubled; NFR6.1).
**Test 2.8**: Lockout progression caps at 60 minutes (NFR6.1).
**Test 2.9**: Each lockout event audit-logged (NFR6.2).
**Test 2.10**: Auth failure logs sanitized, no passphrase/content exposed (NFR6.3).

### 2.3 Biometric Unlock (FR1.3-1.6)
**Test 2.11**: After successful passphrase unlock, prompt to enable biometric (FR1.3).
**Test 2.12**: Enable biometric, lock, verify biometric entry prompted on next launch.
**Test 2.13**: Correct biometric → workspace loads, failure counter resets to 0 (FR1.6).
**Test 2.14**: Reject biometric 3 times → passphrase fallback screen (FR1.4).
**Test 2.15**: Fail once, succeed on second attempt → counter resets (FR1.6).
**Test 2.16**: Biometric unavailability (hardware error) → passphrase fallback auto-activates (FR1.5).
**Test 2.17**: Disable biometric, verify passphrase screen on next lock/unlock.

---

## 3. Normal Note Lifecycle (FR2.1-2.5, NFR2.1, NFR5.1)

### 3.1 Create and Save
**Test 3.1**: Create note with text → appears in active list (FR2.1).
**Test 3.2**: Verify normal note stored as plain text (FR2.2).
**Test 3.3**: Verify note has stable unique ID after creation (FR2.3).
**Test 3.4**: Simulate write failure during save → rollback preserves previous state (FR2.4, NFR5.1).
**Test 3.5**: Save note with >1 MB text, verify atomic completion.
**Test 3.6**: Multiple rapid saves, verify all atomic (FR2.4).

### 3.2 Edit and Update
**Test 3.7**: Edit note content → note ID remains stable (FR2.3).
**Test 3.8**: Edit and save multiple times → all atomic, previous state recoverable (FR2.4).

### 3.3 Delete and Trash
**Test 3.9**: Delete normal note → moves to protected trash in single transaction (FR2.5, NFR5.1).
**Test 3.10**: Restore normal note from trash → returns to active list with same content.
**Test 3.11**: Permanently delete normal note → record removed.
**Test 3.12**: Simulate trash failure → note remains in active list (rollback; FR2.5).

---

## 4. Secure Note Lifecycle (FR3.1-3.7, FR3.9, NFR3.1-3.2, NFR4.1-4.2)

### 4.1 Enable Secure Mode
**Test 4.1**: Toggle secure mode → secure controls appear without expiration fields (FR3.1, FR3.2).
**Test 4.2**: Save secure note → note encrypts immediately without time-based validation (FR3.2, FR3.3).
**Test 4.3**: Secure note access still requires step-up authentication before open (FR3.9).

### 4.2 Encryption and Storage
**Test 4.4**: Save secure note, inspect database → ciphertext only, no plaintext (FR3.3).
**Test 4.5**: Ciphertext record includes nonce and salt (FR3.3).
**Test 4.6**: Secure note has stable ID across edits (FR3.4).
**Test 4.7**: Edit and save → atomic write, previous ciphertext preserved on failure (FR3.5, NFR5.1).
**Test 4.8**: Decrypted content never in logs, caches (except in-memory search), exports (NFR3.1).
**Test 4.9**: Decrypted titles held in memory only during unlocked session, cleared on lock (NFR3.2).

### 4.3 Decryption Failure and Integrity
**Test 4.10**: Corrupt secure ciphertext → view fails, error shown, record preserved (FR3.6, NFR4.2).
**Test 4.11**: Authenticated encryption (AES-GCM) → tampered ciphertext fails verification (NFR4.1).
**Test 4.12**: Decrypt with wrong key → auth failure, record preserved (NFR4.1, NFR4.2).

### 4.4 Secure Note Deletion
**Test 4.13**: Delete secure note → encrypted record/attachments move to trash, single transaction (FR3.7, NFR5.1).
**Test 4.14**: Permanently delete from trash → ciphertext/attachments wiped, unrecoverable (FR5.7).

---

## 5. Secure Note Retention (FR4.1-4.2)

### 5.1 Retention Checks
**Test 5.1**: Create secure note and leave app open → note remains active with no automatic trash move.
**Test 5.2**: Close and relaunch app → secure note stays in active list on launch.
**Test 5.3**: Multiple secure notes remain active until deleted.
**Test 5.4**: Secure-note runtime policies never emit expiry notifications.

### 5.2 Device Time Changes
**Test 5.5**: Roll back device time → secure notes remain active and no policy action is triggered.
**Test 5.6**: Advance device time forward → secure-note availability is unchanged because no time-based policy runs.

---

## 6. Protected Trash Management (FR5.1-5.7)

### 6.1 Trash Display and Semantics (FR5.2, FR5.3)
**Test 6.1**: Delete normal note → trash shows title, deletion time, Restore/Delete buttons (FR5.2).
**Test 6.2**: Delete secure note → trash shows deletion time, lock badge, NO readable title (FR5.2, FR5.3).
**Test 6.3**: Click secure note in trash to preview → "locked, cannot preview" message (FR5.3).
**Test 6.4**: Unlock while viewing trash → secure notes still show lock badge only (FR5.3).
**Test 6.5**: Lock while viewing trash → secure titles remain hidden (FR5.3).

### 6.2 Restore Flow
**Test 6.6**: Restore normal note → returns to active list with original content (FR5.4).
**Test 6.7**: Restore secure note while unlocked → returns to active list, decryption succeeds (FR5.4).
**Test 6.8**: Attempt restore secure note while locked → operation blocked (FR5.5).
**Test 6.9**: Lock during restore → operation cancelled or queued.
**Test 6.10**: Restore removes from trash.

### 6.3 Permanent Delete
**Test 6.11**: Permanently delete normal note → record removed from database (FR5.6).
**Test 6.12**: Permanently delete secure note → ciphertext/attachments wiped (FR5.7).
**Test 6.13**: Verify permanent delete not recoverable.
**Test 6.14**: Simulate delete failure → clear error, record may remain for retry.

---

## 7. Voice Capture (FR6.1-6.3, FR6.2)

### 7.1 Recording and Storage
**Test 7.1**: Click voice capture button → recording UI appears (FR6.1).
**Test 7.2**: Record <10 min, <50 MB → saved with complete file protection (FR6.2).
**Test 7.3**: Record in normal note → stored unencrypted with OS protection (FR6.2).
**Test 7.4**: Record in secure note → stored encrypted, inheriting security mode (FR6.2).
**Test 7.5**: Protected-recording write occurs after recording completes, before linking (FR6.2).

### 7.2 Size/Duration Limits
**Test 7.6**: Recording >10 minutes → rejection with limit message (FR6.3).
**Test 7.7**: Recording >50 MB → rejection with limit message (FR6.3).
**Test 7.8**: Boundary: exactly 10 minutes → save succeeds.
**Test 7.9**: Boundary: exactly 50 MB → save succeeds.

### 7.3 Asynchronous Transcription
**Test 7.10**: Transcription runs async without blocking UI (NFR2.1).
**Test 7.11**: During transcription, perform edits → UI responsive (NFR2.2, 60 FPS).
**Test 7.12**: Transcription fails → clear error, note unchanged.

---

## 8. Image Attachment (FR13.1-13.3)

### 8.1 Attach and Store
**Test 8.1**: Click attach image → file picker appears (FR13.1).
**Test 8.2**: Select local image file (no camera, no remote URL; FR13.1).
**Test 8.3**: Image stored with complete file protection (FR13.2).
**Test 8.4**: Image in normal note stored unencrypted with OS protection (FR13.2).
**Test 8.5**: Image in secure note encrypted, matching security mode (FR13.2).
**Test 8.6**: Attachment record includes `type: image` and `noteId`.

### 8.2 Size Limits
**Test 8.7**: Attach image >20 MB → rejection with limit message (FR13.3).
**Test 8.8**: Boundary: exactly 20 MB → save succeeds.

### 8.3 Multiple Attachments
**Test 8.9**: Attach multiple images → all stored and linked correctly.
**Test 8.10**: Attach image + voice recording → both stored with correct security mode.
**Test 8.11**: Delete note with attachments → all move to trash (or deleted per design).

---

## 9. Auto-Lock and Session Management (FR7.1-7.5)

### 9.1 Inactivity Lock
**Test 9.1**: Configure timeout to 1 minute (FR7.1).
**Test 9.2**: Leave idle 1 minute → auto-lock (FR7.1).
**Test 9.3**: Perform action (typing, tapping) → timer resets.
**Test 9.4**: Default 5-minute timeout → behavior matches (FR7.1).
**Test 9.5**: Timer continues during background operations, does not reset (FR7.3).

### 9.2 Sleep and Background Lock
**Test 9.6**: Put OS to sleep → app locks immediately (FR7.2).
**Test 9.7**: Background app → lock triggered per policy (FR7.2).
**Test 9.8**: Resume from sleep, app backgrounded → remains locked.

### 9.3 Key Clearing on Lock
**Test 9.9**: Lock app → all in-memory keys cleared (FR7.4).
**Test 9.10**: View secure note after lock → decryption fails (FR7.4).
**Test 9.11**: Secure title search cache cleared on lock (NFR3.2).

### 9.4 Draft Persistence
**Test 9.12**: Edit secure note, lock without saving → draft encrypted/persisted (FR7.5).
**Test 9.13**: Unlock → draft restored in editor.

---

## 10. Passphrase Change and Key Rotation (FR8.1-8.6, NFR5.2-5.3)

### 10.1 Passphrase Change
**Test 10.1**: Initiate passphrase change in settings (FR8.1).
**Test 10.2**: Enter new passphrase and confirm → all secure notes re-encrypted (FR8.2, NFR5.1).
**Test 10.3**: Normal notes unaffected (FR8.6).
**Test 10.4**: After rotation, unlock with new passphrase → workspace loads, secure notes accessible (FR8.2).

### 10.2 Key Rotation and Recovery
**Test 10.5**: Initiate passphrase change and interrupt (force quit, crash) mid-rotation (FR8.4, NFR5.3).
**Test 10.6**: Restart → app detects partial migration (FR8.4).
**Test 10.7**: App attempts to complete remaining re-encryption (FR8.4).
**Test 10.8**: If succeeds → new passphrase active, user informed (FR8.4, NFR5.3).
**Test 10.9**: If fails → all records rolled back to old key, previous passphrase restored, user informed (FR8.4, NFR5.3).
**Test 10.10**: Old key material retained until rotation complete (FR8.3).

### 10.3 Identical Key Rejection
**Test 10.11**: New passphrase derives same key → rejection with error (FR8.5).
**Test 10.12**: No re-encryption or storage write performed (FR8.5).
**Test 10.13**: Prompt to choose different passphrase (FR8.5).

### 10.4 Attachment Re-encryption
**Test 10.14**: Create secure note with secure attachments (FR6.2, FR13.2).
**Test 10.15**: Change passphrase → secure attachments also re-encrypted (FR8.2).

---

## 11. Export and Import (FR9.1-9.4, NFR5.1-5.3)

### 11.1 Export
**Test 11.1**: Initiate export from settings (FR9.1).
**Test 11.2**: Select location → encrypted archive created, schema-tagged (FR9.1).
**Test 11.3**: Archive passphrase-protected (FR9.1).
**Test 11.4**: Inspect archive → no decrypted content visible (FR9.1, NFR3.1).
**Test 11.5**: Mix of normal and secure notes → all in archive.

### 11.2 Import Validation
**Test 11.6**: Import compatible schema → proceeds (FR9.2).
**Test 11.7**: Correct passphrase → import accepted (FR9.2).
**Test 11.8**: Incompatible schema → rejection with mismatch error (FR9.2).
**Test 11.9**: Wrong passphrase → rejection, data not written (FR9.2).

### 11.3 Atomic Import
**Test 11.10**: Import archive with notes → all restored atomically (FR9.4, NFR5.1).
**Test 11.11**: Storage exhaustion during import → full rollback, no partial state (FR9.4, NFR5.1).
**Test 11.12**: User informed to free storage and retry (FR9.4).
**Test 11.13**: ID conflicts → imported notes get new IDs, existing not overwritten (FR9.3).
**Test 11.14**: Corrupt import records → detected, error reported, rollback (NFR5.3).

---

## 12. Title Search (FR12.1-12.6, NFR3.1-3.2)

### 12.1 Normal Title Search
**Test 12.1**: Type query in workspace top bar (FR12.1).
**Test 12.2**: Normal notes filtered by matching title (FR12.2).
**Test 12.3**: Search works at any time for normal notes (FR12.2).
**Test 12.4**: Results update in real-time as query changes.
**Test 12.5**: Clear search, all notes shown.

### 12.2 Secure Title Search
**Test 12.6**: Unlocked, query matches secure note title → appears in results (FR12.4).
**Test 12.7**: Secure search uses in-memory decrypted matching, not persistent index (FR12.3, FR12.4).
**Test 12.8**: Lock app → secure notes excluded from results (FR12.6).
**Test 12.9**: On lock, in-memory search cache cleared (FR12.5, NFR3.2).
**Test 12.10**: Unlock → secure notes searchable again.

---

## 13. Subject Group Management (FR14.1-14.6)

### 13.1 Create Subject Group
**Test 13.1**: Click add in sidebar → create dialog (FR14.1).
**Test 13.2**: Unique, non-empty name → group created, appears in sidebar (FR14.1).
**Test 13.3**: Empty name → rejection (FR14.1).
**Test 13.4**: Duplicate name → rejection (FR14.1).

### 13.2 Rename Subject Group
**Test 13.5**: Click rename → inline edit (FR14.2).
**Test 13.6**: New unique, non-empty name → committed (FR14.2).
**Test 13.7**: Empty name → rejection (FR14.2).
**Test 13.8**: Duplicate name → rejection (FR14.2).

### 13.3 Delete Subject Group
**Test 13.9**: Delete empty group → removed (FR14.3).
**Test 13.10**: Delete group with notes → confirmation prompt (FR14.3).
**Test 13.11**: After confirmation, group deleted, notes ungrouped (FR14.4).
**Test 13.12**: Cancel confirmation → group remains, notes stay assigned.

### 13.4 Assign and Move Notes
**Test 13.13**: Assign note to subject → appears under group (FR14.5).
**Test 13.14**: Move note between groups → appears in new, removed from old (FR14.5).
**Test 13.15**: Create note with subject selected → auto-assigned (FR14.5).
**Test 13.16**: "All Notes" filter shows every note (FR14.6).

---

## 14. Simple Plugin Support (FR11.1-11.8, NFR2.1)

### 14.1 Installation and Validation
**Test 14.1**: Open plugin management (FR11.3).
**Test 14.2**: Install local plugin package → manifest validation (FR11.2).
**Test 14.3**: Manifest checks: pluginId, name, version, supportedAppVersion, entryAction, capabilities (FR11.2).
**Test 14.4**: Invalid manifest → rejection with error (FR11.2).
**Test 14.5**: Plugin metadata persisted: enabled, install path/hash, last run status, last error (FR11.8).

### 14.2 Enable/Disable and Execution
**Test 14.6**: Enable plugin → metadata updated (FR11.3, FR11.8).
**Test 14.7**: Disable plugin → plugins blocked globally (FR10.1).
**Test 14.8**: Plugin runs through host API, not direct repo access (FR11.4).
**Test 14.9**: Plugin action (text transform) on current note (FR11.5).
**Test 14.10**: Plugin executes async without blocking (NFR2.1, NFR2.2, 60 FPS).

### 14.3 Success and Failure Handling
**Test 14.11**: Plugin succeeds → result applied through normal save (FR11.6).
**Test 14.12**: Secure note → result re-encrypted (FR11.6).
**Test 14.13**: Plugin fails or times out → error shown, note preserved (FR11.7).
**Test 14.14**: Plugin throws exception → app responsive, no crash (FR11.7).
**Test 14.15**: Plugin failure audit-logged safely (NFR6.3).

### 14.4 Plugin Management
**Test 14.16**: Remove plugin → removed from enabled list (FR11.3).
**Test 14.17**: View plugin status (enabled, disabled, error) (FR11.8).
**Test 14.18**: Global toggle disables all without removing records (FR10.1).

---

## 15. Settings and Configuration (FR10.1-10.2)

### 15.1 Lock Timeout
**Test 15.1**: Adjust lock timeout value (FR10.1).
**Test 15.2**: Valid timeout (1, 5, 10 minutes) → accepted (FR10.2).
**Test 15.3**: Invalid timeout (negative, non-numeric) → rejection (FR10.2).
**Test 15.4**: New timeout takes effect immediately.

### 15.2 Telemetry
**Test 15.5**: Telemetry opt-in toggle (FR10.1).
**Test 15.6**: Disabled → no telemetry sent (FR7.1).
**Test 15.7**: Enabled → non-sensitive metrics sent (NFR7.1).
**Test 15.8**: Telemetry excludes note text, titles, derived data (NFR7.2).

### 15.3 Global Plugin Toggle
**Test 15.9**: Toggle plugin enable/disable (FR10.1).
**Test 15.10**: Disabled → plugins blocked from running (FR10.1).
**Test 15.11**: Installed records retained when disabled (FR10.1).

---

## 16. Accessibility (NFR8.1)

### 16.1 Keyboard Navigation
**Test 16.1**: Navigate unlock flow keyboard-only (NFR8.1).
**Test 16.2**: Browse, create, edit, delete notes keyboard-only (NFR8.1).
**Test 16.3**: Navigate trash keyboard-only (NFR8.1).
**Test 16.4**: Navigate settings keyboard-only (NFR8.1).
**Test 16.5**: All elements have focus indicators.

### 16.2 VoiceOver Support
**Test 16.6**: Unlock flow with VoiceOver → all elements labeled, readable (NFR8.1).
**Test 16.7**: Browse and edit notes with VoiceOver → actions announced (NFR8.1).
**Test 16.8**: Navigate trash, settings with VoiceOver (NFR8.1).
**Test 16.9**: Button labels, field labels, messages VoiceOver-compatible.

---

## 17. Internationalization (NFR9.1-9.2)

### 17.1 English-First Release
**Test 17.1**: App ships English (NFR9.1).
**Test 17.2**: All UI strings, messages, documentation in English.

### 17.2 Localization Architecture
**Test 17.3**: Architecture supports new language without rewriting features (NFR9.2).
**Test 17.4**: Add non-English locale (Spanish, French, etc.) → strings localized, features work (NFR9.2).

---

## 18. Data Integrity and Recovery (NFR4.1-4.2, NFR5.1-5.3)

### 18.1 Authenticated Encryption
**Test 18.1**: Secure notes use authenticated encryption (AES-GCM) (NFR4.1).
**Test 18.2**: Tampered ciphertext → auth fails (NFR4.1).
**Test 18.3**: Failure shows user error, record preserved (NFR4.2).

### 18.2 ACID Transactions
**Test 18.4**: All DB writes use ACID transactions (NFR5.1).
**Test 18.5**: Transaction failure → rollback to previous state (NFR5.1).

### 18.3 Corruption Recovery
**Test 18.6**: Database corruption → detected, recovery instructions provided (NFR5.3).
**Test 18.7**: Partial passphrase rotation → detection and recovery (NFR5.3).
**Test 18.8**: Corrupted import → detection, rollback, guidance (NFR5.3).

---

## 19. Performance and Responsiveness (NFR1.1-1.3, NFR2.1-2.2)

### 19.1 Unlock Performance
**Test 19.1**: Unlock with 1,000 notes on target hardware ≤1 second (NFR1.1).
**Test 19.2**: Unlock with 10,000 notes ≤2 seconds (NFR1.2).
**Test 19.3**: Passphrase entry time excluded (NFR1.3).

### 19.2 UI Responsiveness
**Test 19.4**: Frame time during note editing → 60 FPS target (NFR2.2).
**Test 19.5**: Frame time during encryption save (bg) → responsive (NFR2.1).
**Test 19.6**: Frame time during transcription → no drops (NFR2.1).
**Test 19.7**: Frame time during plugin execution → async (NFR2.1).

---

## 20. Confidentiality Boundaries (NFR3.1-3.2)

### 20.1 Disk Persistence
**Test 20.1**: DB inspection → no decrypted content (NFR3.1).
**Test 20.2**: Only ciphertext, nonce, salt, metadata stored (NFR3.1).

### 20.2 Logging
**Test 20.3**: Debug logging → no decrypted content, titles, derived data (NFR3.1, NFR6.3).
**Test 20.4**: Auth failures, plugin errors logged safely (NFR6.3).

### 20.3 Caching
**Test 20.5**: In-memory search cache holds plaintext only during unlock (NFR3.2).
**Test 20.6**: On lock, cache cleared immediately (NFR3.2).
**Test 20.7**: No decrypted content cached to disk (NFR3.1, NFR3.2).

### 20.4 Exports
**Test 20.8**: Export inspection → no decrypted content (NFR3.1).
**Test 20.9**: Archive encrypted under passphrase (FR9.1).

### 20.5 UI Display
**Test 20.10**: Secure note edit → content in memory, not persisted to logs/temp (NFR3.1).
**Test 20.11**: On lock, text fields masked/cleared (NFR3.1, NFR3.2).

---

## Test Execution Strategy
- **Automation**: Unlock, CRUD, import/export, key rotation, basic plugin flows.
- **Manual**: Accessibility, VoiceOver, plugin failure modes, UI responsiveness, edge cases.
- **Performance**: Representative hardware (Apple Silicon M-series, Intel i5/i7 6th gen+), target datasets.
- **Integration**: Feature interactions (secure + attachment + auto-lock + key rotation).
- **Regression**: After each change, re-run unlock, CRUD, core security flows.

**Metrics**: ≥95% code coverage (core services), all NFR benchmarks met, no decrypted content leakage, all ACID transactions validated.
