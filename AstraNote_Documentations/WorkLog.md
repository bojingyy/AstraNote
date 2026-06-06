# AstraNotes Work Log

---

## 2026-05-07

### Documentation Alignment Pass — Architecture, Requirements, UserStories, TestSteps

#### Architecture.md
- Added `UnlockView.swift` to AstraUI module map (passphrase entry + first-launch passphrase creation screen).
- Updated `KeyManager.swift` description to include rate limiting and lockout enforcement on consecutive unlock failures.
- Added step 0 to Unlock flow (5.1): first-launch passphrase creation before any data is stored.
- Fixed flow numbering: Subject Group Management was mislabeled 5.8, Title Search was mislabeled 5.7; corrected to 5.7 and 5.8 respectively.
- Added Section 5.9: Auto-Lock Flow.
- Added Section 5.10: Passphrase Change / Key Rotation Flow.
- Added Section 5.11: Export / Import Flow.
- Passphrase Change flow (5.10, step 3): identical derived key now returns a user-visible error and prompts user to choose a different passphrase; no longer returns silent success.
- Passphrase Change flow (5.10, step 7): interrupted key rotation now has a concrete decision rule — always attempt to complete remaining re-encryption first; roll back only if completion itself fails; user informed of outcome either way.

#### Requirement.md
- FR8.4: replaced vague "complete or roll back" with concrete rule — always attempt completion first; roll back only if completion fails; user informed either way.
- FR8.5: identical key now returns a user-visible error and prompts user to choose a different passphrase instead of silently skipping re-encryption.

#### UserStories.md
- Story 1: added first-launch passphrase setup criterion (aligned with FR1.1).
- Story 4: added device clock rollback protection criterion (aligned with FR4.5).
- Story 7: removed out-of-scope transcription (not in Architecture or Requirements); story renamed to "Capture voice" with record-and-attach goal only.
- Story 9: added criterion that background operations do not reset the inactivity timer (aligned with FR7.3).
- Story 10: updated interrupted key rotation criterion to match new concrete decision rule; updated identical key criterion to reflect error behavior.

#### TestSteps.md
- Step 46: updated to verify complete-first then roll-back-if-fail logic and that user is informed of the outcome.
- Step 47: updated to verify app rejects identical key with a user-visible error and prompts user to choose a different passphrase.

---

## 2026-05-18

### UML Documentation Format Update

#### UML_Package
- Updated `ClassDiagram.html` with the latest class diagram refinements.
- Replaced legacy UML markdown/image artifacts with HTML-based UML exports for consistency in documentation consumption.
- Added HTML diagram files for Activity, Deployment, Object, and Use Case views in `UML_Package`.
- Removed outdated UML `.md` and `.png` files from `UML_Package` as part of the format transition.

### Implementation Progress Update — Phases 1 to 4

#### Phase 1: Foundation and Core Crypto (Completed)
- Implemented transactional persistence foundation in `DatabaseProvider` with commit or rollback behavior.
- Implemented core persistence models for notes, encrypted payloads, attachments, subjects, settings, trash records, and credential state.
- Implemented passphrase-derived key handling in `KeyManager` with PBKDF2 key derivation, in-memory key lifecycle, and lockout enforcement.
- Implemented `EncryptionService` using AES-GCM authenticated encryption and decryption boundaries.
- Implemented audit logging support for security-relevant events with metadata sanitization.

#### Phase 2: Core Repositories and Note CRUD (Completed)
- Implemented repositories for notes, subjects, attachments, settings, and protected trash persistence operations.
- Implemented `NoteService` orchestration for normal and secure note save/load/delete flows with encryption routing.
- Implemented subject management in `SubjectService` with non-empty and unique-name validation.
- Implemented settings validation and update flow in `SettingsService`.
- Added attachment handling rules in service layer, including size constraints and note security-mode inheritance.

