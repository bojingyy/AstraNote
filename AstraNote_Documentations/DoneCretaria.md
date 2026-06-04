# AstraNote Done Criteria (Based on Finalized Design)

All criteria aligned with Requirement.md, Architecture.md, and Traceability matrix (100% requirements coverage). Done criteria map to specific FR/NFR and test case references.

---

## 1. Foundation: Data Persistence and Crypto (Phase 1)

**Database**:
- [x] SQLite database created with schema supporting subject groups, normal notes, secure notes, attachments, trash, settings, and plugin metadata (Architecture §6).
- [x] All database writes use ACID transactions (NFR5.1).
- [x] Transaction rollback on failure preserves previous state (NFR5.1).
- [x] Database migrations versioned and tested (Architecture).
- [x] Database corruption detected via integrity checks (NFR5.3).

**Encryption and Key Management**:
- [x] `KeyManager` implements PBKDF2-based passphrase hashing with configurable iterations (FR1.1, FR1.2).
- [x] AES-256 key derivation from passphrase produces consistent keys (FR1.2).
- [x] `EncryptionService` uses AES-GCM for authenticated encryption (NFR4.1).
- [x] All test vectors for AES-GCM pass (AES-GCM RFC 5116 validation).
- [x] Keys held in memory only during unlocked session (NFR3.2).
- [x] All in-memory key material cleared on lock (FR7.4, NFR3.2).
- [x] Decrypted content never written to disk or logs (NFR3.1).

**Rate Limiting and Audit Logging**:
- [x] After 5 consecutive failed unlock attempts within 30 seconds, enforce 30-second lockout (NFR6.1).
- [x] Subsequent lockouts double (60s, 120s, etc.) up to 60-minute maximum (NFR6.1).
- [x] Each lockout event audit-logged with timestamp and reason (NFR6.2).
- [x] Authentication failure logs exclude passphrase and note content (NFR6.3).
- [x] Plugin manifest validation failures audit-logged safely (NFR6.3).
- [x] Plugin runtime failures audit-logged without sensitive content (NFR6.3).

**Test Coverage**:
- [x] ≥95% code coverage for `KeyManager`, `EncryptionService`, `DatabaseProvider`.
- [x] All ACID transaction test cases pass (rollback, atomicity).
- [x] Rate limiting progression verified (Test 2.6-2.10).

---

## 2. Core Note Lifecycle (Phase 2)

**Normal Notes (FR2.1-2.5)**:
- [x] User can create notes with text content via `NotesWorkspaceView`.
- [x] Created notes persisted as plain text (no encryption) in database (FR2.2).
- [x] Each note has stable unique ID preserved across all edits (FR2.3).
- [x] All note writes are atomic; failed write rolls back and preserves previous state (FR2.4, NFR5.1).
- [x] Deleting normal note moves it and all attachments to protected trash in single transaction (FR2.5, NFR5.1).
- [x] If trash operation fails, note remains in active list (rollback; FR2.5).
- [x] Test cases 3.1-3.12 pass (normal note CRUD).

**Subject Groups (FR14.1-14.6)**:
- [x] User can create subject groups from sidebar with unique, non-empty names (FR14.1).
- [x] Empty or duplicate names rejected with user-visible error message (FR14.1).
- [x] Subject group can be renamed inline; new name validated (non-empty, unique) before commit (FR14.2).
- [x] User can delete empty subject group; group removed from sidebar (FR14.3).
- [x] Delete subject group with notes prompts for confirmation; after confirmation, group deleted and notes become ungrouped (FR14.4).
- [x] User can assign note to subject and move between subjects (FR14.5).
- [x] "All Notes" filter shows every note regardless of subject (FR14.6).
- [x] Test cases 13.1-13.16 pass (subject management).

**Database Persistence**:
- [x] Normal notes and subject groups persisted with all ACID guarantees (NFR5.1).
- [x] Test cases 18.4-18.5 pass (ACID transaction validation).

---

## 3. Secure Note Lifecycle (Phase 3)

