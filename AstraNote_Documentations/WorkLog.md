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