#### Phase 3: Secure Note Features and Trash (Completed)
- Implemented `SecureNotePolicyService` as a no-op secure-note policy boundary with no time-based expiration behavior.
- Removed rollback-time guard behavior from the runtime model.
- Implemented protected trash behavior in `ProtectedTrashService` including secure-note lock semantics in trash.
- Implemented restore authorization rules requiring active unlocked session for secure note restore.
- Implemented notification service abstraction for workspace feedback and general platform alerts.

#### Phase 4: Session Management, Search, and Attachments (Completed)
- Implemented `AppCoordinator` for first-launch branch routing, lock or unlock transitions, and inactivity lock decisions.
- Implemented deferred auto-lock behavior when inactivity timeout expires during active background operation.
- Implemented `NoteSearchService` for normal-title storage search and unlocked-session-only secure-title in-memory matching.
- Implemented secure search cache clear on lock.
- Added minimal functional UI wiring with `AppEnvironment`, `UnlockView`, and `NotesWorkspaceView` to exercise session and search flows.

#### Test Status (Current)
- Phase 1 and 2 validator passed: `make phase12-validate`.
- Phase 3 and 4 validator passed: `make phase34-validate`.
- Targeted suite results during verification:
	- `AstraCoreTests`: 9 passed.
	- `AstraDataTests`: 4 passed.
	- `AstraIntegrationTests.testPhase1And2HappyPathFlow`: passed.
	- `AstraIntegrationTests.testPhase3And4SecureTrashAndSearchFlow`: passed.
- Project build status: `swift build` passed during verification for this milestone.

---

## 2026-05-19

### Bug Fixes — Passphrase Screen, Session State, and App Launch

#### UnlockView.swift
- Replaced boolean `@FocusState` with an enum-based `FocusField` type for deterministic passphrase/confirm-passphrase field targeting.
- Removed `onTapGesture` override and `NSApplication.activate` hack that interfered with macOS first-responder routing.
- Added `onSubmit` handlers: Enter in passphrase field advances to confirm field (first-launch) or submits unlock; Enter in confirm field submits.
- Replaced `DispatchQueue` focus delay with `.task(id: sessionState)` plus `Task.yield()` for reliable view-hierarchy-ready focus assignment.
- Added `.defaultFocus($focusedField, .passphrase)` as a secondary focus hint.
- Disabled autocorrection on both secure fields to prevent input transformation.
- Added typed error messages for `invalidPassphrase`, `lockoutActive`, and `passphraseNotInitialized` cases instead of raw error string dumps.
- Removed debug `Text("Debug: \(passphrase)")` label and `print` statements from production code.

#### AstraNotesApp.swift
- Added `AstraNotesAppDelegate` conforming to `NSApplicationDelegate`.
- Called `NSApp.setActivationPolicy(.regular)` and `NSApp.activate(ignoringOtherApps: true)` in `applicationDidFinishLaunching` so SwiftPM-launched windows reliably receive keyboard focus instead of leaving the terminal as key target.

#### ContentView.swift
- Added `didInitializeCoordinator` guard so `coordinator.start()` and `coordinator.bind()` run only once per process lifetime; repeated view refreshes can no longer reset an already-unlocked session to locked.
- Added local `@State private var sessionState` mirroring the coordinator value, subscribed via `onReceive(coordinator.$sessionState)`, so root screen switching is guaranteed to react to every state change.
- Added periodic inactivity auto-lock poll (1-second interval) via a long-lived `.task`.
- Added `.onChange(of: scenePhase)` to register user interaction on scene activation.
- Removed immediate lock-on-background scene-phase trigger to match the UX requirement: lock only on inactivity timeout or explicit quit/reopen.

#### AppCoordinator.swift
- Added early-exit guard in `start()`: if `sessionState == .unlocked`, skip credential check and return immediately; startup can no longer overwrite a valid in-process unlocked state.
- Added `effectiveLockTimeoutSeconds` clamp (`30...3600`) in `evaluateInactivityAutoLock` to prevent immediate relock loops caused by zero or invalid persisted timeout values.

