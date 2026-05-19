## Full Traceability Matrix

Evidence sources:
- Requirements: [AstraNote_Documentations/Requirement.md](AstraNote_Documentations/Requirement.md)
- Architecture: [AstraNote_Documentations/Architecture.md](AstraNote_Documentations/Architecture.md)
- Use Case UML: [AstraNote_Documentations/UML_Package/UseCaseDiagram.html](AstraNote_Documentations/UML_Package/UseCaseDiagram.html)
- Activity UML: [AstraNote_Documentations/UML_Package/ActivityDiagram.html](AstraNote_Documentations/UML_Package/ActivityDiagram.html)
- Class UML: [AstraNote_Documentations/UML_Package/ClassDiagram.html](AstraNote_Documentations/UML_Package/ClassDiagram.html)
- Object UML: [AstraNote_Documentations/UML_Package/ObjectDiagram.html](AstraNote_Documentations/UML_Package/ObjectDiagram.html)
- Deployment UML: [AstraNote_Documentations/UML_Package/DeploymentDiagram.html](AstraNote_Documentations/UML_Package/DeploymentDiagram.html)

Legend:
- Coverage: Fully Traced or Partially Traced
- Evidence tags: A=Architecture, U=Use Case, ACT=Activity, C=Class, O=Object, D=Deployment

### Functional Requirements

| ID | Coverage | Evidence | Gap Note |
| --- | --- | --- | --- |
| FR1.1 | Partially Traced | A, C, U, ACT | First-launch passphrase creation before any storage is not explicit as a dedicated behavioral branch. |
| FR1.2 | Fully Traced | A, U, ACT, C | Unlock path is explicitly modeled. |
| FR1.3 | Fully Traced | A, U, ACT, C, D | Optional biometric enrollment is explicitly modeled. |
| FR1.4 | Partially Traced | A, U, C, D | Fallback exists, but the explicit three-failure threshold is not shown in UML behavior. |
| FR1.5 | Partially Traced | A, C, D | Biometric unavailability handling is architectural; no explicit behavior branch in activity. |
| FR1.6 | Partially Traced | A, C | Biometric failure counter reset is structural, not behaviorally explicit. |
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
| FR4.5 | Partially Traced | A, C, D | Time rollback protection is structural, but explicit activity branch is not shown. |
| FR4.6 | Fully Traced | A, C, O | Local-time selection with UTC persistence is represented in architecture and models. |
| FR4.7 | Fully Traced | A, U, ACT | Explicit date/time controls are represented in secure-note flow. |
| FR5.1 | Fully Traced | A, U, ACT, C | All deletes flow through protected trash. |
| FR5.2 | Partially Traced | A, U, C, O | Trash listing behavior is present, but title/deletion-time/lock-badge detail is mostly structural. |
| FR5.3 | Partially Traced | A, C, O | Lock-badge without readable secure title is represented structurally; behavior labels are not explicit. |
| FR5.4 | Fully Traced | A, U, ACT, C | Restore flow is explicit. |
| FR5.5 | Fully Traced | A, ACT, C, O | Restore-block-when-locked branch is explicit. |
| FR5.6 | Fully Traced | A, U, ACT, C | Permanent delete flow is explicit. |
| FR5.7 | Fully Traced | A, ACT, C, D | Wipe path for secure record and attachments is explicit. |
| FR6.1 | Fully Traced | A, U, ACT | Voice capture trigger is explicit. |
| FR6.2 | Partially Traced | A, C, D | Protected audio storage is architectural/deployment-level; activity does not explicitly show protected recording write. |
| FR6.3 | Fully Traced | A, ACT | Voice size/duration rejection is explicit. |
| FR7.1 | Fully Traced | A, U, ACT, C | Inactivity lock is explicit. |
| FR7.2 | Fully Traced | A, U, ACT, C, D | Sleep/background lock trigger is explicit. |
| FR7.3 | Partially Traced | A, C | Background operation timer exclusion is architectural but not explicit in activity. |
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
| FR10.1 | Partially Traced | A, C, O | Settings model is present; dedicated settings behavior/use case is not explicit in behavioral diagrams. |
| FR10.2 | Partially Traced | A, C | Validation behavior is architectural/service-level but not explicit in activity. |
| FR11.1 | Fully Traced | A, U, C, D | Install local plugin package use case is explicit. |
| FR11.2 | Partially Traced | A, C, O | Manifest validation is structural/service-level; behavior branch is not explicit. |
| FR11.3 | Fully Traced | A, U, C, O | Plugin management use case and state are represented. |
| FR11.4 | Fully Traced | A, ACT, C | Plugin execution through host API is explicit. |
| FR11.5 | Partially Traced | A, C, O | At least one action type is implied but not explicitly labeled as text transform in behavior. |
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
| FR14.6 | Partially Traced | A, U, ACT, C, O | Group management is explicit; All Notes filter remains implied rather than named as its own node. |

