# Security, Deployment, and Maintenance Notes

This document provides operational guidance for AstraNotes as a local-first macOS application. It complements the product requirements in [Requirement.md](Requirement.md), the system design in [Architecture.md](Architecture.md), and the deployment topology in [UML_Package/DeploymentDiagram.html](UML_Package/DeploymentDiagram.html).

## 1. Purpose and Scope

AstraNotes is intentionally designed as a single-device desktop application with no cloud backend, no remote API, no telemetry pipeline, and no network plugin marketplace. As a result, the security, deployment, and maintenance posture is centered on:

- protecting local data at rest and in memory
- preserving integrity through transactional persistence and authenticated encryption
- deploying a stable signed macOS desktop build
- maintaining the application through disciplined schema, dependency, and release practices

These notes apply to the current documented scope only. They do not assume future additions such as cloud sync, remote administration, server-side storage, or a runtime plugin execution UI.

## 2. Security Notes

### 2.1 Security Objectives

The current design prioritizes the following security goals:

- confidentiality of secure-note title and content
- integrity of persisted secure-note records
- bounded exposure of decrypted data in memory
- predictable local-only trust boundaries
- safe failure behavior for authentication, rotation, import, and plugin execution

### 2.2 Trust Boundary Summary

The primary trust boundaries in AstraNotes are:

- `AstraUI` to `AstraCore`: UI initiates actions but does not perform encryption or direct persistence
- `AstraCore` to `AstraData`: services decide security behavior and repositories persist state transactionally
- app runtime to macOS services: Keychain, LocalAuthentication, file panels, microphone permission, and desktop file integration
- app-owned storage to user-selected local artifacts: backup files, plugin bundles, imported images, and microphone input

There is no network trust boundary in the current release because the product is strictly local.

### 2.3 Secure Data Handling

Secure-note handling should continue to follow these rules:

- secure-note title and content must be encrypted on-device before persistence
- persisted secure-note records must never contain plaintext title or plaintext content
- decrypted secure content must remain in memory only while required for active use
- in-memory key material must never be persisted or restored from disk
- secure-note title search must use `secureTitleAlias` only and must never depend on decrypted title data

This design keeps the most sensitive note content inside a narrow runtime boundary controlled by `KeyManager`, `EncryptionService`, and `NoteService`.

### 2.4 Authentication and Key Management

Operationally, the following controls are significant:

- first launch requires explicit passphrase creation before note usage
- later launches begin in a locked state for secure-note access because key material is not restored from disk
- biometric authentication is optional and must always preserve passphrase fallback in the same prompt
- failed authentication attempts are rate-limited with escalating lockout
- passphrase rotation must remain atomic and recoverable

Key management expectations:

- passphrase-derived keys must continue to use PBKDF2-HMAC-SHA256 with the documented iteration count
- salts must be random and unique per credential state
- biometric recovery secrets must remain device-bound through Keychain access controls
- recovery logic for stale pending-rotation markers must remain in place and be regression-tested

### 2.5 Storage and Confidentiality Caveats

The security model includes one important caveat that must be communicated clearly:

- attachment files are not encrypted at the application layer

This means:

- secure-note attachments depend on host disk encryption, such as FileVault, for confidentiality at rest
- deployment guidance should recommend FileVault-enabled machines for any environment handling sensitive notes
- future security reviews should treat attachment storage as a known residual risk rather than an undocumented assumption

### 2.6 Logging and Privacy

Audit logging is acceptable only when it remains sanitized. Logs must never include:

- note titles
- note bodies
- passphrases
- decrypted secure-note content
- exported archive plaintext

Acceptable log content includes:

- event names
- timestamps
- small non-content metadata such as counts, IDs, durations, and error categories

Because the product intentionally collects no telemetry, engineering teams should avoid introducing analytics SDKs, network diagnostics collectors, or background instrumentation that would violate the local-first privacy model.

### 2.7 Plugin Security Posture

The plugin surface is intentionally narrow and should remain so unless a new threat model is produced. Current security expectations are:

