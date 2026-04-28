# AstraNotes User Stories

## 1. Unlock and resume securely
- As a user, I want to unlock AstraNotes with my master passphrase and optionally use biometric authentication so I can access my encrypted notes quickly and safely.
- Acceptance criteria:
  - The app shows a passphrase entry screen on startup when locked.
  - Entering the correct passphrase decrypts and displays all note titles in the list view.
  - After a successful passphrase unlock, biometric unlock may be enabled and used for subsequent sessions.
  - Biometric unlock falls back to the passphrase when unavailable or rejected.
  - The app does not store plaintext notes on disk at any time during unlock.

## 2. Create, edit, and delete encrypted notes
- As a user, I want to create, edit, and delete notes so I can manage my private information securely.
- Acceptance criteria:
  - Creating or updating a note encrypts its content locally before writing to storage.
  - Stored note entries contain ciphertext, nonce, and salt, not plaintext.
  - Editing a note updates the encrypted content and preserves the note ID.
  - Deleting a note removes its encrypted record and any related attachments.
  - The note list view refreshes immediately after create/edit/delete.

## 3. Secure note lifecycle with expiration
- As a user, I want to mark a note as secure so it expires automatically after a defined time.
- Acceptance criteria:
  - User can enable secure note mode when creating or editing a note.
  - Secure notes support TTL expiration behavior.
  - When a secure note expires, it is removed from the visible list and optionally moved to trash.
  - Expired secure notes are no longer decryptable or viewable after the expiration event.

## 4. Record voice notes and transcribe them
- As a user, I want to capture voice notes and convert them to text so I can save ideas quickly without typing.
- Acceptance criteria:
  - The app provides a voice capture view for recording audio.
  - Recorded audio is stored with file protection and encrypted in the app container.
  - The app transcribes recorded voice into a text note that can be saved.
  - The transcription flow does not block the main UI thread and remains responsive.

## 5. Install, manage, and verify plugins
- As a user, I want to install, remove, and run plugins safely so I can extend AstraNotes with text, voice, and secure features.
- Acceptance criteria:
  - The app shows available plugins in a plugin store view.
  - Enabling a plugin registers it in plugin metadata.
  - Plugin signatures are verified before installation or execution.
  - Untrusted or unsigned plugins are rejected with an audit log entry.
  - Plugins execute using a limited API and do not directly access plaintext storage.

## 6. Auto-lock and session protection
- As a user, I want the app to auto-lock when idle or when the device sleeps so my notes stay protected.
- Acceptance criteria:
  - The app auto-locks after the configured inactivity timeout.
  - The app auto-locks when the OS goes to sleep or the app is backgrounded.
  - When locked, the app requires authentication to reopen.
  - In-memory key material is cleared when the lock state resets.

## 7. Backup and restore encrypted data
- As a user, I want to export and import encrypted archives so I can protect and recover my data.
- Acceptance criteria:
  - The export feature creates an encrypted archive containing note and attachment ciphertext.
  - The import feature accepts only encrypted archives and restores notes without exposing plaintext.
  - Failed imports show clear user-facing messages and do not cause data loss.

## 8. Ensure integrity, replay protection, and recovery
- As a user, I want my note data to remain intact and protected from tampering so I can trust AstraNotes with sensitive information.
- Acceptance criteria:
  - Database writes use ACID transactions and rollback on failure.
  - Note decryption fails explicitly if integrity checks or authentication tags do not match.
  - The app detects corrupted or replayed data and prompts the user with recovery instructions.
  - Migration failures preserve the previous database state and surface user-readable guidance.
