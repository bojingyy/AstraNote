## Implementation Plan

This plan sequences the build of AstraNotes against the requirements in [Requirement.md](Requirement.md), the user stories in [UserStories.md](UserStories.md), and the layered design in [Architecture.md](Architecture.md). Work proceeds bottom-up through the module dependency chain — `AstraData` → `AstraCore` → `AstraPlatform` → `AstraUI` — so that every feature is built on a tested, transactionally-sound foundation before its UI is wired up. Each phase ends with an integration checkpoint that must pass before the next phase begins.

---

### Phase 1: Persistence Foundation and Cryptographic Core (Weeks 1–3)
**Goal**: Stand up the transactional data layer and the cryptographic primitives every other feature depends on.

**Components**:
- `DatabaseProvider`: an actor-isolated, in-process store that holds `DatabaseState` in memory, applies mutations through a copy-on-write `transaction` closure (clone → mutate → commit-or-discard), and persists committed snapshots to disk as JSON. This gives every write full ACID semantics without an external database engine (NFR5.1).
- `DatabaseState` and the persisted record types in `PersistenceModels.swift`, including the `schemaVersion` field that anchors export/import compatibility checks (FR9.2).
- Core domain models: `Note`, `EncryptedPayload`, `Attachment`, `KeyMaterial`, `AppSettings`, `PluginManifest`.
- `KeyManager`: PBKDF2-HMAC-SHA256 passphrase derivation (100,000 iterations), credential storage and verification, in-memory key lifecycle, and the escalating rate-limit lockout (NFR6.1).
- `EncryptionService`: AES-256-GCM authenticated encryption with HKDF-derived per-note keys, producing ciphertext, nonce, and authentication tag (FR3.3, NFR4.1).
- `AuditLogger` and `TimeProvider`: sanitized event logging (event names and small metadata only — never content, titles, or credentials; NFR6.3) and a single UTC time source for all timestamps.

**Testing**: Transaction commit/rollback unit tests (including induced mid-transaction failures), AES-GCM test vectors, PBKDF2 derivation correctness, lockout escalation timing, audit-log content sanitization checks.

**Phase checkpoint**: All crypto primitives pass standardized test vectors; a transaction that throws leaves `DatabaseState` byte-for-byte unchanged; lockout reaches the documented 30 s → 60 min progression.

---

### Phase 2: Repositories and Note/Subject Lifecycle (Weeks 4–5)
**Goal**: Implement the repository layer and the CRUD services for normal notes and subject groups — the simplest end-to-end vertical slice through the architecture.

**Components**:
- `NoteRepository`, `SubjectRepository`, `AttachmentRepository`, `SettingsRepository`: thin, `DatabaseProvider`-backed repositories, each scoped to one record family.
- `NoteService`: orchestrates note save/load, routing normal notes to plaintext storage and secure notes through `EncryptionService` (FR2.1–2.5, FR3.1–3.5), and preserves stable identifiers across edits.
- `SubjectService`: subject group CRUD with non-empty/unique-name validation (FR14.1–14.3, FR14.5).

**Testing**: CRUD round-trips for both note kinds, atomic-write rollback scenarios, stable-ID preservation across repeated edits, subject validation edge cases (duplicate names, empty names, deletion with notes attached).

**Phase checkpoint**: A note can be created, edited, deleted, and reloaded with identical content and identifier; a failed write leaves the previous record intact; subject groups can be created, renamed, and deleted with notes correctly reassigned to "ungrouped" (FR14.4).

---

### Phase 3: Secure Notes, Step-Up Authentication, and Protected Trash (Weeks 6–8)
**Goal**: Bring secure-mode notes online end to end — encryption at save time, key-gated access at open time, and lock-aware trash semantics.

**Components**:
- Secure-mode toggle and on-device encryption path in `NoteService.save`/`load`, producing storage records that contain only ciphertext, nonce, tag, and salt (FR3.3, FR3.6).
- `secureTitleAlias` field on secure notes — a user-supplied, non-sensitive display label (defaulting to "Locked Note") persisted alongside the ciphertext (FR12.3) and surfaced wherever a secure note's real title cannot be shown.
- `AppCoordinator` session states (`.firstLaunchSetup`, `.locked`, `.unlocked`) and the step-up authentication flow: opening, saving, or attaching to a secure note triggers an authentication prompt at the moment the encryption key is needed, and the triggering action resumes automatically on success (FR3.8).
- `UnlockView`: presented only during first-launch initialization to create and confirm the master passphrase (FR1.1) — not as a gate on subsequent launches, since the workspace opens directly and authenticates per secure-note operation (FR1.2).
- `ProtectedTrashRepository` and `ProtectedTrashService`: move-to-trash, restore, and permanent-delete, each wrapped in its own ACID transaction (FR5.1, FR5.4, FR5.6–5.7).
- Trash UI semantics: normal notes show title and deletion time; secure notes show only the alias and a lock badge, with restore gated on an active unlocked session (FR5.2–5.3, FR5.5).

