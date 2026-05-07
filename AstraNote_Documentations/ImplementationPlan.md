## Implementation Plan (Lowest-Risk Order)

Phase 1: Foundation
- Implement `DatabaseProvider`, repositories, and migrations.
- Implement `KeyManager` + `EncryptionService` with test vectors.

Phase 2: Core Note Lifecycle
- Implement `NoteService` CRUD with encrypted persistence.
- Implement `NotesWorkspaceView` basic tri-pane with create/edit/delete.
- Implement title search for normal notes in `WorkspaceTopBar` + `NoteSearchService`.

Phase 3: Secure Note Features
- Implement `SecureNotePolicyService` and `ProtectedTrashService`.
- Add secure toggle, expiry date/time UI, lock badges, and expiration processing.
- Implement `TrashView` with browse, restore, and permanent-delete for both normal and secure notes.
- Extend title search to include secure notes via unlocked in-memory matching and cache clear on lock.

Phase 4: Platform Hardening
- Add biometric unlock (`LocalAuthService`), auto-lock hooks (`PlatformIntegration`), notifications (`NotificationService`).
- Add audit-safe logging and time rollback protection (`TimeProvider`).
- Add `ExportImportService` flow for encrypted archive backup and atomic restore.

Phase 5: Simple Plugin Support
- Add local plugin install/remove and enable/disable in `PluginStoreView`.
- Implement minimal `PluginService` host API and action execution guardrails.
- Persist plugin metadata and status in plugin repositories.