**Secure Mode (FR3.1-3.7, FR3.9)**:
- [x] User can toggle secure mode from editor toolbar (FR3.1).
- [x] Enabling secure mode does not require any expiration fields before save (FR3.2).
- [x] Secure notes are encrypted immediately when saved (FR3.2, FR3.3).
- [x] When secure note saved, title and content encrypted on-device before storage write (FR3.3).
- [x] Database stores only ciphertext, nonce, and salt for secure notes (no plaintext; FR3.3).
- [x] Secure note has stable ID across edits (FR3.4).
- [x] Secure note writes atomic; failed write preserves previous ciphertext (FR3.5, NFR5.1).
- [x] If decryption fails (corrupt ciphertext or auth data), error shown to user and record preserved (FR3.6, NFR4.2).
- [x] Deleting secure note moves encrypted record and attachments to trash in single transaction (FR3.7, NFR5.1).
- [x] Test cases 4.1-4.16 pass (secure note lifecycle).

**Secure Retention (FR4.1-4.2)**:
- [x] Secure notes remain in the active list until deleted (FR4.1).
- [x] Secure-note save and load flows preserve retention without any time-based policy checks (FR4.2).
- [x] Secure notes do not emit expiration notifications or time-rollback behavior.
- [x] Test cases 5.1-5.6 pass (secure-note retention).

**Data Integrity (NFR4.1-4.2)**:
- [x] Secure notes use authenticated encryption (AES-GCM) (NFR4.1).
- [x] Tampered or replayed ciphertext fails authentication verification (NFR4.1).
- [x] Verification failure shows user-visible error; record left unchanged (NFR4.2).
- [x] Test cases 18.1-18.3 pass (authenticated encryption validation).

---

## 4. Protected Trash and Recovery (Phase 3)

**Trash Display Semantics (FR5.2, FR5.3)**:
- [x] Trash view lists all trashed items (normal and secure) (FR5.1, FR5.2).
- [x] **Normal notes in trash**: Display title, deletion time, Restore and Permanently Delete actions (FR5.2).
- [x] **Secure notes in trash**: Display deletion time and lock badge; NO readable title visible (FR5.2, FR5.3).
- [x] When user attempts to view secure note details in trash, app shows message: "Note is locked and cannot be previewed until restored and unlocked" (FR5.3).
- [x] Lock badge is primary visual indicator for secure notes in trash (FR5.3).
- [x] Test cases 6.1-6.5 pass (trash display semantics).

**Restore and Delete (FR5.4-5.7)**:
- [x] User can restore any trashed note back to active list (FR5.4).
- [x] Restoring secure note requires active unlocked session; restore blocked if app locked (FR5.5).
- [x] User can permanently delete any trashed note (FR5.6).
- [x] Permanently deleting secure note wipes ciphertext and all linked attachments; unrecoverable (FR5.7).
- [x] All trash operations use ACID transactions (NFR5.1).
- [x] Test cases 6.6-6.14 pass (restore and permanent delete).

---

## 5. Voice and Image Attachments (Phase 4)

**Voice Capture (FR6.1-6.3, FR6.2)**:
- [x] Editor top bar provides voice capture button (FR6.1).
- [x] Recording <10 minutes and <50 MB saved with complete file protection (FR6.2).
- [x] **Protected-recording write operation (FR6.2)**: Occurs only after recording completes and before audio linked to note.
- [x] **Security mode inheritance (FR6.2)**: Recording in normal note stored unencrypted with OS-level protection.
- [x] **Security mode inheritance (FR6.2)**: Recording in secure note stored encrypted, inheriting note's encryption.
- [x] Recording >10 minutes rejected with message "recording exceeds 10 minute limit" (FR6.3).
- [x] Recording >50 MB rejected with message "recording exceeds 50 MB limit" (FR6.3).
- [x] Transcription runs asynchronously without blocking UI (NFR2.1).
- [x] Test cases 7.1-7.12 pass (voice capture with size limits and async transcription).

