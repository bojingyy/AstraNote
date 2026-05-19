## Full Traceability Matrix

Evidence sources:
- Requirements: [AstraNote_Documentations/Requirement.md](AstraNote_Documentations/Requirement.md)
- Architecture: [AstraNote_Documentations/Architecture.md](AstraNote_Documentations/Architecture.md)
- Use Case UML: [AstraNote_Documentations/UML_Package/UseCaseDiagram.html](AstraNote_Documentations/UML_Package/UseCaseDiagram.html)
- Activity UML: [AstraNote_Documentations/UML_Package/ActivityDiagram.html](AstraNote_Documentations/UML_Package/ActivityDiagram.html)
- Class UML: [AstraNote_Documentations/UML_Package/ClassDiagram.html](AstraNote_Documentations/UML_Package/ClassDiagram.html)
- Object UML: [AstraNote_Documentations/UML_Package/ObjectDiagram.html](AstraNote_Documentations/UML_Package/ObjectDiagram.html)
- Deployment UML: [AstraNote_Documentations/UML_Package/DeploymentDiagram.html](AstraNote_Documentations/UML_Package/DeploymentDiagram.html)
- Non-Functional Verification: [AstraNote_Documentations/NonFunctionalVerification.md](AstraNote_Documentations/NonFunctionalVerification.md)

Legend:
- Coverage: Fully Traced or Partially Traced
- Evidence tags: A=Architecture, U=Use Case, ACT=Activity, C=Class, O=Object, D=Deployment, NFV=Non-Functional Verification Artifact

### Functional Requirements

