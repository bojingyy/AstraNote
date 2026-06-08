# AstraNotes Non-Functional Verification Artifact

## Verification Matrix

| NFR ID | Verification Method | Acceptance Criterion | Primary Evidence |
| --- | --- | --- | --- |
| NFR1.1 | Timed authentication benchmark on target hardware profile (Apple Silicon M-series and Intel i5/i7 6th gen+, 8 GB RAM): measure passphrase verification and key derivation only. | Authentication completes in approximately 1.0s, excluding manual passphrase entry. | Benchmark run records + TestSteps section 1 |
| NFR1.2 | Repeat the NFR1.1 benchmark against databases of 100, 1,000, and 10,000 notes and compare results. | Authentication latency is statistically constant across dataset sizes — there is no whole-app unlock step whose duration scales with note count. | Benchmark run records (100 / 1k / 10k comparison) |
| NFR1.3 | Measurement protocol check for benchmark harness. | Timer starts at credential submission and stops at key-derivation completion; manual typing time is excluded from the measurement. | Benchmark harness specification |
| NFR2.1 | Concurrency trace during encryption, database writes, and plugin action execution, confirming each runs on actor-isolated background contexts. | The main UI thread is never blocked by encryption, database I/O, or plugin execution. | Instrumented concurrency trace |
| NFR2.2 | UI frame-time capture during note editing, encrypted saves, attachment handling, and plugin action execution. | 60 FPS is maintained during normal workflows. | Frame-time profile and interaction trace |
| NFR3.1 | Inspection of persisted records, audit logs, caches, and export archives for decrypted secure-note content. | Persisted secure-note records contain only ciphertext, authentication tag, salt, and the non-sensitive display alias; decrypted content never appears in logs, caches, or exports. | Storage/log/export content inspection report |
| NFR3.2 | Memory-lifecycle trace: open a secure note, navigate away, then lock the session; separately, trace the search path while matching secure-note queries. | Decrypted content is held only while its note is open and is reset on navigation-away or lock; the search path matches exclusively against `secureTitleAlias` and never holds decrypted titles in memory. | Memory-lifecycle trace + search-path instrumentation |
| NFR4.1 | Tamper test: mutate stored ciphertext, nonce, or authentication tag for a secure note and attempt to load it. | AES-GCM authentication fails explicitly and is surfaced as a verification error rather than producing corrupted plaintext. | Tamper-test run log |
| NFR4.2 | Before/after snapshot comparison of the stored record across an induced verification failure. | The user sees a clear error, and the stored record is byte-for-byte unchanged after the failed verification attempt. | Snapshot diff + UI error capture |
| NFR5.1 | Induced-failure transaction tests across note edit/delete, passphrase rotation, and backup import, each interrupted mid-operation. | Every interrupted transaction commits in full or leaves the prior `DatabaseState` completely intact — no partial writes are observable. | Transaction rollback test logs + state snapshots |
| NFR5.2 | Two scripted recovery scenarios: (a) terminate the app mid-passphrase-rotation and relaunch; (b) submit a backup archive that fails partway through import. | (a) Every secure note remains under the original credentials, any stale in-flight rotation marker is detected, cleared, and logged on next unlock, with no user action required; (b) the import rolls back entirely, the prior database state is intact, and the user sees a descriptive error. | Recovery-scenario run logs + audit-log extracts |
| NFR6.1 | Repeated failed-unlock scenario test with controlled cadence and lockout-progression capture. | 5 failures within 30s trigger a 30s lockout; each subsequent breach doubles the lockout up to a 60-minute maximum. | Lockout scenario logs |
| NFR6.2 | Audit log assertion for lockout events. | Every lockout event writes an audit record with timestamp and reason. | Audit log extraction |
| NFR6.3 | Audit log assertion across authentication failures, passphrase-rotation outcomes, plugin lifecycle events (install/remove/execute), and export/import completions, with payload inspection. | Each event is logged with an event name and small non-content metadata only — never note titles, content, or passphrases. | Sanitized audit log extraction |
| NFR7.1 | Negative assertion over all outbound network activity and emitted instrumentation during a full feature pass. | No telemetry or usage-analytics payload of any kind is collected, generated, or transmitted; zero operational metrics leave the device. | Network/instrumentation capture report (expected: empty) |

## Execution Notes

1. Performance and frame-time checks should run on representative Apple Silicon and Intel targets, per NFR1.1/NFR2.2.
2. Authentication-latency comparisons (NFR1.2) must use the same hardware profile and passphrase across all three dataset sizes so that only note count varies.
3. Confidentiality and audit captures (NFR3.1, NFR6.3) must use sanitized exports only and must inspect logs, caches, and export archives together — a gap in any one of the three is a confidentiality defect.
4. Recovery-scenario tests (NFR5.2) must induce the interruption deterministically (e.g., forced termination at a known transaction step) so the scenario is reproducible.
5. The telemetry negative assertion (NFR7.1) should be run over a full end-to-end feature pass (unlock, edit, attach, search, export, plugin install) to maximize the chance of observing any unexpected outbound activity.
