## Implementation Plan (Practical, Lowest-Risk Order)

All 5 phases build incrementally toward complete MVP with early integration testing and deployment readiness.

### Phase 1: Foundation and Core Crypto (Weeks 1-3)
**Goal**: Establish data persistence, encryption, and key management foundations.

**Priority Components**:
- `DatabaseProvider.swift`: SQLite setup, connection pooling, transaction wrapper (ACID compliance).
- Migration framework for schema versioning.
- `KeyManager.swift`: Passphrase hashing (PBKDF2), key derivation (AES-256), in-memory key lifecycle, rate-limited lockout.
- `EncryptionService.swift`: AES-GCM authenticated encryption, nonce generation, encrypt/decrypt payload boundary.
- Core models: `Note.swift`, `EncryptedPayload.swift`, `Attachment.swift`, `KeyMaterial.swift`.

**Testing**: Unit tests for encryption, key derivation, transaction rollback. Test vectors for AES-GCM.

**Deliverables**:
- Secure database with transaction support.
- Encryption/decryption with authentication.
- Rate-limited unlock enforcement.

---

### Phase 2: Core Repositories and Note CRUD (Weeks 4-5)
**Goal**: Implement persistence layer and basic note lifecycle.

**Priority Components**:
- `NoteRepository.swift`: CRUD for standard and secure notes (plain text vs. ciphertext persistence).
- `SubjectRepository.swift`: Subject group persistence (id, name, displayOrder).
- `AttachmentRepository.swift`: Attachment linking by noteId and type (image | recording).
- `SettingsRepository.swift`: Settings persistence (lock timeout, telemetry opt-in, plugin enabled).
- `NoteService.swift`: Orchestration of note CRUD with encrypted/standard storage routing (FR2.1-2.5, FR3.1-3.5).
- `SubjectService.swift`: Subject group CRUD with validation (non-empty, unique names; FR14.1-14.5).

**Testing**: CRUD operations, atomic writes, rollback scenarios, stable ID preservation across edits.

**Deliverables**:
- Note creation, editing, deletion.
- Normal notes stored as plain text.
- Subject group management (create, rename, delete).

---

### Phase 3: Secure Note Features and Trash (Weeks 6-8)
**Goal**: Implement secure mode and trash flow.

**Priority Components**:
- `SecureNotePolicyService.swift`: Secure-note protection rules and delete/restore coordination without time-based expiration.
- `ProtectedTrashRepository.swift`: Trash record schema (source note, isSecure, deletion time).
- `ProtectedTrashService.swift`: Move/restore/permanent-delete logic with ACID transactions (FR5.1-5.7).
- `NotificationService.swift`: Local app notifications for general workspace feedback.
- `TimeProvider.swift`: UTC source for app timestamps.
- UI: Secure toggle, trash view (display semantics for lock badges, hidden titles).
- Test: Secure note storage, trash display, and restore.

**Testing**: Lock badge display, restore permissions (unlock requirement), permanent delete irreversibility.

**Deliverables**:
- Secure notes with encryption.
- Protected trash with correct display semantics (FR5.2, FR5.3).

---

### Phase 4: Session Management, Search, and File Attachments (Weeks 9-10)
**Goal**: Implement unlock flow, title search, and media attachments.

**Priority Components**:
- `AppCoordinator.swift`: App lifecycle, lock/unlock routing, first-launch initialization branch (FR1.1).
- `UnlockView.swift`: Passphrase entry and first-launch creation screens.
- `NoteSearchService.swift`: Normal title search (direct DB query), secure title search (in-memory decrypted cache only while unlocked), cache clear on lock (FR12.1-12.6, NFR3.2).
- Voice capture and storage: Recording file protection (FR6.1-6.3), async transcription (NFR2.1).
- Image attachment and storage: File protection, security mode inheritance (FR13.1-13.3).
- `PlatformIntegration.swift`: App lifecycle events (sleep, background, foreground).
- UI: `NotesWorkspaceView`, `WorkspaceTopBar` (search), `NoteEditorPane` (attachments, secure toggle).

**Testing**: Unlock performance (1k-note ≤1s, 10k-note ≤2s; NFR1.1-1.3), title search correctness, attachment security, UI responsiveness (NFR2.2, 60 FPS).

**Deliverables**:
- Passphrase and biometric unlock (FR1.1-1.6).
- Title search with secure note handling (FR12.1-12.6).
- Voice and image attachments (FR6.1-6.3, FR13.1-13.3).

---

### Phase 5: Advanced Features and Hardening (Weeks 11-13)
**Goal**: Implement passphrase rotation, export/import, plugins, accessibility, and final security hardening.

