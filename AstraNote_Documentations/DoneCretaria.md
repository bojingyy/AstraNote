# AstraNotes Done Criteria

This document defines, phase by phase, the conditions that must hold before AstraNotes is considered ready to ship. It mirrors the five-phase sequence in [ImplementationPlan.md](ImplementationPlan.md) and the requirement set in [Requirement.md](Requirement.md), and every criterion below is verified by one or more cases in [TestSteps.md](TestSteps.md). A phase is "done" only when every criterion in its section is met; the MVP is done only when every phase, plus Deployment Readiness, is met.

Total scope: **83 requirements (68 FR + 15 NFR)**, all traced to the test cases referenced below.

---

## 1. Phase 1 — Persistence Foundation and Cryptographic Core

- [ ] `DatabaseProvider` performs every mutation through a clone-mutate-commit-or-discard transaction, and a thrown error during a transaction leaves `DatabaseState` byte-for-byte unchanged (NFR5.1; Test 16.3).
- [ ] `DatabaseState` and persisted record types carry a `schemaVersion` field that export/import compatibility checks rely on (FR9.2).
- [ ] `KeyManager` derives keys via PBKDF2-HMAC-SHA256 at 100,000 iterations and verifies passphrases without ever persisting derived key material (NFR1.1).
- [ ] `EncryptionService` produces AES-256-GCM ciphertext, nonce, and authentication tag, and a tampered tag/nonce/ciphertext fails verification explicitly (FR3.3, NFR4.1; Test 16.1).
- [ ] The escalating lockout (30s → doubling → 60-minute cap) fires on the documented failure cadence and every lockout event is audit-logged (NFR6.1, NFR6.2; Test 2.12-2.15).
- [ ] `AuditLogger` entries contain event names and small metadata only — never passphrases, titles, or note content (NFR6.3; Test 2.16).
- [ ] `TimeProvider` is the single UTC time source consulted anywhere a timestamp is recorded.
- [ ] AES-GCM and PBKDF2 implementations pass standardized test vectors before any feature is layered on top of them.

**Phase 1 is done when**: every crypto primitive passes its test vectors, every induced mid-transaction failure leaves the prior state intact, and the lockout/audit paths behave exactly as specified — all verified before Phase 2 work begins.

---

## 2. Phase 2 — Repositories and Note/Subject Lifecycle

**Repository layer**:
- [ ] `NoteRepository`, `SubjectRepository`, `AttachmentRepository`, and `SettingsRepository` are each scoped to a single record family and route every mutation through `DatabaseProvider` transactions.

**Normal Note Lifecycle (FR2.1-2.5)**:
- [ ] A note can be created, edited, and deleted with text content, with image and recording attachments optional (FR2.1; Test 3.1).
- [ ] Normal notes are persisted as plain text with no encryption applied (FR2.2; Test 3.2).
- [ ] Each note retains a stable unique identifier across every edit (FR2.3; Test 3.3, 3.7).
- [ ] An induced write failure rolls back and leaves the previous record unchanged (FR2.4; Test 3.4, 3.8).
- [ ] Deleting a normal note moves it and its attachments to protected trash in one ACID transaction, and a failed move leaves the note intact (FR2.5; Test 3.9, 3.12).
- [ ] Test cases 3.1-3.12 pass in full.

**Subject Groups (FR14.1-14.6)**:
- [ ] A subject group can be created with a non-empty, unique name; empty or duplicate names are rejected (FR14.1; Test 13.1-13.4).
- [ ] A subject group can be renamed under the same non-empty/unique validation (FR14.2; Test 13.5-13.6).
- [ ] An empty group deletes without confirmation; a non-empty group prompts for confirmation first (FR14.3; Test 13.7-13.8).
- [ ] Deleting a group leaves its notes intact and ungrouped, never deleted (FR14.4; Test 13.8).
- [ ] A note can be assigned to a group and moved between groups (FR14.5; Test 13.9-13.10).
- [ ] The sidebar shows every subject group plus an "All Notes" view spanning every note (FR14.6; Test 13.11).
- [ ] Test cases 13.1-13.11 pass in full.