- plugin installation accepts only local package input
- plugin manifests must be validated before registration
- plugin IDs must remain unique
- plugin execution must stay behind host-mediated service APIs
- plugin failures and timeouts must not crash the host or corrupt note data

If a future release introduces executable plugin runtime loading, that change should trigger a dedicated security review, because it materially expands the attack surface.

### 2.8 Backup and Restore Security

Backup handling must preserve the same confidentiality standards as active storage:

- exported backups must remain encrypted end to end
- runtime-only and sensitive fields must be stripped before export encryption
- imports must validate schema compatibility before commit
- import failures must roll back completely

Operational guidance:

- backup files should be stored only in trusted local or organization-approved encrypted storage locations
- test backups should never be decrypted manually unless there is an explicit recovery procedure and a secure environment

### 2.9 Recommended Security Practices

- Enable FileVault on any Mac used to store production or sensitive AstraNotes data.
- Require signed release builds for all distributed app binaries.
- Treat backup files as sensitive assets even though they are encrypted.
- Keep plugin installation restricted to trusted local packages.
- Re-run confidentiality and rollback tests whenever persistence, encryption, import/export, or plugin code changes.
- Document any future expansion of platform integrations before implementation, especially if it changes the current local-only boundary.

## 3. Deployment Notes

### 3.1 Supported Deployment Model

The current documented deployment model is:

- one macOS desktop application process
- local JSON-backed persistence in the user's Application Support directory
- attachment file storage in the app's local container path
- Keychain-backed biometric secret storage
- user-selected local files for backup, import, image attachment, and plugin installation

There is no server deployment, container orchestration layer, or multi-node environment in scope.

### 3.2 Environment Assumptions

Deployment should assume:

- macOS host device
- a writable user profile directory
- functioning Keychain and LocalAuthentication services for biometric-enabled flows
- sufficient disk space for the JSON snapshot, attachments, and encrypted backups
- microphone permission availability for voice-capture features

For security-sensitive use, the machine should also have:

- FileVault enabled
- OS updates applied on a supported cadence
- access restricted to the authorized local user

### 3.3 Release Packaging Expectations

Each production release should:

- be built from a tagged and reviewed source revision
- produce a signed macOS application bundle
- include the correct app icon and metadata
- preserve the documented filesystem layout and storage paths
- avoid introducing undeclared runtime dependencies

If notarization is part of the team’s release pipeline, it should be treated as a standard release gate for public or broad internal distribution.

### 3.4 Filesystem and Data Locations

The deployment documentation should remain consistent with the current design:

- structured app state: `~/Library/Application Support/AstraNotes/database-state.json`
- attachment files: `~/Library/Application Support/AstraNotes/Attachments/`
- biometric recovery secret: macOS Keychain item with device-bound accessibility

Maintenance teams should avoid manual edits to persisted JSON snapshots outside controlled diagnostic or migration procedures.

### 3.5 Deployment Validation Checklist

After a new build is installed, validate at minimum:

- app launches successfully on first-run and later-launch paths
- first-launch passphrase setup works correctly
- later launches open directly to workspace while secure-note actions remain gated
- normal note save, secure note save, and secure note open flows behave as documented
- encrypted backup export and import function correctly
- attachments save to the expected storage location
- plugin install, enable/disable, and remove flows behave safely
- audit logging remains sanitized
- no unexpected network activity is introduced

### 3.6 Rollback and Recovery Guidance

Because AstraNotes is a local desktop application, rollback planning should focus on data compatibility and safe recovery rather than service failover.

Recommended approach:

- maintain a tested backup export before distributing schema-affecting releases
- verify import compatibility before adopting any schema change
- keep release notes explicit about data-model changes and recovery expectations
- if a release introduces a critical defect, prefer restoring user data from a known-good encrypted backup rather than manually editing live storage

### 3.7 Known Deployment Caveat

The architecture currently documents platform-event subscription for background and sleep lock behavior, but also notes that the present build does not yet connect a live macOS lifecycle/power producer into that stream.

That means:

