# SPR-009 Turn C Remediation Report

Date: 2026-09-23

## 1. Remediation Summary

- P1-01 Derived Effect Eligibility: RESOLVED
- P1-02 Missing Moderator Protection: RESOLVED
- P1-03 Dependency Strategy: RESOLVED
- P1-04 Sensitivity Reproducibility: RESOLVED
- P1-05 Evidence Graph Lineage: RESOLVED
- P1-06 Researcher Decision Firewall: RESOLVED

The passing statistical core was preserved. Remediation was limited to eligibility,
scientific-decision validation, dependency enforcement, lineage integration,
sensitivity child-run persistence, and the corresponding fixture tests.

## 2. Changed Files

Created:

- `src/Local/Synthesis/tests/SynthesisGateRemediationTests.ps1`
- `src/Local/Synthesis/tests/SensitivityRecoveryProcess.ps1`
- `outputs/SPR-009-TURN-C-REPORT.md`

Modified:

- `src/Local/Synthesis/SynthesisEngine.psm1`
- `src/Local/Synthesis/ResearchAutomation.Synthesis.psm1`
- `src/Local/Synthesis/tests/TestHarness.ps1`
- `src/Local/Synthesis/tests/SynthesisTests.ps1`
- `src/Local/ResearchAutomation.Local/modules/SelfTest.psm1`
- `docs/SPR-009.md`
- `docs/SPR-009-SCENARIO-MATRIX.md`
- `docs/RISK-REGISTER.md`
- `ROADMAP.md`
- `CHANGELOG.md`

## 3. Statistical Non-Regression

- Hedges' g: PASS
- Variance/SE: PASS
- Pooled Effects: PASS
- CI: PASS
- Q: PASS
- I²: PASS
- tau²: PASS

Legacy tolerances were unchanged. Turn C added independent `1e-12` checks for
Hedges' g `0.4961636828644501`, variance `0.04125601224588579`, SE
`0.20311576070282136`, fixed pooled effect `0.6`, fixed SE
`0.11547005383792516`, and fixed lower CI `0.37367869447766666`.

## 4. Focused Tests

- Legacy scenarios: 68/68 PASS
- New remediation scenarios: 25/25 PASS
- Total: 93/93 PASS
- Actual assertions: 99
- Numerical assertions: 17
- Failures: 0

The legacy suite contains 68 assertions, including 11 explicit numerical tolerance
assertions. The remediation suite contains 31 assertions, including 6 added
numerical tolerance assertions.

## 5. Evidence / Researcher Safety

- End-to-end lineage: PASS
- Dependency protection: PASS
- Missing moderator protection: PASS
- Scientific default prevention: PASS
- HUMAN_OWNED firewall: PASS

Dataset eligibility now validates SPR-008 Project-Paper, Meta Coding, Effect,
Evidence/Paper, and applicable derived-input graph paths. Unsupported RVE,
multilevel, aggregation, or other strategies cannot silently fall back to ordinary
independent pooling when dependent rows remain.

## 6. Persistence / Reproducibility

- Sensitivity persistence: PASS
- Hashes: PASS
- Engine version: PASS
- Parent-child relationship: PASS
- Restart/reload: PASS

Each leave-one-out run is a distinct persisted child analysis with the parent ID,
changed configuration, exclusions, input/config hashes, engine version, complete
statistics, provenance, timestamp, and deterministic run identity. A writer
PowerShell process persisted the primary and child runs; a separate reader process
reopened SQLite and recovered all three parent-child relationships.

## 7. Full Safe RAP Regression

- Available: 16 test scripts
- Executed: 16
- PASS: 16
- FAIL: 0
- Unavailable historical artifacts: SPR-006 executable source/test artifacts

The unavailable SPR-006 historical artifact was not counted as executed or passed.

## 8. Production Safety

- AI Provider: DISABLED
- Zotero Write: DISABLED
- Drive Migration: DISABLED
- Notion Write: DISABLED
- Synthesis Production Write: DISABLED
- Real External Tests: TEST_DEFERRED

## 9. Production Data Changes

- Zotero: 0
- Drive: 0
- Notion: 0

## 10. Risk State After Remediation

- P0: 0
- P1: 0
- P2: 1

Remaining risk:

- `RISK-BASELINE-001` (P2, non-blocking): SPR-006 executable artifacts are absent
  from this checkout, so that historical baseline cannot be rerun locally.

The six Turn B P1 risks and the SPR-009 test-coverage P2 risk are recorded as
RESOLVED with implementation and test evidence in `docs/RISK-REGISTER.md`.

## 11. Git

- Commit: NOT PERFORMED
- Push: NOT PERFORMED

## 12. Gate Status

- FINAL GATE: NOT PERFORMED
- READY FOR NEXT SPRINT: NOT EVALUATED

## 13. Stop

SPR-009 TURN C COMPLETE — FINAL GATE NOT PERFORMED.