**Phase 2 is done when**: a note can be created, edited, deleted, and reloaded with identical content and identifier; a failed write leaves the previous record intact; and subject groups can be created, renamed, deleted, and reassigned exactly as specified — all exercised end to end through `NoteService`/`SubjectService`.

---

## 3. Phase 3 — Secure Notes, Step-Up Authentication, and Protected Trash

**First-Launch Initialization (FR1.1)**:
- [ ] First launch enters a dedicated initialization branch, presents a passphrase-creation dialog, and blocks every note operation until the passphrase is created and confirmed (FR1.1; Test 1.1-1.6).

**Workspace Access and Step-Up Authentication (FR1.2, FR3.8)**:
- [ ] On every later launch, the workspace opens directly with no whole-app unlock screen (FR1.2; Test 2.1).
- [ ] Normal notes are usable immediately, with no authentication step (FR1.2; Test 2.2).
- [ ] Opening, saving, or attaching to a secure note triggers the step-up authentication prompt at the moment the key is needed, and the triggering action resumes automatically on success (FR3.8; Test 2.3-2.6).
- [ ] An incorrect passphrase at the prompt is rejected with the prompt remaining open for retry (FR1.4; Test 2.7).

**Secure Note Lifecycle (FR3.1-3.8)**:
- [ ] Secure mode can be toggled from the editor toolbar with no expiration or scheduling fields presented (FR3.1, FR3.2; Test 4.1).
- [ ] A secure note can carry a custom display alias (`secureTitleAlias`), persisted alongside its ciphertext (FR12.3; Test 4.2).
- [ ] On save, title and content are encrypted on-device and the persisted record contains only ciphertext, nonce, tag, and salt (FR3.3; Test 4.3-4.4).
- [ ] The secure note's identifier remains stable across edits, and a failed write rolls back to the previous ciphertext (FR3.4, FR3.5; Test 4.5-4.6).
- [ ] Corrupted ciphertext, a mutated authentication tag, or an incorrect key each surface a clear error while leaving the stored record untouched (FR3.6, NFR4.1, NFR4.2; Test 4.7-4.9).
- [ ] Decrypted content is cleared from memory on navigate-away, and never appears in logs, caches, or exports (NFR3.1, NFR3.2; Test 4.10-4.11).
- [ ] Deleting a secure note moves the encrypted record and its attachments to trash in one transaction (FR3.7; Test 4.12).
- [ ] Test cases 4.1-4.12 pass in full.

**Secure Note Retention (FR4.1-4.2)**:
- [ ] A secure note remains in the active list indefinitely, across edits and relaunches, until the user deletes it (FR4.1; Test 5.1-5.2).
- [ ] No expiration, sweeping, launch-time-checkpoint, or expiry-notification mechanism exists, and device-clock changes have no effect on secure-note availability (FR4.2; Test 5.3-5.4).
- [ ] Test cases 5.1-5.4 pass in full.

**Protected Trash (FR5.1-5.7)**:
- [ ] Every deleted note, normal or secure, lands in protected trash rather than being deleted immediately (FR5.1).
- [ ] Trash shows normal notes with title and deletion time, and secure notes with deletion time and a lock badge sourced from the display alias — never a decrypted title (FR5.2, FR5.3; Test 6.1-6.2).
- [ ] Requesting details on a locked trash item returns the fixed "locked, cannot be previewed" message with no decryption attempted (FR5.3; Test 6.3).
- [ ] Any trashed note can be restored to the active list with its original content (FR5.4; Test 6.4-6.5).
- [ ] Restoring a secure note while locked is blocked with a clear message (FR5.5; Test 6.6).
- [ ] Permanent deletion removes a normal note's record and wipes a secure note's ciphertext and attachments beyond recovery (FR5.6, FR5.7; Test 6.7-6.9).
- [ ] Test cases 6.1-6.9 pass in full.

