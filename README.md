# AstraNotes

AstraNotes is a secure, local-first note-taking application for macOS, built with SwiftUI and CryptoKit. It provides end-to-end encryption for notes, voice capture with transcription, plugin support, and encrypted export/import backup workflows, all while maintaining zero-knowledge privacy.

## Features

- **Encrypted Notes**: All notes are encrypted locally using ChaChaPoly. Plaintext never touches disk.
- **Secure Modes**: Per-note TTL expiration with user-set expiration time.
- **Voice Notes**: Record audio and transcribe to text notes.
- **Plugin System**: Extend functionality with signed plugins for text, voice, and secure features.
- **Biometric Unlock**: Use Face ID or Touch ID after initial passphrase.
- **Auto-Lock**: Locks automatically on inactivity or OS sleep.
- **Backup & Restore**: Export/import encrypted archives for local backup and recovery.
- **Settings**: Customize appearance, lock timeout, and plugin preferences.

## Architecture

The app follows a layered architecture:
- **UI Layer (AstraUI)**: SwiftUI views and state management.
- **Orchestration Layer (AppCoordinator)**: Session handling and routing.
- **Domain (AstraCore)**: Business logic, encryption, and key management.
- **Persistence (AstraData)**: SQLite with GRDB for encrypted storage.
- **Platform (AstraPlatform)**: macOS integrations like LocalAuthentication and speech/audio services.

For detailed architecture, see [AstraDocument/AstraNote_architecture.md](AstraDocument/AstraNote_architecture.md).

## Requirements

- macOS 12.0 or later
- Xcode 14.0 or later
- Swift 5.7+

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/bojingyy/AstraNote.git
   cd AstraNote
   ```

2. Open `AstraNotes.xcodeproj` in Xcode.

3. Build and run the project on a macOS device or simulator.

## Usage

1. Launch the app and set a master passphrase.
2. Create, edit, and delete encrypted notes.
3. Enable biometric unlock in settings for faster access.
4. Record voice notes and transcribe them.
5. Install plugins from the plugin store (signed only).
6. Export notes as encrypted archives for backup.

## Documentation

- [User Stories](AstraDocument/UserStories.md): Detailed user stories and acceptance criteria.
- [Requirement Set](AstraDocument/Requirement_Set.md): Functional and non-functional requirements.
- [Architecture](AstraDocument/AstraNote_architecture.md): In-depth architecture design.

## Testing

Run tests in Xcode or via command line:
```bash
xcodebuild test -scheme AstraNotes -destination 'platform=macOS'
```

Includes unit, integration, and UI tests for encryption, persistence, and security.

## Contributing

1. Fork the repository.
2. Create a feature branch.
3. Make changes and add tests.
4. Submit a pull request.

Ensure all changes maintain security boundaries and pass existing tests.

## Security

AstraNotes prioritizes privacy and security:
- Zero-knowledge encryption.
- No telemetry without opt-in.
- Plugin code must be signed.
- All database operations use ACID transactions.

For security audits or issues, contact the maintainers.