# SPR-009 Final Gate Report

Date: 2026-09-23

## 1. Implementation Verification

- SPR-009: VERIFIED
- Actual implementation files:
  - `src/Local/Synthesis/SynthesisEngine.psm1`
  - `src/Local/Synthesis/SynthesisPersistence.psm1`
  - `src/Local/Synthesis/ResearchAutomation.Synthesis.psm1`
  - `src/Local/Synthesis/ResearchAutomation.Synthesis.psd1`
  - `src/Local/Synthesis/tests/SynthesisTests.ps1`
  - `src/Local/Synthesis/tests/TestHarness.ps1`

The repository contains an executable dataset builder, analysis specification,
Hedges' g calculation, fixed and DL random-effects pooling, heterogeneity,
subgroup, leave-one-out, funnel-data, local persistence, audit, and fixture tests.
This is an actual implementation rather than documentation or stubs.

## 2. Architecture Boundary

- SPR-007 Meta Coding boundary: PASS
- SPR-008 Evidence Graph boundary: PASS (SPR-009 does not redefine the graph)
- SPR-009 synthesis responsibility: PASS
- Project isolation: PASS

The dataset builder enforces the specification Project ID and retains Project ID,
Library ID, MetaCoding ID, EffectSize ID, outcome, comparison, arm, measurement,
time point, effect, variance, sample size, moderator, and provenance fields.

## 3. Input Integrity

- Researcher-confirmed gate: PASS
- Eligibility validation: FAIL
- Conflict handling: PASS
- No silent cleaning: FAIL

AI-assisted and pending records are rejected, project mismatches are rejected, and
conflicting evidence is rejected. However, a derived effect without source inputs
or transformation is accepted, and a missing moderator is silently represented as
an empty subgroup.

## 4. Statistical Validation

- Effect-size computation: PASS for the claimed Hedges' g implementation
- Variance/SE: PASS
- Pooled effect: PASS
- Confidence interval: PASS
- Q: PASS
- I²: PASS
- tau²: PASS
- Direction harmonization: PASS
- Dependency protection: FAIL

Independent calculations reproduced Hedges' g `0.4961636828644501`, variance
`0.04125601224588579`, and SE `0.20311576070282136`. For effects `0.1`, `0.5`,
and `1.2` with variance `0.04`, fixed and random pooled effects were `0.6`;
fixed SE was `0.11547005383792516`; DL random SE was `0.32145502536643183`;
Q was `15.5`; I² was `87.09677419354838`; and tau² was `0.27`. Engine and
independent results agreed within `1e-12`.

Dependency protection failed because two effects sharing one dependency group can
be labelled `RVE` and then pooled by the ordinary independent inverse-variance
implementation. The strategy is recorded but neither executed nor explicitly
rejected.

## 5. Advanced Analysis

- Moderator/Subgroup: FAIL
- Sensitivity: FAIL
- Publication-bias diagnostics: PASS for claimed funnel-data output

Approved named subgroups work, but missing moderator values produce an anonymous
empty subgroup. Leave-one-out output preserves the parent Analysis ID and excluded
effect but is not persisted and lacks configuration hash, dataset hash, engine
version, and provenance. Funnel data retain effect IDs and SEs and generate no
automatic publication-bias interpretation.

## 6. Reproducibility

- Dataset hashing: PASS
- Configuration hashing: PASS
- Analysis versioning: PASS for persisted primary runs
- Deterministic reproduction: PASS for primary synthesis

Primary datasets are canonically ordered and hashed, scientifically meaningful
configuration changes alter the configuration hash, and primary run identities
include config and dataset hashes. Sensitivity-run reproducibility remains a
separate blocking persistence defect.

## 7. Evidence & Ownership

- Evidence Graph lineage: FAIL
- AI/researcher boundary: PASS
- HUMAN_OWNED firewall: PASS
- Researcher interpretation firewall: PASS
- Researcher decision firewall: FAIL

The analysis result retains effect, project, evidence-reference, and optional
statistical-input data. It does not create or retain the complete Analysis Result
→ Analysis Dataset → Effect Size → Statistical Inputs → Evidence → Paper path
using SPR-008 graph identities. Narrative interpretation fields remain null and
protected. Separately, omitted model and estimator parameters silently select
RANDOM/DL, which violates the broader researcher decision firewall.

## 8. Focused Tests

- Scenarios: 68/68 PASS
- Actual Assertions: 68
- Numerical Assertions: 11 explicit tolerance assertions
- Failures: 0
- Scenario Matrix: `docs/SPR-009-SCENARIO-MATRIX.md`

The focused suite was rerun on 2026-09-23 using only deterministic synthetic
fixtures and local SQLite. Passing coverage does not exercise the six P1 findings.

## 9. Full Safe RAP Regression

- Executed: 15 test scripts
- PASS: 15
- FAIL: 0
- Overall: PASS

All available local suites for SPR-001–005 and SPR-007–009 passed. No executable
SPR-006 artifacts exist in this checkout, so that historical baseline could not be
rerun locally.

## 10. Production Safety

- Production AI Provider: DISABLED
- Production Zotero Write: DISABLED
- Production Drive Migration: DISABLED
- Production Notion Write: DISABLED
- Synthesis Production Write: DISABLED
- Real External Tests: TEST_DEFERRED

No real research PDF, production credential, or external research system was used.

## 11. Production Data Changes

- Zotero: 0
- Drive: 0
- Notion: 0

## 12. Risk Register

- P0: 0
- P1: 6
- P2: 2

Unresolved risks are recorded with evidence, impact, affected component, and Gate
status in `docs/RISK-REGISTER.md`. All six P1 risks are Gate-blocking. The P2 risks
cover test-evidence gaps and absent SPR-006 executable artifacts.

## 13. Git

- Commit: NOT PERFORMED
- Push: NOT PERFORMED

## 14. Final Gate

SPR-009 FINAL GATE = FAIL

Evidence-based reason: the implemented statistical formulas and existing tests
pass, but dependent effects can be pooled as independent despite an unimplemented
strategy label; consequential model/estimator decisions can be defaulted; derived
effect provenance is not mandatory; full Evidence Graph lineage is absent;
sensitivity runs are not persistently reproducible; and invalid moderator values
do not fail safely.

## 15. Next Sprint Readiness

READY FOR NEXT SPRINT = NO

## 16. Stop

SPR-009 TURN B COMPLETE — STOPPED BEFORE SPR-010.
