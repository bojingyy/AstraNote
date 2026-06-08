# AstraNotes User Stories

## 1. Set up and authenticate
- As a user, I want to set a master passphrase on first launch and optionally add biometric unlock so I can protect my secure notes without typing my passphrase every time.
- Acceptance criteria:
  - On first launch, before any notes are stored, I am required to create and confirm a master passphrase before the workspace becomes available.
  - On later launches, the workspace opens directly; I am only asked to authenticate at the moment I open or save a secure note.
  - Once I've unlocked at least once, I can enable biometric authentication from Settings as an additional option in the secure-note authentication prompt.
  - The authentication prompt always offers passphrase entry alongside the biometric action, so a declined, unavailable, or failed biometric attempt never locks me out — I can simply type my passphrase in the same prompt.

## 2. Create and edit normal notes
- As a user, I want normal notes to be fast and simple so I can capture ideas with minimal friction.
- Acceptance criteria:
  - I can create and edit normal notes without enabling secure mode.
  - Normal note titles and content are stored as plain text, with no encryption overhead.
  - I can optionally attach images (chosen from local file storage) or voice recordings to a note.
  - Each note keeps a stable identity across edits, and a failed save leaves the previously stored version untouched.

## 3. Protect a note with secure mode
- As a user, I want to mark individual notes as secure so I can protect sensitive content without affecting how I work with everything else.
- Acceptance criteria:
  - I can turn secure mode on for any note from the toggle in the editor's toolbar — there are no expiration or scheduling fields to configure.
  - When I save a secure note, its title and content are encrypted on-device before anything is written to storage; only ciphertext, the authentication tag, and a salt are persisted.
  - I can give a secure note a display alias that stands in for its real title whenever the note is locked or shown in trash.
  - Each secure note keeps a stable identity across edits, and a failed save leaves the previously stored ciphertext untouched.

## 4. Open and save secure notes
- As a user, I want secure notes to ask me to authenticate exactly when they need the encryption key, so I'm not interrupted at any other time.
- Acceptance criteria:
  - Opening a secure note, saving a new or edited one, or working with its attachments prompts me for my passphrase or biometrics at that moment.
  - Once I authenticate successfully, the action that triggered the prompt continues automatically — I don't have to repeat it.
  - Secure notes stay in my active note list for as long as I keep them; the app never moves or expires them on its own.
  - If a secure note's stored data ever fails to verify, I see a clear error and the original record is left exactly as it was.

## 5. Manage trash for normal and secure notes
- As a user, I want a trash view so I can restore deleted notes or remove them permanently.
- Acceptance criteria:
  - Deleting any note — normal or secure — moves it, along with its attachments, to protected trash in one all-or-nothing step.
  - Normal trashed notes show their title and the time they were deleted.
  - Secure trashed notes show only their display alias and a lock badge — never a decrypted title — until they are restored and unlocked.
  - Restoring a secure note requires an active unlocked session; if I'm locked out, the app tells me clearly instead of attempting the restore.
  - Permanently deleting a secure note wipes its ciphertext and every linked attachment beyond recovery.

## 6. Search by note title
- As a user, I want title search so I can quickly find any note, secure or not.
- Acceptance criteria:
  - The workspace top bar provides a search field that filters the note list as I type.
  - Normal note titles are matched directly against their stored plaintext.
  - Secure note titles are never decrypted for search — instead, each secure note carries a separate, non-sensitive display alias that the search matches against, using the same case-insensitive comparison as normal titles.
  - Because matching never touches decrypted content, secure notes are just as searchable by their alias whether my session is locked or unlocked.

## 7. Capture voice
- As a user, I want to record voice and attach it to notes so I can capture audio alongside written content.
- Acceptance criteria:
  - The editor's top bar includes a voice capture action that records through the system microphone.
  - A finished recording is written to app storage and linked to the note as an attachment; its confidentiality at rest comes from the host's disk-level encryption (e.g., FileVault), the same protection every file in the app's storage relies on.
  - A recording over 50 MB is rejected before it's stored, and I'm told the size limit clearly.