**Testing**: Encrypt/decrypt round-trips with tamper-detection (corrupted ciphertext surfaces a user-visible error without altering the stored record — FR3.6, NFR4.2), step-up prompt triggers on every access attempt, trash display and restore-gating across locked/unlocked sessions, permanent-delete irreversibility.

**Phase checkpoint**: A secure note can be created with a custom alias, saved (encrypted), closed, and reopened only after authentication; deleting it moves the encrypted record and its attachments to trash atomically; the trash never reveals a decrypted title.

---

### Phase 4: Session Lock, Search, Attachments, and Workspace Feedback (Weeks 9–10)
**Goal**: Complete the always-on workspace experience — alias-based search that works regardless of lock state, media attachments, lifecycle-driven locking, and user-facing notifications.

**Components**:
- `NoteSearchService`: direct plaintext matching for normal-note titles and alias-only matching for secure notes — the search path never decrypts or holds a decrypted title in memory, so results are identical whether the session is locked or unlocked (FR12.1–12.5, NFR3.2).
- `PlatformIntegration`: subscribes to background/sleep/wake/user-interaction platform events and routes background and sleep events to `AppCoordinator.handleImmediateLockEvent`, which clears in-memory key material immediately unless a tracked background operation (export, rotation) is in flight, in which case the lock is deferred until that operation completes (FR7.1–FR7.4).
- Voice capture: microphone recording, written to app-container storage as a plain file once recording completes, carrying an `isEncrypted` bookkeeping flag that records (but does not enforce) the owning note's secure-mode intent; confidentiality at rest rests on the host's disk-level encryption (FR6.1–FR6.3).
- Image attachment: local file picker, the same plain-file storage and bookkeeping-flag model, and the 20 MB size ceiling (FR13.1–FR13.3).
- `NotificationService` / toast presentation: transient pop-up feedback for success, warning, and error states that auto-dismisses after about five seconds (FR10.3).
- `SettingsService` / `SettingsView` (first pass): the two-setting model — global plugin enablement and biometric-unlock enablement — with validation before commit (FR10.1–FR10.2).

**Testing**: Search correctness and lock-state independence for secure notes, oversize-attachment rejection messaging, immediate-lock triggering and deferral around background operations, toast lifecycle timing, settings validation.

**Phase checkpoint**: Searching by alias returns secure notes whether the app is locked or unlocked; backgrounding the app clears in-memory key material immediately (or as soon as an in-flight export/rotation completes); voice and image attachments respect their size limits and persist correctly; user feedback appears as auto-dismissing toasts.

---

### Phase 5: Passphrase Rotation, Backup, Plugins, and Biometrics (Weeks 11–13)
**Goal**: Deliver the remaining advanced capabilities — atomic credential rotation, encrypted backup/restore, the plugin host, and biometric authentication — and close out the security hardening work.

**Components**:
- `KeyManager.changePassphrase`: a single atomic transaction that re-encrypts every secure note under the new key and commits the new credentials together — there is no persisted intermediate state, and an interruption leaves the database exactly as it was under the original credentials, with any stale in-flight marker cleared and logged on next unlock (FR8.1–FR8.4, NFR5.2). Includes the identical-passphrase rejection check (FR8.5).
- `ExportImportService`: encrypted, schema-versioned archive export (with sensitive/runtime-only fields stripped before encryption) and a single-transaction import that supports both ID-remapping and strict-rejection conflict resolution and rolls back completely on any failure (FR9.1–FR9.4).
- `LocalAuthService`: Keychain-backed biometric enrollment and authentication, integrated as the optional fast path alongside passphrase entry in the same authentication prompt, including graceful handling when biometric hardware or enrollment becomes unavailable (FR1.3–FR1.5).
- `PluginService`, `PluginMetadataRepository`, `PluginBundleRepository`: install-time manifest validation (`pluginId`, `displayName`, `version`, `capabilities`), enable/disable/remove lifecycle, persisted plugin metadata and separately-stored bundle bytes, and a gated, timeout-guarded action-execution surface (`registerHandler`/`execute`) exposed at the service layer for future extension (FR11.1–FR11.7).
- `PluginStoreView`: install, enable/disable, and remove UI with a confirmation step before removal (FR11.3).
- Confidentiality and audit verification pass: confirm no decrypted content reaches logs, caches, or exports (NFR3.1), and that audit events cover authentication failures, rotation outcomes, plugin lifecycle events, and export/import completions (NFR6.3).