**Phase 3 is done when**: a secure note can be created with a custom alias, encrypted on save, and reopened only after step-up authentication; deleting it moves the encrypted record and its attachments to trash atomically; and the trash never reveals a decrypted title under any circumstance.

---

## 4. Phase 4 — Session Lock, Search, Attachments, and Workspace Feedback

**Title Search (FR12.1-12.5)**:
- [ ] The top-bar search field filters the note list as the query changes, matching normal-note titles directly against stored plaintext (FR12.1, FR12.2; Test 12.1-12.2).
- [ ] Secure notes are matched against their `secureTitleAlias` only, with the search path never decrypting or holding decrypted titles in memory (FR12.3, FR12.4, NFR3.2; Test 12.3-12.4).
- [ ] Search results for secure-note aliases are identical whether the session is locked or unlocked (FR12.5; Test 12.5-12.6).
- [ ] Test cases 12.1-12.6 pass in full.

**Session Lock (FR7.1-7.4)**:
- [ ] Every relaunch begins locked, with in-memory key material never persisted to or restored from disk (FR7.1; Test 9.1-9.2).
- [ ] Backgrounding the app or an OS-sleep event clears in-memory key material immediately, while user-interaction and foreground/wake events are recorded without triggering a lock (FR7.2; Test 9.3-9.5).
- [ ] An immediate-lock trigger that fires during a tracked background operation (export, rotation) is deferred until that operation completes, then applied (FR7.3; Test 9.6).
- [ ] After any lock, normal notes remain fully usable and any secure-note action re-triggers step-up authentication (FR7.4; Test 9.7).
- [ ] No inactivity-timeout mechanism and no draft-persistence-on-lock behavior exist anywhere in the lock path (FR7.1-FR7.4; Test 9.8).
- [ ] Test cases 9.1-9.8 pass in full.

**Voice Capture (FR6.1-6.3)**:
- [ ] The editor's top bar records audio via the system microphone and attaches the result to the current note (FR6.1; Test 7.1).
- [ ] The recording is written to app-container storage as a plain file only after it completes, carrying an `isEncrypted` bookkeeping flag that records — but does not enforce — the owning note's secure-mode intent; confidentiality at rest rests on the host's disk-level encryption (FR6.2; Test 7.2-7.4).
- [ ] Recordings over 50 MB are rejected before storage with a size-limit message; a recording at exactly 50 MB succeeds (FR6.3; Test 7.5-7.6).
- [ ] Test cases 7.1-7.6 pass in full.

**Image Attachment (FR13.1-13.3)**:
- [ ] The editor's attach-image action opens a local file picker only — no camera capture or remote URL sources (FR13.1; Test 8.1).
- [ ] The selected image is stored as a plain file carrying the same bookkeeping flag and disk-level confidentiality model as voice recordings (FR13.2; Test 8.2-8.3).
- [ ] Images over 20 MB are rejected before storage with a size-limit message; an image at exactly 20 MB succeeds (FR13.3; Test 8.4-8.5).
- [ ] Test cases 8.1-8.7 pass in full.

**Workspace Feedback and Settings, First Pass (FR10.1-10.3)**:
- [ ] Operation feedback (success, warning, error) appears as a transient pop-up that auto-dismisses after about five seconds, never as inline text under the editor (FR10.3; Test 15.4-15.5).
- [ ] Settings exposes exactly two configurable items — global plugin enablement and biometric-unlock enablement — with no telemetry or lock-timeout options, and rejects invalid values before commit (FR10.1, FR10.2; Test 15.1-15.3).
- [ ] Test cases 15.1-15.5 pass in full.

**Phase 4 is done when**: alias-based search returns identical, lock-state-independent results; backgrounding the app clears in-memory key material immediately (or as soon as an in-flight export/rotation finishes); voice and image attachments respect their size limits and persist as plain files with correct bookkeeping flags; and user feedback appears exclusively as auto-dismissing toasts.

---

## 5. Phase 5 — Passphrase Rotation, Backup, Plugins, and Biometrics