## 8. Attach images to notes
- As a user, I want to attach images from my computer to a note so I can keep visual references alongside my writing.
- Acceptance criteria:
  - The editor provides an action to pick a local image file and attach it to the current note.
  - The attached image is written to app storage and linked to the note, with the same disk-level confidentiality model described for voice recordings.
  - An image over 20 MB is rejected before it's stored, and I'm told the size limit clearly.

## 9. Manage a plugin catalog
- As a user, I want to install and manage simple plugins so I can curate the extensions available to the app.
- Acceptance criteria:
  - I can install a plugin by picking its package file locally; the app validates its identity fields (ID, display name, version, capabilities) and rejects anything malformed, unreadable, or already installed, with a clear error.
  - I can enable, disable, and remove plugins from plugin management, with a confirmation step before removal.
  - A global toggle in Settings lets me turn all plugins off at once without losing their installed records.
  - Plugins never touch my notes or data directly — every interaction goes through a host-mediated API, and a plugin that fails or times out is contained without affecting the app or my notes.

## 10. Trust the lock boundary
- As a user, I want to know that locking the app reliably protects my secure notes whenever I step away, so I don't have to think about session timing.
- Acceptance criteria:
  - Every time I relaunch the app, it starts locked — the encryption key is never written to or restored from disk, so I always re-authenticate at relaunch.
  - Sending the app to the background or letting the system sleep clears the in-memory key immediately, unless an export or passphrase change is actively running, in which case the lock is applied as soon as that operation finishes.
  - Once locked, the workspace stays usable for normal notes; any secure-note action simply re-prompts me to authenticate, exactly as it would on a fresh launch.

## 11. Change passphrase safely
- As a user, I want to change my master passphrase without risking my secure data, so I can rotate credentials with confidence.
- Acceptance criteria:
  - Changing my passphrase re-encrypts every secure note under the new key as a single all-or-nothing operation — there's never a moment where some notes are under the old key and others under the new one.
  - Normal notes and attachment files are untouched by a passphrase change, since they were never encrypted at the app layer.
  - If something interrupts the change partway (e.g., the app quits), my data is left exactly as it was under the original passphrase; the next time I unlock, the app quietly clears any leftover in-progress marker and logs the recovery — I don't have to do anything.
  - If my new passphrase would derive the same key as my current one, the app rejects it with a clear message and asks me to choose a different one.

## 12. Export and import backups
- As a user, I want to export and import encrypted backups so I can move my data or recover it after a device issue.
- Acceptance criteria:
  - Exporting produces a single encrypted archive containing my notes and their metadata, tagged with a schema version and protected by my key material.
  - Importing only accepts archives whose schema version is no newer than what my app supports; anything newer is rejected with a clear mismatch error.
  - If an imported archive's identifiers collide with notes I already have, the app assigns the imported records fresh identifiers so both sets of data coexist; a stricter mode that rejects on any collision is also available.
  - Import runs as a single all-or-nothing operation — if anything goes wrong partway through, my existing data is left untouched and I see a clear explanation of the failure.

## 13. Organize notes with subject groups
- As a user, I want to create subject groups (folders) in the sidebar so I can organize my notes the way I think about them.
- Acceptance criteria:
  - I can create a new subject group with a non-empty, unique name from the sidebar.
  - I can rename an existing subject group, with the same non-empty/unique validation applied before the change is saved.
  - I can delete a subject group; if it still contains notes, I'm asked to confirm before the group disappears.
  - Notes that belonged to a deleted group become ungrouped — they are never deleted along with the group.
  - I can assign any note to a group and move it between groups freely.
  - The sidebar always shows every subject group plus an "All Notes" view that lists every note regardless of grouping.

## 14. Stay informed without being interrupted
- As a user, I want clear, unobtrusive feedback about what the app is doing so I always know whether an action succeeded.
- Acceptance criteria:
  - Successes, warnings, and errors appear as transient pop-up notifications near the top of the workspace and dismiss themselves after a few seconds.
  - The app never collects or transmits telemetry or usage analytics — feedback is purely local and momentary, consistent with the app's local-first design.
