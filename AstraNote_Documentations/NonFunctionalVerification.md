# AstraNotes Non-Functional Verification Artifact

This document provides explicit verification coverage for non-functional requirements that are not naturally represented by structural UML alone.

Evidence sources:
- Architecture: AstraNote_Documentations/Architecture.md
- Test procedures: AstraNote_Documentations/TestSteps.md
- UML support context: AstraNote_Documentations/UML_Package/*.html

## Verification Matrix

| NFR ID | Verification Method | Acceptance Criterion | Primary Evidence |
| --- | --- | --- | --- |
| NFR1.1 | Timed unlock benchmark on target hardware profile with 1,000 notes loaded. | Unlock completes in <= 1.0s excluding manual passphrase entry. | Benchmark run records + TestSteps section 1 |
| NFR1.2 | Timed unlock benchmark at 10,000-note dataset scale. | Unlock completes in <= 2.0s excluding manual passphrase entry. | Benchmark run records + TestSteps section 1 |
| NFR1.3 | Measurement protocol check for benchmark harness. | Timer starts at auth submit and stops at workspace render; typing time excluded. | Benchmark harness specification |
| NFR2.2 | UI frame-time capture during note editing, encryption saves, transcription, and plugin action execution. | 60 FPS target maintained during normal workflows. | Frame-time profile and interaction trace |
| NFR6.1 | Repeated failed-unlock scenario test with controlled cadence and lockout progression capture. | 5 failures in 30s triggers 30s lockout; subsequent breaches double up to 60 min max. | Lockout scenario logs |
| NFR6.2 | Audit log assertion for lockout events. | Every lockout event writes an audit record with timestamp and reason. | Audit log extraction |
| NFR6.3 | Audit log assertion for auth failures and plugin validation/runtime failures with payload inspection. | Events logged without sensitive note content. | Sanitized audit log extraction |
| NFR7.1 | Telemetry payload inspection with telemetry opt-in on/off. | Telemetry is opt-in and limited to non-sensitive operational metrics. | Telemetry capture report |
| NFR7.2 | Negative assertion over telemetry payload schema and emitted records. | No note titles, note text, or derived content appears in telemetry. | Telemetry schema and sample payloads |
| NFR8.1 | Accessibility conformance run for core workflows using keyboard-only navigation and VoiceOver. | Core workflows are fully operable with keyboard and VoiceOver feedback. | Accessibility test report |
| NFR9.1 | Release packaging check. | Default shipped locale is English. | Build/release checklist |
| NFR9.2 | Localization architecture review and proof-of-extension test. | New locale can be added without rewriting feature logic. | Localization design review + sample locale integration |

## Execution Notes

1. Performance and frame-time checks should run on representative Apple Silicon and Intel targets.
2. Audit and telemetry captures must use sanitized exports only.
3. Accessibility verification should cover lock/unlock, browse/edit, trash, and settings workflows end-to-end.
4. Localization verification should include at least one non-English locale pack smoke test.