| ID | Coverage | Evidence | Gap Note |
| --- | --- | --- | --- |
| FR1.1 | Fully Traced | R, A, C, U, ACT | First-launch passphrase creation is now explicitly modeled as a dedicated initialization branch in requirements and architecture (section 5.1). |
| FR1.2 | Fully Traced | A, U, ACT, C | Unlock path is explicitly modeled. |
| FR1.3 | Fully Traced | A, U, ACT, C, D | Optional biometric enrollment is explicitly modeled. |
| FR1.4 | Fully Traced | A, U, ACT, C, D | Biometric fallback threshold and passphrase fallback branch are explicit in activity behavior. |
| FR1.5 | Fully Traced | A, ACT, C, D | Biometric unavailability fallback is explicit in activity decision logic. |
| FR1.6 | Fully Traced | A, ACT, C | Biometric failure counter reset is explicit after successful biometric unlock. |
| FR2.1 | Fully Traced | A, U, ACT, C, O | Create/edit/delete with optional attachments is represented. |
| FR2.2 | Fully Traced | A, ACT, C, D | Plain-text save path is explicit. |
| FR2.3 | Fully Traced | A, C, O | Stable note identity is represented by persistent note IDs. |
| FR2.4 | Fully Traced | A, ACT, C, D | Atomic save and rollback semantics are represented. |
| FR2.5 | Fully Traced | A, ACT, C, D | Single-transaction move with rollback path is explicit. |
| FR3.1 | Fully Traced | A, U, ACT, C | Secure mode toggle is modeled. |
| FR3.2 | Fully Traced | A, U, ACT | Secure mode requires date and time in behavior. |
| FR3.8 | Fully Traced | A, ACT | Past-expiration rejection branch is explicit. |
| FR3.3 | Fully Traced | A, ACT, C, D | Encrypt-before-write path is explicit. |
| FR3.4 | Fully Traced | A, C, O | Stable secure-note ID is represented by persistent note identity model. |
| FR3.5 | Fully Traced | A, ACT, C, D | Atomic secure-write semantics are modeled. |
| FR3.6 | Fully Traced | A, ACT, C, D | Decrypt verification failure branch preserves record and shows error. |
| FR3.7 | Fully Traced | A, ACT, C, D | Secure delete routes encrypted note and attachments to trash in one flow. |
| FR4.1 | Fully Traced | A, U, ACT, C | Expiration checks are represented in policy and system behaviors. |
| FR4.2 | Fully Traced | A, U, C, O | Expire-on-next-launch behavior is structurally and behaviorally aligned. |
| FR4.3 | Fully Traced | A, U, ACT, C | Expired secure notes move out of active list into trash. |
| FR4.4 | Fully Traced | A, U, C, D | Foreground and background notification mechanisms are represented. |
| FR4.5 | Fully Traced | R, A, C, D | Time-rollback guard path is now explicitly modeled in requirements with clear behavioral semantics (activate guard, defer expiration checks, log and inform user) and referenced in architecture. |
| FR4.6 | Fully Traced | A, C, O | Local-time selection with UTC persistence is represented in architecture and models. |
| FR4.7 | Fully Traced | A, U, ACT | Explicit date/time controls are represented in secure-note flow. |
| FR5.1 | Fully Traced | A, U, ACT, C | All deletes flow through protected trash. |
| FR5.2 | Fully Traced | R, A, U, C, O | Trash listing behavior semantics are now explicitly detailed in requirements: normal notes show title+deletion-time; secure notes show deletion-time+lock-badge only. |
| FR5.3 | Fully Traced | R, A, C, O | Lock-badge behavior and hidden title semantics are now explicitly modeled in requirements with user-visible locked preview message in architecture (section 5.5). |
| FR5.4 | Fully Traced | A, U, ACT, C | Restore flow is explicit. |
| FR5.5 | Fully Traced | A, ACT, C, O | Restore-block-when-locked branch is explicit. |
| FR5.6 | Fully Traced | A, U, ACT, C | Permanent delete flow is explicit. |
| FR5.7 | Fully Traced | A, ACT, C, D | Wipe path for secure record and attachments is explicit. |
| FR6.1 | Fully Traced | A, U, ACT | Voice capture trigger is explicit. |
| FR6.2 | Fully Traced | R, A, C, D | Protected-recording write operation is now explicitly specified in requirements: occurs after recording completes, before note linkage, with security-mode-dependent encryption inheritance. |
| FR6.3 | Fully Traced | A, ACT | Voice size/duration rejection is explicit. |
| FR7.1 | Fully Traced | A, U, ACT, C | Inactivity lock is explicit. |
| FR7.2 | Fully Traced | A, U, ACT, C, D | Sleep/background lock trigger is explicit. |
| FR7.3 | Fully Traced | R, A, C | Background operation non-reset behavior is now explicitly detailed in requirements: timer continues during background ops, lock proceeds immediately after operation completes if timer expires. |
| FR7.4 | Fully Traced | A, U, ACT, C, O | Key clear on lock is explicit. |
| FR7.5 | Fully Traced | A, ACT, C | Draft persistence before lock completion is explicit. |
| FR8.1 | Fully Traced | A, U, ACT, C | Passphrase change flow is explicit. |
| FR8.2 | Fully Traced | A, ACT, C | Re-encryption of secure notes and attachments is explicit. |
| FR8.3 | Fully Traced | A, ACT, C, O | Old-key retention until completion is represented in model and flow. |
| FR8.4 | Fully Traced | A, U, ACT, C | Detect partial migration, complete-first attempt, and rollback path are explicit. |
| FR8.5 | Fully Traced | A, ACT, C | Identical-key rejection branch is explicit. |
| FR8.6 | Fully Traced | A, ACT, C | Rotation flow targets secure records only. |
| FR9.1 | Fully Traced | A, U, ACT, C, D | Encrypted, schema-tagged export is explicit. |
| FR9.2 | Fully Traced | A, U, ACT, C | Schema compatibility gate with error path is explicit. |
| FR9.3 | Fully Traced | A, ACT, C | ID-conflict reassignment is explicit. |
| FR9.4 | Fully Traced | A, ACT, C, D | Atomic import with rollback-and-guidance path is explicit. |
| FR10.1 | Fully Traced | A, U, ACT, C, O | Settings behavior and global plugin toggle update are explicit in use case and activity flows. |
| FR10.2 | Fully Traced | A, ACT, C | Settings validation decision and user-visible validation error branch are explicit in activity. |
| FR11.1 | Fully Traced | A, U, C, D | Install local plugin package use case is explicit. |
| FR11.2 | Fully Traced | A, U, ACT, C, O | Plugin manifest validation now has explicit use case and activity behavior branches. |
| FR11.3 | Fully Traced | A, U, C, O | Plugin management use case and state are represented. |
| FR11.4 | Fully Traced | A, ACT, C | Plugin execution through host API is explicit. |
| FR11.5 | Fully Traced | A, U, ACT, C, O | Plugin action is explicitly labeled and modeled as text-transform execution. |
| FR11.6 | Fully Traced | A, ACT, C | Success path applies plugin result through save flow. |
| FR11.7 | Fully Traced | A, ACT, C | Failure/timeout error path preserves note state. |
| FR11.8 | Fully Traced | A, C, O, D | Plugin metadata persistence is structurally represented. |
| FR12.1 | Fully Traced | A, U, ACT | Title search input and behavior are explicit. |
| FR12.2 | Fully Traced | A, ACT, C | Normal-title search path is explicit. |
| FR12.3 | Fully Traced | A, C, O, D | Secure titles encrypted at rest and non-indexed in storage are represented. |
| FR12.4 | Fully Traced | A, ACT, C, O | Unlocked-only secure-title matching is explicit. |
| FR12.5 | Fully Traced | A, ACT, C, O | Lock-time secure-title cache clearing is explicit. |
| FR12.6 | Fully Traced | A, ACT | Locked search excludes secure titles via locked branch. |
| FR13.1 | Fully Traced | A, U, ACT, C | Image attach use case and behavior are explicit. |
| FR13.2 | Fully Traced | A, ACT, C, D | Image protection aligned with storage/security mode in flow and layers. |
| FR13.3 | Fully Traced | A, ACT | Image size-limit rejection branch is explicit. |
| FR14.1 | Fully Traced | A, U, ACT, C | Subject create with validation is explicit. |
| FR14.2 | Fully Traced | A, ACT, C | Rename validation and save are explicit. |
| FR14.3 | Fully Traced | A, ACT, C | Delete confirmation behavior is explicit. |
| FR14.4 | Fully Traced | A, ACT, C, O | Ungroup-on-delete behavior is explicit. |
| FR14.5 | Fully Traced | A, ACT, C, O | Assign/move between groups is represented in subject-management behavior. |
| FR14.6 | Fully Traced | A, U, ACT, C, O | All Notes filter is explicitly represented in use case and activity behavior. |