**Passphrase Change and Key Rotation (FR8.1-8.6)**:
- [ ] The passphrase can be changed at any time while unlocked (FR8.1; Test 10.1).
- [ ] Rotation re-encrypts every secure note and commits the new credentials together in a single atomic transaction, with no observable intermediate state (FR8.2, FR8.3; Test 10.2-10.3).
- [ ] Normal notes and attachment files are untouched by rotation (FR8.6; Test 10.4).
- [ ] A forced termination mid-rotation leaves the database exactly as it was under the original credentials, and the next unlock detects, clears, and logs any stale in-flight marker with no user action required (FR8.4, NFR5.2; Test 10.5-10.6).
- [ ] A new passphrase that derives an identical key is rejected before any write occurs, with the user prompted to choose differently (FR8.5; Test 10.7).
- [ ] Test cases 10.1-10.7 pass in full.

**Export and Import (FR9.1-9.4)**:
- [ ] Export produces a single encrypted, schema-tagged archive with sensitive and runtime-only fields stripped before encryption (FR9.1; Test 11.1-11.2).
- [ ] Import accepts archives whose schema version is not newer than local, and rejects newer ones with a mismatch error (FR9.2; Test 11.3-11.4).
- [ ] Conflicting identifiers are remapped to fresh IDs by default, with cross-references rewritten consistently and existing data untouched; strict mode rejects on any collision (FR9.3; Test 11.5-11.6).
- [ ] An induced failure during decoding, decryption, or merge rolls back the entire import, leaving the prior database state intact and showing a descriptive error (FR9.4, NFR5.1, NFR5.2; Test 11.7).
- [ ] Test cases 11.1-11.7 pass in full.

**Biometric Authentication (FR1.3-1.5)**:
- [ ] After at least one successful authentication, biometric unlock can be enabled from Settings (FR1.3; Test 2.8).
- [ ] The authentication prompt co-presents passphrase entry and the biometric action, and a declined or failed biometric attempt leaves the passphrase field usable in the same prompt (FR1.4; Test 2.9-2.10).
- [ ] Unavailable biometric hardware or enrollment surfaces a descriptive error (`biometricUnavailable` / `biometricUnlockDisabled`) without disrupting the passphrase path (FR1.5; Test 2.11).
- [ ] Test cases 2.8-2.11 pass in full.

**Simple Plugin Support (FR11.1-11.7)**:
- [ ] A plugin can be installed from a local package via the file picker, with its manifest validated against `pluginId`, `displayName`, `version`, and `capabilities` (FR11.1, FR11.2; Test 14.1-14.2).
- [ ] Malformed manifests, unreadable bundles, and duplicate plugin IDs are each rejected with a descriptive error (FR11.2; Test 14.3).
- [ ] Persisted plugin metadata contains exactly: plugin ID, display name, version, capabilities, enabled state, and install timestamp, with bundle bytes stored separately and keyed by plugin ID (FR11.7; Test 14.4).
- [ ] Plugins can be enabled, disabled, and removed from the management UI, with confirmation required before removal; the global toggle disables all plugins without discarding their records (FR11.3, FR10.1; Test 14.5-14.6).
- [ ] `execute` enforces global- and per-plugin-enablement checks, and a failing, timing-out, or throwing handler surfaces a typed error and is audit-logged without crashing the host or corrupting note data (FR11.5, FR11.6, NFR6.3; Test 14.7-14.8).
- [ ] No UI control triggers plugin execution in this release — the gated execution surface exists only at the service layer (FR11.5; Test 14.9).
- [ ] Plugins interact with notes only through the host API and never touch repositories directly (FR11.4; Test 14.10).
- [ ] Test cases 14.1-14.10 pass in full.

**Phase 5 is done when**: changing the passphrase re-encrypts every secure note atomically and survives a simulated mid-rotation termination; export followed by import on a clean database reproduces the original note set; plugins install, run only through the gated host API, and fail safely on timeout; and biometric unlock falls back to the passphrase seamlessly.

---