**Image Attachment (FR13.1-13.3)**:
- [x] Editor provides attach image button (FR13.1).
- [x] User can select local image file from file system (no camera, no remote URL; FR13.1).
- [x] Attached image stored with complete file protection (FR13.2).
- [x] **Security mode inheritance (FR13.2)**: Image in normal note stored unencrypted with OS protection.
- [x] **Security mode inheritance (FR13.2)**: Image in secure note stored encrypted, matching note's security mode.
- [x] Image >20 MB rejected with message "image exceeds 20 MB limit" (FR13.3).
- [x] Attachment record includes type (image | recording) and noteId.
- [x] Test cases 8.1-8.11 pass (image attachment with size limits and security mode inheritance).

**Confidentiality Boundary** (NFR3.1):
- [x] No decrypted attachment content written to disk, logs, or caches (except in-memory session during unlock) (NFR3.1).
- [x] Test cases 20.1-20.11 pass (confidentiality boundary verification).

---

## 6. Session and Auto-Lock Management (Phase 4)

**First-Launch Initialization (FR1.1)**:
- [x] On first launch, app enters dedicated initialization branch before any note data stored (FR1.1).
- [x] First-launch branch presents passphrase creation dialog (not passphrase entry) (FR1.1).
- [x] All note operations blocked until passphrase created and confirmed (FR1.1).
- [x] Test case 1.1-1.6 pass (first-launch initialization).

**Passphrase and Biometric Unlock (FR1.2-1.6)**:
- [x] On subsequent launches, app requires passphrase to start session (FR1.2).
- [x] After successful passphrase unlock, user can optionally enable biometric unlock (FR1.3).
- [x] Biometric unlock falls back to passphrase if biometrics unavailable, rejected, or fail 3 times (FR1.4).
- [x] If biometric hardware unavailable after enrollment, passphrase fallback auto-activates (FR1.5).
- [x] Consecutive biometric failure counter resets to 0 after any successful unlock (FR1.6).
- [x] Test cases 2.11-2.17 pass (biometric unlock with fallback).

**Unlock Performance** (NFR1.1-1.3):
- [x] Unlock with 1,000 notes completes within 1 second on target hardware (NFR1.1; Test 19.1).
- [x] Unlock with 10,000 notes completes within 2 seconds on target hardware (NFR1.2; Test 19.2).
- [x] Passphrase entry time excluded from measurements (NFR1.3; Test 19.3).
- [x] Benchmark runs on Apple Silicon M-series and Intel i5/i7 6th gen+ with 8 GB RAM and SSD.

**Auto-Lock (FR7.1-7.5, FR7.3)**:
- [x] App auto-locks after configured inactivity timeout (default 5 minutes) with no user input (FR7.1).
- [x] App auto-locks when OS sleeps or app backgrounded (FR7.2).
- [x] Background operations (export, key rotation) do not count as user activity and do not reset inactivity timer (FR7.3).
- [x] When inactivity timer expires during active background operation, lock proceeds immediately after operation completes (FR7.3).
- [x] On lock, all in-memory key material cleared before re-authentication required (FR7.4).
- [x] If auto-lock fires during secure note editing, draft encrypted and persisted before lock completes (FR7.5).
- [x] Test cases 9.1-9.13 pass (auto-lock and draft persistence).

**UI Responsiveness** (NFR2.1-2.2):
- [x] Encryption, database I/O, transcription, and plugin action execution run asynchronously (NFR2.1).
- [x] UI thread never blocked by heavy operations (NFR2.1).
- [x] App maintains 60 FPS responsiveness during note editing, encryption saves, transcription, plugin actions (NFR2.2).
- [x] Frame-time profile shows no significant drops (Test 19.4-19.7).

---

## 7. Title Search (Phase 4)

**Normal Title Search (FR12.1-12.2)**:
- [x] Workspace top bar provides title search input (FR12.1).
- [x] Normal note titles searchable directly from stored title data (FR12.2).
- [x] Results filtered by query text; update in real-time (FR12.1, FR12.2).
- [x] Normal title search works at any time (locked or unlocked) (FR12.2).