#### DatabaseProvider.swift
- Added optional `persistenceURL` parameter to `DatabaseProvider.init`.
- On init with a URL, attempts to load and decode a JSON-encoded `DatabaseState` from disk; falls back to fresh state if absent or malformed.
- `replaceState` and `transaction` now call `persistIfNeeded()` after every successful mutation to keep the on-disk snapshot up to date.
- Added `static func defaultPersistenceURL() -> URL?` resolving to `~/Library/Application Support/AstraNotes/database-state.json`.

#### AppEnvironment.swift
- Updated `DatabaseProvider` initialisation to use `DatabaseProvider.defaultPersistenceURL()` so credential and settings state persists across process restarts; enables the "unlock on reopen, not create" flow.

#### AstraCoreTests.swift
- Fixed 14 passing tests to remain green after the above coordinator and persistence changes; no new test failures introduced.

---

## 2026-06-03

### UI Refinement — Notes Workspace Editor Readability

#### NotesWorkspaceView.swift
- Increased default typography size for note editing inputs to improve readability in the workspace editor.
- Updated `Title` input and note `TextEditor` content font to `.system(size: 16)` for a clearer default writing experience.

### Security UX Enhancement — Secure Note Step-Up Access

#### NotesWorkspaceView.swift
- Added secure-note access prompt that requires step-up authentication before opening secure note content.
- Added passphrase and biometric options in the access prompt; secure note load proceeds only after successful re-authentication.
- Added typed error messages for failed secure-note access attempts (invalid passphrase, lockout, biometric disabled/unavailable).

#### ContentView.swift / AppCoordinator.swift
- Wired workspace secure-note access actions to coordinator-level re-authentication methods.
- Added dedicated coordinator APIs for secure-note access checks with passphrase and biometrics.

#### Requirement.md / Architecture.md
- Added FR3.9 to require passphrase or biometric step-up authentication per secure-note open attempt.
- Updated note open flow in architecture to include secure-note access authentication before load.

### Security Model Update — Remove Whole-App Lock, Keep Secure-Note Re-Auth

#### Product/UX Behavior
- Removed whole-app lock as a user-facing workflow for returning users.
- Kept first-launch passphrase creation as mandatory bootstrap for new users.
- Retained secure-note step-up authentication (passphrase or biometrics) per secure-note access attempt.

#### AppCoordinator.swift / ContentView.swift / NotesWorkspaceView.swift
- Updated startup routing so existing users land directly in workspace instead of global unlock screen.
- Removed explicit workspace lock control from top actions.
- Kept secure-key clear behavior for timeout/background/sleep events without redirecting to full unlock UI.

#### Requirement.md / Architecture.md
- Updated Unlock and Auto-Lock related requirements to reflect secure-key timeout behavior rather than whole-app lock transitions.
- Updated architecture unlock and timeout flows to describe per-secure-note authentication with workspace remaining available for normal notes.

### UI Notification Redesign — Transient Pop-Up Messages

#### NotesWorkspaceView.swift
- Replaced inline info/error message text under the editor input area with floating pop-up notifications.
- Added workspace toast overlay for user feedback (success/error) with automatic dismiss after approximately 5 seconds.
- Routed workspace operation outcomes (save/delete/subject operations/trash actions/secure-access failures) to toast presentation.

#### Requirement.md / Architecture.md
- Updated requirement language to define transient pop-up notification windows (about 5 seconds) for foreground feedback.
- Updated architecture module map and secure-note retention flow to document toast-based foreground notification behavior.

---

## 2026-06-05

### Secure Note Search & Save Fixes — Alias Model + Session Correctness

#### NoteService.swift / NoteSearchService.swift / CoreModels.swift / PersistenceModels.swift
- Added secure-note alias support (`secureTitleAlias`) to draft/view/persistence models.
- Updated secure-note save flow to persist alias metadata with default fallback `Locked Note`.
- Updated note summary display for secure notes to use alias fallback instead of decrypted title.
- Reworked secure-title search to match on stored alias metadata only.
- Removed decrypted secure-title cache dependency from search behavior.

