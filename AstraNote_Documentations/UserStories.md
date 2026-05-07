# AstraNotes User Stories

## 1. Unlock and resume securely
- As a user, I want to unlock AstraNotes with my master passphrase and optionally use biometric authentication so I can access notes quickly and safely.
- Acceptance criteria:
  - The app shows a passphrase screen when no unlocked session exists.
  - Entering the correct passphrase unlocks the app and loads note lists.
  - After one successful passphrase unlock, biometric unlock can be enabled for later sessions.
  - Biometric unlock falls back to passphrase when unavailable, rejected, or after repeated failures.

## 2. Create and edit normal notes
- As a user, I want normal notes to be fast and simple so I can capture ideas with minimal friction.
- Acceptance criteria:
  - I can create and edit normal notes without enabling secure mode.
  - Normal note title and content are stored as plain text.
  - Note updates preserve stable note identity.
  - Failed writes rollback and keep the previous saved state.

## 3. Enable secure mode per note
- As a user, I want to secure only selected notes so I can protect sensitive content without slowing down all notes.
- Acceptance criteria:
  - I can turn secure mode on from the note editor toolbar.
  - Secure mode requires both expiration date and expiration time.
  - The app rejects expiration timestamps in the past.
  - Secure note title and content are encrypted before persistence.

## 4. Secure note expiration behavior
- As a user, I want secure notes to expire automatically at an exact time so sensitive content is removed on schedule.
- Acceptance criteria:
  - Expiration checks run during active use and app launch.
  - Expiration is selected in local time and stored as UTC timestamp.
  - When expiration is reached, the secure note leaves active list and moves to protected trash.
  - Foreground expiry shows in-app notice; background expiry uses local notification.

## 5. Manage trash for normal and secure notes
- As a user, I want a trash view so I can restore deleted notes or permanently remove them.
- Acceptance criteria:
  - Deleted normal and secure notes appear in trash.
  - Normal trashed notes show readable title and deletion time.
  - Secure trashed notes show lock badge and no readable title.
  - Restoring secure notes requires an active unlocked session.
  - Permanent delete of secure notes wipes ciphertext and linked attachments.

## 6. Search by note title
- As a user, I want title search so I can quickly find notes.
- Acceptance criteria:
  - The top bar provides title search input.
  - Normal note titles are searchable from stored title data.
  - Secure note titles stay encrypted at rest.
  - Secure note titles are searchable only while unlocked using in-memory decrypted matching.
  - Locking the app clears secure-title search memory immediately.

## 7. Capture voice and transcribe
- As a user, I want to record voice and convert it to text so I can write notes faster.
- Acceptance criteria:
  - The workspace top bar includes a voice capture action.
  - Recorded audio is stored with file protection in app storage.
  - Audio transcription runs without blocking the main UI thread.
  - Audio longer than 10 minutes or larger than 50 MB is rejected with clear feedback.

## 8. Use simple plugins
- As a user, I want basic plugins so I can extend note workflows without a complex plugin ecosystem.
- Acceptance criteria:
  - I can install a plugin from a local package.
  - Plugin manifest is validated before plugin can be enabled.
  - I can enable, disable, and remove plugins from plugin management UI.
  - Plugins run only through host API and cannot access repositories directly.
  - Plugin failures or timeouts do not crash the app and do not corrupt note data.

## 9. Auto-lock and key clearing
- As a user, I want auto-lock so protected data is not exposed when I leave the app unattended.
- Acceptance criteria:
  - App auto-locks after timeout, OS sleep, or backgrounding.
  - Lock clears in-memory key material before access is allowed again.
  - If secure note draft is active at lock time, draft is persisted safely before lock completes.

## 10. Change passphrase safely
- As a user, I want to change my master passphrase so I can rotate credentials without losing secure data.
- Acceptance criteria:
  - Passphrase change re-encrypts secure notes and secure attachments.
  - Normal notes are unaffected by passphrase change.
  - Interrupted key rotation resumes or rolls back safely on next launch.
  - If derived key is unchanged, unnecessary re-encryption is skipped.

## 11. Export and import backups
- As a user, I want to export and import protected backups so I can recover data after device issues.
- Acceptance criteria:
  - Export creates passphrase-protected encrypted archive with schema version.
  - Import accepts only compatible encrypted archives.
  - ID conflicts are resolved by assigning new IDs to imported notes.
  - Import is atomic and does not leave partial data on failure.