**Secure Title Search (FR12.3-12.6, NFR3.2)**:
- [x] Secure note titles remain encrypted at rest and not stored as plaintext for indexing (FR12.3).
- [x] While unlocked, secure note titles searchable using in-memory decrypted title matching (FR12.4).
- [x] Search uses in-memory session cache only, never reads from persistent storage (FR12.3, FR12.4).
- [x] On lock, all in-memory decrypted secure title search data cleared immediately (FR12.5, NFR3.2).
- [x] While locked, secure notes excluded from search results (FR12.6).
- [x] No decrypted titles cached to disk or shared state (NFR3.2).
- [x] Test cases 12.1-12.10 pass (title search with secure handling).

---

## 8. Settings and Configuration (Phase 5)

**Settings Management (FR10.1-10.2)**:
- [x] User can configure lock timeout value in settings (FR10.1).
- [x] User can enable/disable telemetry opt-in in settings (FR10.1).
- [x] User can toggle global plugin enable/disable in settings (FR10.1).
- [x] Disabling plugins prevents all plugins from running without removing installed records (FR10.1).
- [x] All settings changes validated before commit (FR10.2).
- [x] Invalid values (negative timeout, out-of-range) rejected with user-visible message (FR10.2).
- [x] Test cases 15.1-15.11 pass (settings validation and application).

**Telemetry Privacy (NFR7.1-7.2)**:
- [x] Telemetry is opt-in; no telemetry sent when disabled (NFR7.1).
- [x] When enabled, telemetry limited to non-sensitive operational metrics (NFR7.1).
- [x] Telemetry excludes note text, note titles, and content-derived data (NFR7.2).
- [x] Test cases 15.5-15.8 pass (telemetry opt-in and privacy validation).

---

## 9. Passphrase Change and Key Rotation (Phase 5)

**Passphrase Change (FR8.1-8.6, NFR5.1-5.3)**:
- [x] User can change master passphrase from settings (FR8.1).
- [x] Changing passphrase triggers re-encryption of all secure notes and attachments with new key (FR8.2, NFR5.1).
- [x] Old key material retained until all secure records confirmed re-encrypted; only then removed (FR8.3).
- [x] Normal notes unaffected by passphrase change (FR8.6).
- [x] After successful rotation, unlock with new passphrase succeeds and secure notes accessible (FR8.2).

**Partial Migration Recovery (FR8.4, NFR5.3)**:
- [x] If re-encryption interrupted (crash, force quit), app detects partial migration on next launch (FR8.4).
- [x] App attempts to complete remaining re-encryption using retained old and new keys (FR8.4).
- [x] If completion succeeds, new passphrase becomes active and user informed (FR8.4, NFR5.3).
- [x] If completion fails (write error, disk full), all partially migrated records rolled back to old key and previous passphrase restored (FR8.4, NFR5.3).
- [x] User informed of rotation outcome (success or rollback) before normal access granted (FR8.4, NFR5.3).

**Identical Key Rejection (FR8.5)**:
- [x] If new passphrase derives identical key to existing one, app rejects change with error (FR8.5).
- [x] Error message: "New passphrase produces same key as current; please choose a different passphrase" (FR8.5).
- [x] No re-encryption or storage write performed (FR8.5).
- [x] User prompted to choose different passphrase (FR8.5).

**Test Coverage**:
- [x] Test cases 10.1-10.15 pass (passphrase change, partial migration recovery, identical key rejection).

---

## 10. Export and Import (Phase 5)

**Export (FR9.1, NFR3.1, NFR5.1)**:
- [x] User can initiate export from settings (FR9.1).
- [x] Export produces encrypted archive containing all note records and metadata (FR9.1).
- [x] Archive tagged with current schema version (FR9.1).
- [x] Archive protected by user's passphrase (encrypted under passphrase) (FR9.1).
- [x] No decrypted content visible in export file; plaintext encrypted before archive assembly (FR9.1, NFR3.1).
- [x] Export includes both normal and secure notes (FR9.1).

**Import Validation (FR9.2, NFR5.1)**:
- [x] User can initiate import from settings (FR9.1).
- [x] Import validates archive signature, schema version, and passphrase before data written (FR9.2).
- [x] Incompatible schema rejected with error identifying mismatch (FR9.2).
- [x] Wrong passphrase rejected and no data written (FR9.2).