#### NotesWorkspaceView.swift / ContentView.swift / AppCoordinator.swift
- Added secure alias input field in editor when secure mode is enabled.
- Added secure-note metadata-only update path for alias/subject changes on existing secure notes, avoiding unnecessary re-encryption.
- Refined secure save error handling so alias-only edits can still save even when key material is unavailable.
- Added interaction callbacks from workspace editing controls to coordinator for inactivity timer refresh.
- Corrected startup session behavior: existing passphrase now starts in `.locked` state (workspace remains available, secure operations require unlock).
- Preserved secure-note authentication prompt for new secure-note creation and real secure content encryption operations.

#### ExportImportService.swift / ProtectedTrashRepository.swift
- Ensured `secureTitleAlias` is preserved in import remap and secure-trash restore/collision flows.

#### Tests
- Updated secure search tests to validate alias-based matching and no decrypted-title search dependency.
- Added regression coverage for secure metadata updates without in-memory key material.
- Verification status during this update cycle: targeted and full test runs passed (latest full run: 29 passed, 0 failed).

### Workspace UX Update — Welcome Default + Header Toolbar Layout

#### NotesWorkspaceView.swift
- Added a default workspace state card in editor pane: `Welcome to AstraNotes`.
- Changed empty-right-pane behavior so blank editor appears only when user explicitly starts a new draft.
- Added explicit new-draft mode to separate welcome state from compose state.
- Updated welcome CTA label to `Create a Note`.
- Reworked top header layout:
	- First row: settings icon (left), trash icon (next), New Note button (right).
	- Second row: search input with Search and Reset actions.

### Workspace UX Update — Simple Navigation Improvements

#### NotesWorkspaceView.swift
- Added a fold/unfold control in the top-left of the note workspace pane.
- Made the entire left panel collapsible.
- Replaced `[Secure]` / `[Normal]` text markers before note titles.
- Secure notes now show a lock icon; normal notes show no prefix.

### Workspace Editor Update — Rich Text Formatting

#### NotesWorkspaceView.swift / RichTextEditor.swift
- Added rich text controls for text size, bold, italic, underline, and preset text colors.
- Limited text colors to black, blue, green, and red.
- Fixed formatting so style changes apply only to the selected text, not the whole note.
- Updated the toolbar to reflect the style of the current text selection, including highlighted formatting buttons.

### Workspace Editor Update — Attachment Support

#### NotesWorkspaceView.swift / ContentView.swift / WorkspaceAttachmentSupport.swift
- Added UI actions to attach images and voice recordings directly in note workspace.
- Added image import flow using a macOS file picker and attachment persistence wiring.
- Added voice recording flow (start/stop) using microphone permission and local recording files.
- Added attachment list in workspace with type icon, file size, and Open/Reveal actions.
- Added secure-note compatible attachment flow, including auth continuation when needed.
- Added cleanup and user-facing error handling for failed attachment operations.

---

## 2026-06-06

### App Icon — AstraNotes Logo in Dock and App Switcher

#### Sources/AstraUI/Assets.xcassets/AppIcon.appiconset/
- Created asset catalog with a full set of macOS icon sizes (16×16 through 1024×1024, including @2x variants).
- All sizes generated from `AstraNotes_Logo.png` using `sips`.
- Applied macOS squircle mask (22.5% corner radius, continuous curve) via a CoreGraphics Swift script to match the standard macOS Big Sur+ app icon shape.
- Rounded version saved as `AstraNotes_Logo_Rounded.png` in `AstraNote_Documentations/`.

#### Sources/AstraUI/AstraNotes_Logo.png
- Added rounded logo as a directly bundled resource for programmatic icon assignment at runtime.

#### Package.swift
- Registered `Assets.xcassets` (`.process`) and `AstraNotes_Logo.png` (`.copy`) as resources for the `AstraUI` target.

#### AstraNotesApp.swift
- Added programmatic app icon assignment in `applicationDidFinishLaunching`: loads `AstraNotes_Logo.png` from `Bundle.module` and sets `NSApp.applicationIconImage`, so the logo appears in the Dock and app switcher when running via `swift run`.

