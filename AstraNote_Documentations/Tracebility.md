# Full Traceability Matrix

This matrix traces the finalized requirement set in `Requirement.md` to the current design documentation and finalized UML package. Coverage here is documentation-level: a requirement is marked `Fully Traced` when it is explicitly represented in the requirements and in one or more current design artifacts.

## Evidence Sources

- Requirements: [AstraNote_Documentations/Requirement.md](AstraNote_Documentations/Requirement.md)
- Architecture: [AstraNote_Documentations/Architecture.md](AstraNote_Documentations/Architecture.md)
- Use Case UML: [AstraNote_Documentations/UML_Package/UseCaseDiagram.html](AstraNote_Documentations/UML_Package/UseCaseDiagram.html)
- Activity UML: [AstraNote_Documentations/UML_Package/ActivityDiagram.html](AstraNote_Documentations/UML_Package/ActivityDiagram.html)
- Class UML: [AstraNote_Documentations/UML_Package/ClassDiagram.html](AstraNote_Documentations/UML_Package/ClassDiagram.html)
- Object UML: [AstraNote_Documentations/UML_Package/ObjectDiagram.html](AstraNote_Documentations/UML_Package/ObjectDiagram.html)
- Deployment UML: [AstraNote_Documentations/UML_Package/DeploymentDiagram.html](AstraNote_Documentations/UML_Package/DeploymentDiagram.html)
- Non-Functional Verification: [AstraNote_Documentations/NonFunctionalVerification.md](AstraNote_Documentations/NonFunctionalVerification.md)

## Legend

- Evidence tags:
  - `R` = Requirements
  - `A` = Architecture
  - `U` = Use Case UML
  - `ACT` = Activity UML
  - `C` = Class UML
  - `O` = Object UML
  - `D` = Deployment UML
  - `NFV` = Non-Functional Verification artifact
- Coverage values:
  - `Fully Traced` = explicitly represented in the finalized requirements and current design documentation
  - `Partially Traced` = requirement exists but some intended design behavior is not yet explicit in the documentation set

## Functional Requirements