### Non-Functional Requirements

| ID | Coverage | Evidence | Gap Note |
| --- | --- | --- | --- |
| NFR1.1 | Fully Traced | A, C, NFV | Benchmark protocol and <=1s unlock acceptance criteria are captured in the supplemental verification artifact. |
| NFR1.2 | Fully Traced | A, C, NFV | 10k-note <=2s unlock benchmark acceptance criteria are captured in the supplemental verification artifact. |
| NFR1.3 | Fully Traced | A, NFV | Measurement protocol explicitly excludes manual passphrase entry time in supplemental verification artifact. |
| NFR2.1 | Fully Traced | A, ACT, C | Async transcription and plugin execution are explicit; heavy operations are service-based. |
| NFR2.2 | Fully Traced | A, NFV | 60 FPS frame-time verification and acceptance criteria are explicitly captured in supplemental artifact. |
| NFR3.1 | Fully Traced | A, C, D | Explicit confidentiality enforcement is now fully documented in architecture (section 4.1) with clear data flow assertions for all sinks: disk persistence stores ciphertext only, logs are sanitized, caches are in-memory only and cleared on lock, exports are encrypted, UI display is transient, and plugins receive content through controlled API only. |
| NFR3.2 | Fully Traced | A, ACT, C, O, D | Memory-only secure-title cache plus lock-time clearing are explicit. |
| NFR4.1 | Fully Traced | A, ACT, C | Authenticated decryption verification/failure behavior is explicit. |
| NFR4.2 | Fully Traced | A, ACT, C | Verification failure error with preserved record is explicit. |
| NFR5.1 | Fully Traced | A, ACT, C, D | ACID transaction boundary is explicit in repositories/import/delete flows. |
| NFR5.2 | Fully Traced | A, ACT, C | Migration/import rollback semantics are explicit. |
| NFR5.3 | Fully Traced | R, A, ACT, C | Recovery instructions now explicitly cover three corruption scenarios: (a) partial passphrase rotation with completion/rollback logic; (b) corrupted import with rollback and storage guidance; (c) database corruption with integrity checks and step-by-step recovery. |
| NFR6.1 | Fully Traced | A, C, NFV | Exponential lockout progression verification is explicitly defined in supplemental artifact. |
| NFR6.2 | Fully Traced | A, C, D, NFV | Lockout-event audit log verification is explicitly defined in supplemental artifact. |
| NFR6.3 | Fully Traced | A, C, NFV | Auth/plugin failure audit logging and sensitive-content exclusion checks are explicitly defined in supplemental artifact. |
| NFR7.1 | Fully Traced | A, C, O, NFV | Telemetry opt-in and non-sensitive metric scope checks are explicitly defined in supplemental artifact. |
| NFR7.2 | Fully Traced | A, C, O, NFV | Telemetry payload exclusion checks for note/title/content-derived data are explicitly defined in supplemental artifact. |
| NFR8.1 | Fully Traced | A, NFV | Accessibility verification procedure for keyboard and VoiceOver workflows is explicitly defined in supplemental artifact. |
| NFR9.1 | Fully Traced | A, NFV | English-first packaging verification is explicitly defined in supplemental artifact. |
| NFR9.2 | Fully Traced | A, NFV | Localization extensibility verification is explicitly defined in supplemental artifact. |

## Summary

- Functional requirements: 76 total, 76 fully traced, 0 partially traced.
- Non-functional requirements: 20 total, 20 fully traced, 0 partially traced.
- **Total: 96 requirements, 96 fully traced, 0 partially traced. 100% coverage.**

## Remaining Gaps To Close

All gaps have been closed. All 96 requirements (76 FR + 20 NFR) are now fully traced with explicit behavioral specifications in requirements and supporting evidence across architecture, UML diagrams, and verification artifacts.