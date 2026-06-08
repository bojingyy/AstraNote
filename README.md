# AstraNotes

AstraNotes is a secure, local-first note-taking application for macOS, built with SwiftUI, CryptoKit, and the Swift Package Manager. It provides per-note end-to-end encryption, rich text formatting, voice and image attachments, a plugin system, and encrypted export/import backups, all while maintaining zero-knowledge privacy — your passphrase and decrypted content never leave the device.

## Features

- **Secure Notes**: Mark any note as "secure" to encrypt its title and content with AES-256-GCM, keyed by a per-note key derived (via HKDF) from your passphrase-derived master key. Locked secure notes display a user-chosen alias instead of their real title.
- **Passphrase-Based Unlock**: A master passphrase (derived with PBKDF2-HMAC-SHA256, 100,000 iterations) gates access to secure notes. Includes rate limiting with escalating lockout after repeated failed attempts.
- **Biometric Unlock**: Enroll Touch ID/Face ID (via the macOS Keychain and LocalAuthentication) to unlock secure notes without retyping your passphrase.
- **Change Passphrase**: Rotate your passphrase from Settings — every secure note is transactionally decrypted with the old key and re-encrypted with the new one (with biometric re-enrollment), rolling back atomically on failure.
- **Rich Text Editing**: Bold, italic, underline, and font-size controls in the note editor.
- **Attachments**: Attach images and voice recordings to notes; attachments inherit the note's secure/plain protection class on disk.
- **Subjects**: Organize notes into collapsible subject groups; create, rename, and delete subjects.
- **Search**: Search note titles by query, with secure-note titles only matched in-memory while unlocked (never persisted in a searchable plaintext index).
- **Protected Trash**: Deleted notes move to a trash that enforces secure-note lock semantics — restoring or previewing a secure note's title requires an unlocked session.
- **Plugin System**: Install plugins with a manifest + bundle, enable/disable them globally or individually, and execute registered plugin actions.
- **Backup & Restore**: Export the entire local database as an encrypted, passphrase-protected archive and import it back, with conflict resolution for re-imported identifiers.
- **Auto-Lock on Background/Sleep**: The app immediately clears in-memory key material when it goes to the background or the OS sleeps, deferring the lock if a background operation is in progress.
- **Settings**: Configure plugin enablement, biometric unlock, and change your passphrase.

## Architecture

The app follows a layered Swift Package Manager architecture with four modules:
- **AstraUI**: SwiftUI views, the executable app target, and state/environment wiring (`AppEnvironment`, `ContentView`, `NotesWorkspaceView`, `SettingsView`, `UnlockView`, etc.).
- **AstraCore**: Business logic and services — `AppCoordinator` (session/lock orchestration), `KeyManager` (passphrase derivation, key lifecycle, rotation), `EncryptionService` (AES-GCM + HKDF), `NoteService`, `SubjectService`, `NoteSearchService`, `ProtectedTrashService`, `PluginService`, `ExportImportService`, and `SettingsService`.
- **AstraData**: Persistence layer — an in-process transactional `DatabaseProvider` and repositories for notes, subjects, attachments, settings, plugins, and protected trash.
- **AstraPlatform**: macOS platform integrations — `LocalAuthService` (Keychain + biometrics), `PlatformIntegration` (background/sleep/wake events), `AuditLogger`, and `TimeProvider`.

For detailed design notes, see [AstraNote_Documentations/Architecture.md](AstraNote_Documentations/Architecture.md).

## Requirements

- macOS 14.0 or later
- Swift 5.9+ (Swift Package Manager — no Xcode project file is used)

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/bojingyy/AstraNote.git
   cd AstraNote
   ```

2. Build and run with Swift Package Manager:
   ```bash
   swift run AstraNotes
   ```

   Or open the folder in Xcode/VS Code as a Swift package and run the `AstraNotes` scheme/target.

## Usage

1. Launch the app and create a master passphrase on first run.
2. Create, edit, and organize notes into subjects; format text with bold/italic/underline and font size.
3. Toggle "Secure Mode" on a note to encrypt it and assign it a display alias for when it's locked.
4. Enable biometric unlock in Settings for faster access to secure notes.
5. Attach images or voice recordings to any note.
6. Browse and restore deleted notes from the protected trash.
7. Install and manage plugins from the plugin store in Settings.
8. Export your notes as an encrypted archive for backup, and import archives to restore.
9. Change your passphrase at any time from Settings — all secure notes are re-encrypted automatically.

## Documentation

- [User Stories](AstraNote_Documentations/UserStories.md): Detailed user stories and acceptance criteria.
- [Requirements](AstraNote_Documentations/Requirement.md): Functional and non-functional requirements.
- [Architecture](AstraNote_Documentations/Architecture.md): In-depth architecture design.

## Testing

Run the full test suite with Swift Package Manager:
```bash
swift test
```

Or run a specific test target:
```bash
swift test --filter AstraCoreTests
swift test --filter AstraDataTests
swift test --filter AstraPlatformTests
swift test --filter AstraIntegrationTests
```

The Makefile also provides convenience targets (`make test`, `make test-core`, `make test-data`, etc.) and phased validation targets that exercise encryption, persistence, session management, and security flows end-to-end.

## Development

Common commands (see `Makefile` for the full list):

```bash
make build           # swift build -v
make build-release   # swift build -c release
make test            # run the full test suite
make lint            # run SwiftLint (Sources/ and Tests/)
make lint-fix        # auto-correct SwiftLint issues
make format          # run SwiftFormat
make format-check    # check formatting without modifying files
make coverage        # generate code coverage report
make clean           # remove build artifacts
make ci              # full pipeline: clean, lint, build, coverage, test
```

Code style is enforced via `.swiftlint.yml` and `.swiftformat` (4-space indentation, 120/200-character line-length warning/error thresholds, avoid force-unwrapping in favor of `guard`/`if let`). Install the tools once with `make install-tools` (requires Homebrew).

If a build fails or modules can't be found, clear the build cache and retry:
```bash
rm -rf .build/
swift build -v
```

## Contributing

1. Fork the repository.
2. Create a feature branch.
3. Make changes and add tests.
4. Submit a pull request.

Ensure all changes maintain security boundaries and pass existing tests.

## Security

AstraNotes prioritizes privacy and security:
- Zero-knowledge, local-first encryption — secure note content is encrypted with AES-256-GCM using per-note keys derived via HKDF from a PBKDF2-derived master key; nothing is ever sent off-device.
- The master passphrase is never stored; only a verifier derived from it is persisted, and the in-memory key is cleared whenever the app locks.
- Biometric unlock stores the key material in the macOS Keychain behind a `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` access control, gated by Touch ID/Face ID.
- Repeated failed unlock attempts trigger escalating rate-limit lockouts.
- All database mutations run through ACID transactions, including atomic, crash-recoverable passphrase rotation that re-encrypts every secure note.
- Export archives are themselves encrypted with the user's key before leaving the database layer.

For security audits or issues, contact the maintainers.