**Atomic Import and Recovery (FR9.3-9.4, NFR5.1-5.3)**:
- [x] Import is all-or-nothing: entire operation wrapped in ACID transaction (FR9.4, NFR5.1).
- [x] If storage exhausted mid-import, entire operation rolls back with no partial state (FR9.4, NFR5.1).
- [x] User informed to free storage and retry (FR9.4).
- [x] ID conflicts in imported archive → imported notes receive new unique IDs (FR9.3).
- [x] Existing local notes never overwritten (FR9.3).
- [x] Corrupt import records detected, error reported, full rollback (NFR5.3).

**Test Coverage**:
- [x] Test cases 11.1-11.14 pass (export validation, import atomicity, ID conflict handling).

---

## 11. Simple Plugin Support (Phase 5)

**Plugin Installation and Validation (FR11.1-11.2)**:
- [x] User can install plugin from local package file (FR11.1).
- [x] On installation, app validates plugin manifest structure (FR11.2).
- [x] Manifest validation checks: `pluginId`, name, version, `supportedAppVersion`, `entryAction`, `capabilities` (FR11.2).
- [x] Invalid manifest rejected with clear error message (FR11.2).
- [x] Plugin metadata persisted: enabled state, install path/hash, last run status, last error (FR11.8).

**Plugin Management (FR11.3)**:
- [x] User can enable, disable, and remove plugins from plugin management UI (FR11.3).
- [x] Disabled plugins do not run (FR10.1, global toggle also disables all).
- [x] Installed plugin records retained when disabled (FR10.1).

**Plugin Execution (FR11.4-11.7, NFR2.1)**:
- [x] Plugins run only through host API (`PluginService`); direct repository access blocked (FR11.4).
- [x] App supports at least one plugin action: text transformation on current note content (FR11.5).
- [x] On success, plugin result applied through normal save flow (FR11.6).
- [x] Secure note results re-encrypted after plugin transformation (FR11.6).
- [x] On failure, timeout, or exception, app preserves current note state, shows error, and remains responsive (FR11.7).
- [x] Plugin execution async, no UI blocking (NFR2.1).
- [x] Plugin failure audit-logged without sensitive content (NFR6.3).

**Test Coverage**:
- [x] Test cases 14.1-14.18 pass (plugin installation, execution, failure handling, management).

---

## 12. Confidentiality and Security Boundaries (All Phases)

**Data Confidentiality (NFR3.1-3.2)**:
- [x] Decrypted secure note content never written to disk (NFR3.1).
- [x] Decrypted content never written to logs (NFR3.1).
- [x] Decrypted content never written to caches except in-memory search cache during unlock (NFR3.1).
- [x] Decrypted content never included in exports (NFR3.1).
- [x] Decrypted titles held in memory only during active unlocked session (NFR3.2).
- [x] In-memory secure title cache cleared immediately on lock (NFR3.2).
- [x] Logging sanitized to exclude decrypted content, titles, credentials (NFR3.1, NFR6.3).
- [x] UI display of decrypted content transient in memory; cleared/masked on lock (NFR3.1, NFR3.2).
- [x] Plugin interface controlled: plugins receive content only through host API with user consent (NFR3.1).
- [x] Test cases 20.1-20.11 pass (confidentiality boundary verification).

**Architecture Boundary Enforcement (Section 4.1 of Architecture)**:
- [x] UI never performs encryption or direct database writes (Architecture §4).
- [x] Core services never depend on SwiftUI views (Architecture §4).
- [x] Repositories store standard notes as-is and secure notes as ciphertext only (Architecture §4).
- [x] Platform wrappers isolate OS APIs from UI and repository layers (Architecture §4).
- [x] Secure-note decisions in `SecureNotePolicyService`, not view logic (Architecture §4).
- [x] Secure title search never reads plaintext from storage (Architecture §4).
- [x] Plugins access repositories only through controlled host API (Architecture §4).
- [x] Plugin failures contained and surfaced as user errors (Architecture §4).

---

## 13. Accessibility and Internationalization (Phase 5)