**Priority Components A** (Critical):
- `KeyManager.swift` (extend): Passphrase change flow, old key retention until re-encryption complete, partial migration detection and recovery (FR8.1-8.6, NFR5.2-5.3).
- `ExportImportService.swift`: Encrypted archive export/import with schema versioning, ACID transaction wrapping, ID conflict handling (FR9.1-9.4, NFR5.1).
- `Logging.swift`: Sanitized audit logging (exclude decrypted content, titles, credentials; NFR6.3, NFR3.1).
- Rate limiting test suite: 5 failed attempts → 30s lockout, exponential progression, max 60 min (NFR6.1).
- `SettingsView.swift`: Lock timeout, telemetry opt-in, plugin global toggle (FR10.1-10.2).

**Priority Components B** (Platform Hardening):
- `LocalAuthService.swift`: Biometric unlock integration (FR1.3-1.6).
- Auto-lock: Background/sleep triggers, inactivity timer (FR7.1-7.2, FR7.3), draft persistence on lock (FR7.5).
- `StorageProtection.swift`: File-protection API for attachments and database (FR6.2, FR13.2).
- Confidentiality boundaries: Verify logs, caches, exports have no decrypted content (NFR3.1).

**Priority Components C** (Plugins and Accessibility):
- `PluginService.swift`: Manifest validation, enable/disable, action execution with timeout and error guard (FR11.1-11.8).
- `PluginMetadataRepository.swift` and `PluginBundleRepository.swift`: Plugin metadata and bundle persistence (FR11.8).
- `PluginStoreView.swift`: Install, enable, disable, remove UI (FR11.1-11.3).
- Keyboard navigation and VoiceOver support for all core workflows (NFR8.1).
- Internationalization infrastructure (English-first, localization extensibility; NFR9.1-9.2).

**Testing**:
- Full integration: Unlock → create/edit/delete → trash → restore → key rotation → export/import.
- Plugin failure modes (timeout, exception, state preservation).
- Accessibility (keyboard-only, VoiceOver navigation).
- Confidentiality boundary verification (logs, caches, exports inspection).
- Performance benchmarks at full scale (10k notes, multiple attachments, key rotation).
- Corruption recovery scenarios (partial migration, import failure, database corruption; NFR5.3).

**Deliverables**:
- Passphrase change with atomic re-encryption (FR8.1-8.6).
- Export/import with atomic semantics (FR9.1-9.4).
- Simple plugin support (FR11.1-11.8).
- Auto-lock and background session management (FR7.1-7.5).
- Biometric unlock (FR1.3-1.6).
- Accessibility and localization (NFR8.1, NFR9.1-9.2).

---

### Deployment Readiness (Week 14)
**Goal**: Final testing, documentation, and release packaging.

**Activities**:
- Full regression test run (all 20 test sections, ≥200 test cases).
- Performance validation on target hardware (Apple Silicon, Intel i5/i7 6th gen+).
- Security audit: Penetration testing, confidentiality boundary verification.
- Documentation: User guides, technical architecture finalization, API reference.
- Build optimization, signing, and release preparation.
- Localization smoke test (add one non-English locale).

**Deliverables**:
- Production-ready MVP binary.
- Complete test coverage report (≥95% core services).
- Release notes and user documentation.

---

### Risk Mitigation

1. **Crypto correctness**: Validate AES-GCM implementation with standardized test vectors; use well-tested libraries.
2. **Data integrity**: ACID transaction testing in Phase 1; simulate failures in all phases.
3. **Performance regressions**: Profile unlock, search, and encryption operations early; optimize in Phase 4-5.
4. **Plugin security**: Timeout and error isolation in Phase 5; test failure modes before release.
5. **Accessibility gaps**: Manual VoiceOver testing throughout development; don't defer to end.

---

### Dependencies and Resources
- **Crypto**: Swift Crypto / CryptoKit for AES-GCM, PBKDF2.
- **Database**: SQLite with transaction API.
- **Local Auth**: LocalAuthentication framework.
- **Storage Protection**: FileProtection API.
- **Notifications**: UserNotifications framework.
- **Localization**: NSLocalizedString with Localizable.strings.

---

### Checkpoints for Phase Transitions

1. **Phase 1 → 2**: Crypto unit tests pass; transaction rollback verified.
2. **Phase 2 → 3**: All CRUD operations atomic; stable note IDs preserved.
3. **Phase 3 → 4**: Secure note storage working; trash display correct; secure-note access confirmed.
4. **Phase 4 → 5**: Unlock performance ≤1s (1k notes); title search correct; attachments stored correctly.
5. **Phase 5 → Deploy**: Full regression pass; ≥95% code coverage; all NFR benchmarks met; no decrypted content leakage detected.