## 6. Cross-Cutting: Confidentiality, Integrity, and Reliability

**Confidentiality (NFR3.1-3.2, NFR6.3, NFR7.1)**:
- [ ] Persisted secure-note records contain only ciphertext, authentication tag, salt, and the display alias — confirmed by direct storage inspection (NFR3.1; Test 18.1).
- [ ] No decrypted content appears in audit logs, caches, or export archives at any point (NFR3.1; Test 18.2).
- [ ] Decrypted content is cleared from memory on navigate-away and on lock, and the search path never holds decrypted titles (NFR3.2; Test 18.3-18.4).
- [ ] Audit-log entries for authentication failures, rotation outcomes, plugin lifecycle events, and export/import completions contain event names and small metadata only (NFR6.3; Test 18.5).
- [ ] A full end-to-end feature pass produces zero telemetry or analytics network/instrumentation activity (NFR7.1; Test 18.6).
- [ ] Test cases 18.1-18.6 pass in full.

**Data Integrity and Reliability (NFR4.1-4.2, NFR5.1-5.2)**:
- [ ] Tampered ciphertext, nonce, or authentication tag fails AES-GCM verification explicitly, surfaces a clear error, and leaves the stored record byte-for-byte unchanged (NFR4.1, NFR4.2; Test 16.1-16.2).
- [ ] Induced mid-transaction failures during note edits/deletions, passphrase rotation, and backup import each roll back to the prior `DatabaseState` with no partial writes observable (NFR5.1; Test 16.3).
- [ ] The interrupted-rotation and interrupted-import recovery scenarios each reach a consistent, usable state without manual intervention (NFR5.2; Test 16.4-16.5).
- [ ] Test cases 16.1-16.5 pass in full.

---

## 7. Deployment Readiness

**Performance (NFR1.1-1.3, NFR2.1-2.2)**:
- [ ] Authentication completes in approximately 1 second on Apple Silicon and Intel i5/i7 (6th gen+) reference hardware, with manual typing time excluded from the measurement (NFR1.1, NFR1.3; Test 17.1, 17.3).
- [ ] Authentication latency is statistically constant across 100-, 1,000-, and 10,000-note databases (NFR1.2; Test 17.2).
- [ ] Encryption, database I/O, and plugin execution never block the main UI thread, and 60 FPS is sustained during normal workflows (NFR2.1, NFR2.2; Test 17.4-17.5).
- [ ] Test cases 17.1-17.5 pass in full.

**Regression and Coverage**:
- [ ] The full regression suite passes across `AstraCoreTests`, `AstraDataTests`, `AstraPlatformTests`, and `AstraIntegrationTests`.
- [ ] The documented code-coverage target is met for `AstraCore` and `AstraData` services.
- [ ] Integration tests exercise cross-feature flows that combine secure notes, attachments, session locking, search, and passphrase rotation.

**Security Review**:
- [ ] The full confidentiality-boundary inspection (section 6 above) is re-run as a final pass and returns a clean result.
- [ ] Rate-limiting and lockout behavior is re-verified end to end (NFR6.1, NFR6.2).
- [ ] Rotation- and import-recovery walkthroughs are re-run as a final pass (NFR5.2).

**Documentation and Release Packaging**:
- [ ] `README.md`, the architecture and requirements cross-references, and user-facing guides are finalized.
- [ ] Release notes map every shipped capability to the requirement IDs it satisfies.
- [ ] The build is signed and packaged for release.

**Deployment Readiness is done when**: every NFR benchmark is met on reference hardware, the full regression suite is green, the confidentiality and recovery passes are clean, and documentation and release artifacts are complete.

---

## Summary

**Total requirements**: 83 (68 FR + 15 NFR), every one traced to a phase above and to one or more cases in TestSteps.md.
**Total test cases**: 18 sections covering every functional and non-functional requirement in Requirement.md.
**MVP is done when**: every checklist item in sections 1 through 7 above is verified, every referenced test case passes, and every NFR benchmark is achieved on the documented reference hardware.