**Keyboard Navigation (NFR8.1)**:
- [x] All core workflows operable with keyboard only (no mouse/trackpad required) (NFR8.1).
- [x] Unlock, note browsing, editing, deletion, trash, settings support keyboard (NFR8.1).
- [x] All interactive elements have visible focus indicators (NFR8.1).
- [x] Test cases 16.1-16.5 pass (keyboard-only navigation).

**VoiceOver Support (NFR8.1)**:
- [x] All core workflows navigable with VoiceOver (screen reader) (NFR8.1).
- [x] Button labels, field labels, status messages VoiceOver-compatible (NFR8.1).
- [x] Test cases 16.6-16.9 pass (VoiceOver navigation and labeling).

**Internationalization (NFR9.1-9.2)**:
- [x] App ships in English as default locale (NFR9.1).
- [x] All UI strings, messages, documentation in English (NFR9.1).
- [x] Codebase uses localization architecture supporting new language addition without rewriting features (NFR9.2).
- [x] Smoke test: Add one non-English locale (e.g., Spanish, French) → strings localized, features work (NFR9.2).
- [x] Test cases 17.1-17.4 pass (English-first release, localization extensibility).

---

## 14. Testing and Quality Metrics (All Phases)

**Test Coverage**:
- [x] ≥95% code coverage for core services: `NoteService`, `EncryptionService`, `KeyManager`, `SecureNotePolicyService`, `ProtectedTrashService`, `NoteSearchService`, `ExportImportService` (All phases).
- [x] All 20 test sections with 200+ individual test cases pass (All phases).
- [x] Regression test suite covers unlock, CRUD, trash, export/import, key rotation (Phases 2-5).
- [x] Integration tests verify feature interactions: secure note + attachment + auto-lock + key rotation (Phase 5).
- [x] Manual testing: Accessibility, VoiceOver, plugin failure modes, UI responsiveness (Phase 5).

**Performance Verification**:
- [x] Unlock with 1,000 notes ≤1 second (NFR1.1; Test 19.1).
- [x] Unlock with 10,000 notes ≤2 seconds (NFR1.2; Test 19.2).
- [x] Frame time during note editing, encryption saves, transcription ≥60 FPS (NFR2.2; Test 19.4-19.7).
- [x] Benchmarks run on Apple Silicon M-series and Intel i5/i7 6th gen+ (NFR1.1, NFR1.2).

**Security and Integrity**:
- [x] No decrypted content leakage detected in logs, caches, exports (NFR3.1).
- [x] All ACID transactions validated with failure/rollback scenarios (NFR5.1).
- [x] Authenticated encryption (AES-GCM) validated with test vectors (NFR4.1).
- [x] Rate-limiting progression verified (NFR6.1).
- [x] Audit logging complete and sanitized (NFR6.2, NFR6.3).
- [x] Corruption recovery paths tested (NFR5.3).

**Documentation**:
- [x] User guide covering all core workflows (unlock, note CRUD, secure mode, trash, settings, plugins).
- [x] Technical architecture documentation (Architecture.md) finalized.
- [x] API reference for plugin host API (`PluginService`).
- [x] Release notes documenting all features, performance metrics, and known limitations.

---

## 15. Release Readiness (Week 14)

**Final Verification**:
- [x] All 20 test sections (200+ cases) pass on target hardware.
- [x] Performance benchmarks meet all NFR targets.
- [x] Security audit: Penetration testing, confidentiality boundary verification complete.
- [x] Localization smoke test (non-English locale) passes.
- [x] Build optimization and app signing complete.
- [x] Code review complete (≥2 reviewers per component).

**Deliverables**:
- [x] Production-ready MVP binary (signed, optimized).
- [x] Complete test coverage report (≥95% core services).
- [x] User documentation and release notes.
- [x] Technical reference (Architecture, API, recovery procedures).

---

## Summary

**Total Requirements**: 96 (76 FR + 20 NFR)
**All Fully Traced**: Yes (100% coverage per Traceability.md)
**All Mapped to Test Cases**: Yes (200+ cases across 20 test sections)
**All Integrated in Done Criteria**: Yes

**MVP is complete when all criteria above verified and test metrics achieved.**