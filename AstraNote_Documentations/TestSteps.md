# AstraNote Test Steps

## 1. Unlock and Session Resume
1. Launch the app and verify passphrase screen appears when no unlocked session exists.
2. Enter valid passphrase and verify note lists load.
3. Enable biometric unlock after successful passphrase unlock.
4. Simulate biometric unavailability or rejection and verify passphrase fallback appears.
5. Fail biometric unlock three consecutive times and verify passphrase fallback is enforced.

## 2. Normal Note Lifecycle (Unencrypted)
6. Create a normal note and save it.
7. Verify normal note title and content are persisted as plain text.
8. Edit normal note and verify note ID remains stable.
9. Force write failure and verify rollback preserves previous saved state.

## 3. Secure Note Lifecycle (Encrypted)
10. Enable secure mode from editor toolbar on a note.
11. Verify secure mode requires both expiration date and expiration time before save.
12. Set expiration timestamp in the past and verify save is rejected with user-visible message.
13. Save secure note and verify title/content are persisted as ciphertext with nonce and salt.
14. Corrupt secure payload and verify decrypt failure shows error while preserving stored record.

## 4. Secure Expiration Date-Time Behavior
15. Set expiration date/time in local timezone and save secure note.
16. Verify persisted policy uses UTC timestamp for expiration comparison.
17. Keep app open until expiration and verify secure note moves from active list to protected trash.
18. Expire secure note while app is closed and verify it moves to protected trash on next launch.
19. Verify foreground expiry shows in-app notice and background expiry schedules local notification.

## 5. Protected Trash Flow
20. Delete normal note and verify trash shows readable title and deletion time.
21. Delete secure note and verify trash shows lock badge and hides readable title.
22. Restore normal note and verify it returns to active list.
23. Attempt restore of secure note while app is locked and verify restore is blocked.
24. Unlock app and restore secure note, then verify it returns to active list.
25. Permanently delete secure note and verify ciphertext and linked attachments are unrecoverable.

## 6. Title Search (Option 1)
26. Enter query in top-bar search and verify normal notes are filtered by title.
27. While unlocked, verify secure notes can be found by title via in-memory matching.
28. Lock app and verify secure notes are excluded from search results.
29. After lock event, verify secure-title search cache is cleared from memory.

## 7. Voice Capture
30. Trigger voice capture from workspace top bar.
31. Save recording and verify file protection is enabled in app storage.
32. Verify transcription runs asynchronously and does not block UI.
33. Attempt recording over 10 minutes or 50 MB and verify app rejects with clear message.

## 8. Simple Plugin Support
34. Install plugin from local package and verify manifest validation occurs.
35. Enable plugin and verify metadata records enabled state, install path/hash, and last run status.
36. Run supported plugin action (text transform) and verify result is applied through normal save flow.
37. Force plugin timeout/error and verify note state remains unchanged and app stays responsive.
38. Disable and remove plugin and verify plugin no longer appears in enabled list.

## 9. Auto-Lock and Key Handling
39. Configure lock timeout and verify app locks after inactivity.
40. Put OS to sleep and verify app locks on resume.
41. Background app and verify lock behavior follows policy.
42. Verify lock clears in-memory key material.
43. With secure draft in progress, trigger lock and verify draft is safely persisted before lock completes.

## 10. Passphrase Change and Key Rotation
44. Change passphrase and verify secure notes and secure attachments are re-encrypted.
45. Verify normal notes remain unchanged by passphrase change.
46. Interrupt key rotation and verify next launch resumes or rolls back safely.
47. Use passphrase that derives identical key and verify app skips unnecessary re-encryption.

## 11. Export / Import and Reliability
48. Export backup and verify archive is encrypted, passphrase-protected, and schema-tagged.
49. Import compatible archive and verify data restore succeeds.
50. Import incompatible schema archive and verify operation is rejected with clear message.
51. Import archive with ID conflicts and verify imported notes receive new IDs.
52. Simulate storage exhaustion during import and verify operation is atomic with no partial commit.

## 12. Settings, Accessibility, and Audit
53. Update lock timeout, telemetry opt-in, and plugin preference flags and verify invalid values are rejected.
54. Verify core workflows support keyboard navigation and VoiceOver.
55. Verify telemetry excludes note text and note titles.
56. Verify audit logs include authentication failures and plugin validation/runtime failures without sensitive content.