| ID | Coverage | Evidence | Design Trace Note |
| --- | --- | --- | --- |
| FR1.1 | Fully Traced | R, A, U, ACT, C | First launch is a dedicated passphrase-setup branch that blocks other note work until credentials are created. |
| FR1.2 | Fully Traced | R, A, U, ACT, C, O | Later launches route directly to the workspace; secure-note authentication happens only in context when key material is needed. |
| FR1.3 | Fully Traced | R, A, U, ACT, C, D | Biometric authentication is modeled as an optional setting-backed alternative to passphrase entry. |
| FR1.4 | Fully Traced | R, A, U, ACT, C, D | The secure-access prompt exposes passphrase entry and biometric action together, with same-prompt fallback. |
| FR1.5 | Fully Traced | R, A, ACT, C, D | Biometric-unavailable and biometric-disabled paths are explicitly handled while keeping the passphrase path usable. |
| FR2.1 | Fully Traced | R, A, U, ACT, C, O | Normal notes support create, edit, delete, plus optional image and recording attachments. |
| FR2.2 | Fully Traced | R, A, ACT, C, D | Plaintext storage for normal-note title and content is explicit in data contracts and persistence topology. |
| FR2.3 | Fully Traced | R, A, C, O | Stable note identity is modeled through persisted note IDs that survive edits. |
| FR2.4 | Fully Traced | R, A, ACT, C, D | Normal-note writes are traced to atomic transactional storage with rollback on failure. |
| FR2.5 | Fully Traced | R, A, ACT, C, D | Normal-note deletion moves the note and attachments to protected trash in one all-or-nothing transaction. |
| FR3.1 | Fully Traced | R, A, U, ACT, C | Secure mode is represented as a per-note editor toggle in the save flow. |
| FR3.2 | Fully Traced | R, A, U, ACT, C | Secure-mode enablement is immediate on save and carries no time-based policy fields. |
| FR3.3 | Fully Traced | R, A, ACT, C, D | Secure-note title and content are encrypted before persistence; storage retains ciphertext, nonce, tag, salt, and alias only. |
| FR3.4 | Fully Traced | R, A, C, O | Secure notes retain stable note IDs across edits. |
| FR3.5 | Fully Traced | R, A, ACT, C, D | Secure-note writes are explicitly atomic and rollback-safe. |
| FR3.6 | Fully Traced | R, A, ACT, C, D | Decryption/authentication failure preserves the stored record and surfaces a user-visible error. |
| FR3.7 | Fully Traced | R, A, ACT, C, D | Secure-note deletion moves encrypted note data and attachments into protected trash as one transaction. |
| FR3.8 | Fully Traced | R, A, U, ACT, C, O | Opening, saving, and continuing secure-note attachment work all step up to authentication and automatically resume on success. |
| FR4.1 | Fully Traced | R, A, U, ACT, C | Secure notes remain in the active list until the user explicitly deletes them. |
| FR4.2 | Fully Traced | R, A, U, C, O | The finalized design explicitly omits expiration, sweep, checkpoint, and expiry-notification behavior. |
| FR5.1 | Fully Traced | R, A, U, ACT, C | All note deletes flow into protected trash rather than immediate destruction. |
| FR5.2 | Fully Traced | R, A, U, ACT, C, O | Trash presentation differentiates normal-note title/time from secure-note locked presentation and deletion time. |
| FR5.3 | Fully Traced | R, A, ACT, C, O | Secure trash items use the persisted `secureTitleAlias` and a fixed locked-preview explanation without decrypting note titles. |
| FR5.4 | Fully Traced | R, A, U, ACT, C | Restore paths are explicit for trashed notes. |
| FR5.5 | Fully Traced | R, A, ACT, C, O | Secure-note restore requires an unlocked session and fails clearly when key material is unavailable. |
| FR5.6 | Fully Traced | R, A, U, ACT, C | Permanent delete is modeled as a separate trash action. |
| FR5.7 | Fully Traced | R, A, ACT, C, D | Permanent deletion of a secure note wipes ciphertext-backed records and linked attachment files with no recovery path. |
| FR6.1 | Fully Traced | R, A, U, ACT, C, D | Voice capture is a top-bar editor action backed by microphone permission and local recording. |
| FR6.2 | Fully Traced | R, A, ACT, C, D | Audio is written after recording completes, then linked as an attachment with an `isEncrypted` bookkeeping flag only. |
| FR6.3 | Fully Traced | R, A, ACT, C, O | Oversize voice attachments are rejected before storage with an explicit 50 MB limit path. |
| FR13.1 | Fully Traced | R, A, U, ACT, C, D | Image attachment is modeled as local-file selection only, with no camera or remote URL source. |
| FR13.2 | Fully Traced | R, A, ACT, C, D | Image bytes are stored as plain files with the same bookkeeping-only `isEncrypted` flag and disk-level confidentiality model as audio. |
| FR13.3 | Fully Traced | R, A, ACT, C, O | Oversize image attachments are rejected before storage with an explicit 20 MB limit path. |
| FR7.1 | Fully Traced | R, A, U, ACT, C, O, D | Relaunch begins in a locked state because in-memory key material is never persisted or restored from disk. |
| FR7.2 | Fully Traced | R, A, U, ACT, C, D | Background and sleep are the immediate-lock triggers; foreground and interaction events are observed without triggering lock. |
| FR7.3 | Fully Traced | R, A, ACT, C, O | Lock deferral while export or passphrase rotation is in flight is explicitly modeled, then applied after completion. |
| FR7.4 | Fully Traced | R, A, U, ACT, C, O | Locking clears in-memory key material while leaving normal-note workspace usage intact and secure actions gated. |
| FR8.1 | Fully Traced | R, A, U, ACT, C | Passphrase change is a settings-driven flow available while unlocked. |
| FR8.2 | Fully Traced | R, A, ACT, C | Passphrase change re-encrypts every secure-note payload under the newly derived key. |
| FR8.3 | Fully Traced | R, A, ACT, C, D | Rotation is represented as one atomic transaction that commits both re-encrypted notes and updated credentials together. |
| FR8.4 | Fully Traced | R, A, ACT, C, O | Interrupted rotation leaves original credentials intact and clears the stale pending-rotation marker on next unlock. |
| FR8.5 | Fully Traced | R, A, ACT, C | Identical derived-key/passphrase changes are explicitly rejected before any write occurs. |
| FR8.6 | Fully Traced | R, A, ACT, C, D | Normal notes and attachment files are excluded from rotation because attachments are not app-layer encrypted. |
| FR9.1 | Fully Traced | R, A, U, ACT, C, D | Export produces a schema-tagged encrypted archive after stripping runtime-only and sensitive fields. |
| FR9.2 | Fully Traced | R, A, U, ACT, C | Import validates schema compatibility and rejects newer-archive versions with a mismatch error. |
| FR9.3 | Fully Traced | R, A, ACT, C | Import conflict handling traces both fresh-ID regeneration and the stricter reject-on-collision mode. |
| FR9.4 | Fully Traced | R, A, U, ACT, C, D | Import executes atomically and rolls back fully on decode, decrypt, or merge failure. |
| FR10.1 | Fully Traced | R, A, U, ACT, C, O | Settings are intentionally limited to exactly two toggles: plugins enabled and biometric unlock enabled. |
| FR10.2 | Fully Traced | R, A, ACT, C | Settings changes are validated before commit and reject invalid values with user-visible feedback. |
| FR10.3 | Fully Traced | R, A, C, O | Workspace feedback is traced as transient toast-style pop-up notifications rather than inline editor messaging. |
| FR11.1 | Fully Traced | R, A, U, ACT, C, D | Plugin installation comes from a user-selected local package file and its raw bundle bytes. |
| FR11.2 | Fully Traced | R, A, U, ACT, C, O | Manifest-field validation, unreadable-bundle rejection, and duplicate-plugin-ID rejection are explicit. |
| FR11.3 | Fully Traced | R, A, U, ACT, C, O | Plugin management covers install, enable, disable, and remove, with confirmation before removal. |
| FR11.4 | Fully Traced | R, A, ACT, C | Plugins are constrained to the host API surface and never touch repositories directly. |
| FR11.5 | Fully Traced | R, A, U, ACT, C | The gated execution surface exists at the service layer only; the finalized UI intentionally omits plugin execution controls. |
| FR11.6 | Fully Traced | R, A, ACT, C, D | Timeout-guarded plugin execution surfaces typed failures, audit logs outcomes, and prevents host crashes or note corruption. |
| FR11.7 | Fully Traced | R, A, C, O, D | Installed-plugin metadata and separately keyed bundle bytes are both explicit in the current data model and deployment view. |
| FR12.1 | Fully Traced | R, A, U, ACT, C | Search input is represented in the workspace flow as title-based note filtering. |
| FR12.2 | Fully Traced | R, A, ACT, C | Normal-note title search maps directly to `plainTitle`. |
| FR12.3 | Fully Traced | R, A, ACT, C, O, D | Secure notes persist `secureTitleAlias` as the only searchable/displayable surrogate; plaintext secure titles are never stored. |
| FR12.4 | Fully Traced | R, A, ACT, C, O | Secure-note title search uses case-insensitive alias matching only and does not hold decrypted titles in memory. |
| FR12.5 | Fully Traced | R, A, ACT, C, O | Secure-note search availability is independent of lock state because matching never depends on decrypted title data. |
| FR14.1 | Fully Traced | R, A, U, ACT, C | Subject creation requires a non-empty, unique name from the sidebar workflow. |
| FR14.2 | Fully Traced | R, A, ACT, C | Subject rename applies the same non-empty and unique validation before commit. |
| FR14.3 | Fully Traced | R, A, U, ACT, C | Subject deletion includes confirmation when notes are still assigned. |
| FR14.4 | Fully Traced | R, A, ACT, C, O | Deleting a subject ungroups notes instead of deleting them. |
| FR14.5 | Fully Traced | R, A, ACT, C, O | Note-to-subject assignment and movement between groups are represented in the service and workspace flows. |
| FR14.6 | Fully Traced | R, A, U, ACT, C, O | The sidebar includes both subject groups and the `All Notes` filter. |