- the relaunch lock boundary remains the strongest guaranteed protection path in practice
- deployment validation should explicitly verify the actual behavior of background/sleep locking in the shipped build
- future work that wires the producer should be documented as a deployment-affecting change

## 4. Maintenance Notes

### 4.1 Maintenance Priorities

Long-term maintenance should prioritize:

- confidentiality regression prevention
- schema and persistence stability
- safe upgrade and rollback behavior
- predictable release validation
- documentation integrity across requirements, architecture, UML, and tests

### 4.2 Change Management

Any change in the following areas should be treated as high-risk and require focused review:

- cryptography
- passphrase handling
- key lifecycle
- import/export
- transaction boundaries
- plugin execution surfaces
- attachment storage semantics
- background/sleep lock behavior

Recommended review practice:

- require at least one reviewer familiar with the security model
- update requirements and architecture docs alongside implementation when behavior changes
- update UML artifacts when structural boundaries or flows materially change

### 4.3 Dependency and Platform Maintenance

Maintenance teams should regularly review:

- Swift and Xcode compatibility
- macOS SDK changes affecting Keychain, LocalAuthentication, AVFoundation, and AppKit file panels
- cryptographic API compatibility and deprecations
- any third-party package or utility introduced into the build or test toolchain

No dependency should be added casually if it expands the trust boundary or introduces background network behavior.

### 4.4 Data and Schema Maintenance

Persistence maintenance should follow these rules:

- schema changes must be versioned deliberately
- export/import compatibility must be re-validated for every schema change
- migrations must preserve atomicity and failure rollback
- test fixtures should include secure notes, trash records, attachments, subjects, and plugins so cross-reference rewrites are exercised

If a migration changes storage semantics, update:

- `Requirement.md`
- `Architecture.md`
- `Tracebility.md`
- deployment and class/object diagrams as needed

### 4.5 Security Regression Testing

The following maintenance checks should be part of regression coverage:

- secure-note ciphertext-only persistence verification
- decryption failure handling with unchanged stored record
- lockout escalation behavior
- passphrase rotation interruption and recovery
- import rollback on failure
- alias-only secure search behavior
- sanitized audit logging
- absence of telemetry or outbound network activity

### 4.6 Operational Diagnostics

When investigating defects, prefer diagnostics that preserve user privacy:

- inspect event types and state transitions rather than note content
- use synthetic or test data for reproduction whenever possible
- avoid copying live user storage into insecure channels
- avoid adding temporary debug logs that include note bodies, titles, or key-related material

If a deeper forensic workflow is ever needed, it should be documented separately with explicit safeguards.

### 4.7 Documentation Maintenance

This project already relies heavily on synchronized design artifacts. To keep the documentation trustworthy:

- update traceability when requirements change
- keep UML diagrams aligned with actual implementation scope
- remove stale references to features that are intentionally out of scope
- keep deployment notes aligned with the actual build topology, not assumed future architecture

A documentation drift review should be part of any milestone or release sign-off.

### 4.8 Recommended Maintenance Checklist

- Review release notes for any change touching security-sensitive paths.
- Re-run regression coverage for authentication, secure notes, backup/import, and plugins.
- Confirm deployment topology still matches the documented local-only model.
- Verify audit logs remain sanitized and telemetry-free.
- Revalidate schema compatibility and backup recovery procedures before shipping storage changes.
- Update architecture, UML, and traceability artifacts before closing the change set.

## 5. Summary

AstraNotes has a relatively strong security and operations posture for a local-first desktop application because it limits its scope deliberately: no cloud backend, no remote API, narrow plugin surfaces, encrypted secure-note storage, atomic persistence, and privacy by omission. The most important maintenance discipline is to preserve those boundaries over time.

The key operational watchpoints are:

- attachment files rely on host disk encryption rather than app-layer encryption
- passphrase rotation and import/export remain high-impact transactional flows
- plugin execution must remain constrained unless a new runtime model is formally designed
- deployment documentation must continue to reflect the real shipped build, not aspirational future behavior