**Testing**: Rotation interruption-and-recovery scenarios, import rollback on induced mid-merge failures, biometric enrollment/availability edge cases with passphrase fallback, plugin install validation and execution timeout/error containment, full confidentiality-boundary inspection of logs/caches/export archives.

**Phase checkpoint**: Changing the passphrase re-encrypts all secure notes atomically and survives a simulated mid-rotation termination; export followed by import on a clean database reproduces the original note set; plugins install, run through the gated host API, and fail safely on timeout; biometric unlock falls back to passphrase seamlessly.

---

### Deployment Readiness (Week 14)
**Goal**: Final verification, documentation, and release packaging.

**Activities**:
- Full regression run across `AstraCoreTests`, `AstraDataTests`, `AstraPlatformTests`, and `AstraIntegrationTests`.
- Performance validation against NFR1.1–NFR1.2 (authentication latency independent of note count) and NFR2.2 (sustained 60 FPS) on Apple Silicon and Intel i5/i7 (6th gen+) reference hardware.
- Security review: confidentiality-boundary inspection, rate-limit and lockout verification, rotation/import recovery-path walkthroughs (NFR5.2).
- Documentation pass: finalize `README.md`, architecture and requirements cross-references, and user-facing guides.
- Build signing and release packaging.

**Deliverables**:
- Production-ready MVP build covering every functional area in Requirement.md: authentication, normal and secure note lifecycles, protected trash, title search, voice and image attachments, session locking, passphrase rotation, export/import, settings and notifications, the plugin host, and subject groups.
- Test coverage report for `AstraCore` and `AstraData` services.
- Release notes mapped to the requirement IDs they satisfy.

---

### Risk Mitigation

1. **Cryptographic correctness**: validate the AES-GCM and PBKDF2 paths against standardized test vectors in Phase 1, before any feature is built on top of them.
2. **Transactional integrity**: exercise induced-failure rollback paths for every multi-step write (note delete-to-trash, passphrase rotation, import) as each feature lands, not just at the end.
3. **Lock-boundary correctness**: because the workspace remains visible while locked, the step-up authentication gate (FR3.8) and the immediate-lock event path (FR7.2–FR7.3) must be tested together — a gap in either one is a confidentiality defect, not a UX defect.
4. **Plugin containment**: enforce the timeout-and-error guard around `execute` from the first integration of `PluginService`, since a misbehaving plugin must never be able to crash the host or touch repositories directly (FR11.4, FR11.6).
5. **Scope discipline**: the requirements deliberately exclude whole-app unlock screens, telemetry, lock timeouts, draft persistence on lock, expiration policies, accessibility/localization infrastructure, and UI-level plugin execution. Treat any drift toward implementing these as a requirements regression, not a welcome addition.

---

### Dependencies and Tooling
- **Cryptography**: Apple CryptoKit (AES-GCM, HKDF) and a PBKDF2-HMAC-SHA256 implementation.
- **Persistence**: in-process `DatabaseProvider` actor with `Codable`-backed JSON snapshot persistence — no external database engine.
- **Authentication**: `LocalAuthentication` and Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) for biometric key storage.
- **Platform integration**: AppKit/SwiftUI scene-phase and power-state notifications for background/sleep/wake events.
- **UI**: SwiftUI across all four modules, with `AstraUI` as the sole presentation layer.

---

### Phase-Transition Checkpoints

1. **Phase 1 → 2**: crypto primitives pass test vectors; transaction rollback is verified under induced failure; audit logging emits sanitized events only.
2. **Phase 2 → 3**: normal-note and subject CRUD is fully atomic with stable identifiers; the repository layer is exercised end to end through `NoteService`/`SubjectService`.
3. **Phase 3 → 4**: secure notes encrypt/decrypt correctly with tamper detection; step-up authentication gates every secure-note operation; trash display and restore-gating semantics match FR5.2–FR5.5 exactly.
4. **Phase 4 → 5**: alias-based search returns correct, lock-state-independent results; immediate-lock and deferral behavior is verified against background operations; attachments respect size limits and storage semantics.
5. **Phase 5 → Deploy**: full regression suite passes; rotation and import recovery paths are verified by induced-interruption tests; no decrypted content is observable in logs, caches, or export archives; performance benchmarks meet NFR1–NFR2 targets.
