# AstraNote Test Steps

## Unlock and Note List
1. Launch the app and verify the master passphrase screen appears.
2. Enter a valid passphrase and confirm the app unlocks within 1 second on desktop hardware.
3. Confirm the note list displays titles only, with no plaintext stored on disk.
4. Search and filter notes, verifying the UI updates without blocking the main thread.

## Create, Encrypt, and Persist Notes
5. Create a new note and save it.
6. Confirm the note is encrypted before being persisted, storing ciphertext, nonce, salt, and metadata.
7. Restart the app and unlock again, then confirm the note decrypts correctly.
8. Update the note and verify the new encrypted record replaces the previous one safely.

## Secure Note TTL Lifecycle
9. Create a secure note and set a user-defined TTL expiration time.
10. Update the secure note expiration time and verify the new TTL value is persisted.
11. Simulate TTL expiration and verify the secure note is removed from active lists and handled by protected deletion/trash policy.
12. Confirm secure note plaintext is never written to disk during normal use.

## Audio and Voice Capture
13. Record a voice note and save the audio attachment.
14. Confirm the audio file is stored in the app container with complete file protection enabled.
15. Verify transcription is returned and stored securely if converted to text.

## Key Management and Unlock Modes
16. Change the master passphrase and verify key rotation occurs without data loss.
17. Enable biometric unlock and confirm LocalAuthentication can derive the session key after the initial password unlock.
18. Lock the app, close it, and confirm the in-memory key is cleared on lock or session end.

## Plugin Host and Security
19. Register a sample plugin and confirm it appears in plugin metadata storage.
20. Invoke a plugin with limited API access and verify the plugin cannot directly read encrypted DB contents.
21. Simulate an unsigned or invalid plugin and confirm the app rejects it with an audit log event.

## Persistence and Recovery
22. Verify database writes use ACID transactions and recover gracefully on failure.
23. Test encrypted archive export and import restore path (local backup/restore only).
24. Confirm storage errors propagate explicit `AstraError` results, not silent failures.

## Settings, Platform, and Performance
25. Verify settings changes (appearance, lock timeout, telemetry opt-in, plugin preferences) are validated before commit.
26. Confirm operations such as encryption, DB I/O, transcription, and plugin invocation do not block the main UI thread.
27. Verify lock timeout and auto-lock occur after inactivity or system sleep.
28. Review logs to ensure only non-sensitive audit data is recorded.