## Non-Functional Requirements

| ID | Coverage | Evidence | Design Trace Note |
| --- | --- | --- | --- |
| NFR1.1 | Fully Traced | R, A, C, NFV | PBKDF2-HMAC-SHA256 authentication performance is explicitly defined and paired with a target-hardware benchmark protocol. |
| NFR1.2 | Fully Traced | R, A, C, NFV | Authentication latency is traced as independent of note count because there is no whole-app unlock path tied to dataset size. |
| NFR1.3 | Fully Traced | R, NFV | The measurement method explicitly excludes manual passphrase entry time. |
| NFR2.1 | Fully Traced | R, A, ACT, C, D | Encryption, database I/O, and plugin execution are all documented as actor-isolated asynchronous operations off the main UI thread. |
| NFR2.2 | Fully Traced | R, A, NFV | UI responsiveness is tied to an explicit 60 FPS verification procedure during representative workflows. |
| NFR3.1 | Fully Traced | R, A, C, D, NFV | The confidentiality boundary is explicit across persistence, logging, caching, and encrypted export: no decrypted secure-note content is written out. |
| NFR3.2 | Fully Traced | R, A, ACT, C, O, NFV | Decrypted secure content is transient in memory only while needed, and title search never holds decrypted titles because it uses alias-only matching. |
| NFR4.1 | Fully Traced | R, A, ACT, C, NFV | Authenticated encryption and explicit tamper detection are modeled and verification-tested through AES-GCM failure scenarios. |
| NFR4.2 | Fully Traced | R, A, ACT, C, NFV | Verification failure is documented to preserve the stored record while surfacing a clear user error. |
| NFR5.1 | Fully Traced | R, A, ACT, C, D, NFV | All high-impact writes are traced to ACID transaction boundaries that either commit fully or preserve the previous state. |
| NFR5.2 | Fully Traced | R, A, ACT, C, NFV | Recovery paths are explicit for interrupted passphrase rotation and interrupted import rollback, including no-manual-intervention recovery. |
| NFR6.1 | Fully Traced | R, A, C, NFV | Lockout escalation after repeated failed unlock attempts is explicit in both design and verification artifacts. |
| NFR6.2 | Fully Traced | R, A, C, D, NFV | Lockout events are tied to the audit logger and to explicit audit-log verification. |
| NFR6.3 | Fully Traced | R, A, C, D, NFV | Authentication, rotation, plugin lifecycle, and export/import audit events are all documented as sanitized, non-content logs only. |
| NFR7.1 | Fully Traced | R, A, D, NFV | The local-first privacy model explicitly excludes telemetry and analytics collection or transmission of any kind. |

## Summary

- Functional requirements traced: 68 of 68
- Non-functional requirements traced: 15 of 15
- Total requirements traced: 83 of 83
- Coverage result: 83 `Fully Traced`, 0 `Partially Traced`

## Alignment Corrections From The Previous Matrix

- Removed obsolete references to requirements that no longer exist in the finalized set, including old IDs such as `FR1.6`, `FR7.5`, `FR11.8`, `FR12.6`, `NFR7.2`, `NFR8.1`, `NFR9.1`, and `NFR9.2`.
- Updated the requirement inventory from `96` entries to the finalized `83` entries now present in `Requirement.md`.
- Realigned the matrix to the current UML/design scope, which explicitly excludes a later-launch whole-app unlock screen, secure-note expiration, expiry notifications, draft-persistence-on-lock behavior, telemetry settings, lock-timeout settings, plugin execution UI, transcription, secure-title caching, and SQLite-based persistence.