### Non-Functional Requirements

| ID | Coverage | Evidence | Gap Note |
| --- | --- | --- | --- |
| NFR1.1 | Partially Traced | A, C | Unlock flow exists, but concrete 1-second benchmark is not represented in UML artifacts. |
| NFR1.2 | Partially Traced | A, C | 10k-note, 2-second objective is not represented in UML artifacts. |
| NFR1.3 | Partially Traced | A | Manual entry exclusion from measurement is requirement text only. |
| NFR2.1 | Fully Traced | A, ACT, C | Async transcription and plugin execution are explicit; heavy operations are service-based. |
| NFR2.2 | Partially Traced | A | 60 FPS target is not represented in UML artifacts. |
| NFR3.1 | Partially Traced | A, C, D | Strong confidentiality boundaries are represented, but a direct UML assertion covering every sink is not explicit. |
| NFR3.2 | Fully Traced | A, ACT, C, O, D | Memory-only secure-title cache plus lock-time clearing are explicit. |
| NFR4.1 | Fully Traced | A, ACT, C | Authenticated decryption verification/failure behavior is explicit. |
| NFR4.2 | Fully Traced | A, ACT, C | Verification failure error with preserved record is explicit. |
| NFR5.1 | Fully Traced | A, ACT, C, D | ACID transaction boundary is explicit in repositories/import/delete flows. |
| NFR5.2 | Fully Traced | A, ACT, C | Migration/import rollback semantics are explicit. |
| NFR5.3 | Partially Traced | A, ACT, C | Recovery instructions are explicit for import/rotation cases, not for all corruption scenarios. |
| NFR6.1 | Partially Traced | A, C | Rate-limit concept exists; exponential lockout policy details are not explicit in behavior. |
| NFR6.2 | Partially Traced | A, C, D | Audit logging component exists, but lockout-event logging behavior is not explicit. |
| NFR6.3 | Partially Traced | A, C | Logging requirements are architectural; behavior-level audit events are not explicitly mapped in UML. |
| NFR7.1 | Partially Traced | A, C, O | Telemetry opt-in setting is represented; operational metric scope is not explicit in UML. |
| NFR7.2 | Partially Traced | A, C, O | Telemetry exclusion of note/title data is requirement text plus architecture intent, not explicit behavior. |
| NFR8.1 | Partially Traced | A | Accessibility support is out-of-band to current UML behavior detail. |
| NFR9.1 | Partially Traced | A | English-first delivery is requirement text only. |
| NFR9.2 | Partially Traced | A | Localization architecture intent is documented, but not explicitly represented in UML artifacts. |

## Summary

- Functional requirements: 76 total, 63 fully traced, 13 partially traced.
- Non-functional requirements: 20 total, 6 fully traced, 14 partially traced.

## Remaining Gaps To Close

1. Add explicit behavioral nodes for biometric failure-count policy and fallback thresholds (FR1.4, FR1.5, FR1.6).
2. Add explicit settings workflow behavior (FR10.1, FR10.2).
3. Add explicit plugin-manifest validation and text-transform action labels in behavior (FR11.2, FR11.5).
4. Add explicit All Notes filter node in use case or activity (FR14.6).
5. Add a supplemental non-functional verification artifact for performance, accessibility, localization, telemetry boundaries, and audit specifics (NFR1.x, NFR2.2, NFR6.x, NFR7.x, NFR8.1, NFR9.x).