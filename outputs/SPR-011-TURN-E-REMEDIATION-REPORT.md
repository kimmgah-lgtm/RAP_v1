# SPR-011 Turn E Remediation Report

Date: 2026-09-24
Scope: P1 remediation of RISK-SPR011-002 ~ 006; local/fixture/mock only
Command: `SPR-011-TURN-E-COMMAND.md`

## 1. Precondition

| Condition | Evidence | Result |
|---|---|---|
| SPR-011 Turn D Final Gate = FAIL | `outputs/SPR-011-TURN-D-FINAL-GATE-REPORT.md` §20 | CONFIRMED |
| READY FOR NEXT SPRINT = NO | same, §21 | CONFIRMED |
| RISK-SPR011-001 RESOLVED; 002–006 OPEN P1; BASELINE-001 OPEN P2 | `docs/RISK-REGISTER.md` at `6b31cff` | CONFIRMED |
| Branch `ASS_v1`, clean at `6b31cff` | `git log -1` = `6b31cff`; `git status` clean before work; `origin/main` = `origin/ASS_v1` = `6b31cff` | CONFIRMED |

Execution environment: the linked Windows PC was offline, so the work was done in a cloud clone of `kimmgah-lgtm/RAP_v1` (`ASS_v1`) and tested on **Linux PowerShell 7.4.6** through a **test-only mirror**. The mirror copies the repository and applies 5 substitutions:

- `winsqlite3.dll` → `libsqlite3.so.0`
- bypass of 2 Windows-only guards
- 3 Windows path literals in SPR-003/SPR-010 tests

These substitutions are listed in `outputs/evidence/SPR-011-TURN-E/linux-test-mirror-substitutions.py`. Repository source was not changed for them. Before any change, the baseline was reproduced on the mirror: SPR-011 120/120 and the full regression PASS. **A native Windows re-run is required** (RISK-SPR011-010).

## 2. RED evidence (before repair)

New suite `WorkflowTurnERemediationTests.ps1` (85 assertions) was written first and executed against the unmodified Turn-D engine: **16 PASS / 69 FAIL**.

| Group | Risk | FAIL | PASS (already satisfied) |
|---|---|---:|---|
| E1 | RISK-SPR011-002 | 14 | E1-05 (a clean run produces no exception) |
| E2 | RISK-SPR011-003 | 19 | E2-05, E2-08, E2-S-E01~E12 (dispositions and preservation, which Turn D had already confirmed) |
| E3 | RISK-SPR011-004 | 19 | E3-16 (no audit-mutating command exported) |
| E5 | RISK-SPR011-006 | 17 | — |

Raw results: `outputs/evidence/SPR-011-TURN-E/turn-e-RED-results.json`.

## 3. Repair per risk

| Risk | Files | Functions / design |
|---|---|---|
| 002 | `WorkflowEngine.psm1` | `AUTOMATION_FAILURE` taxonomy class and detector (masked exit-0 failures); `ConvertTo-RapExceptionClass` (ordinal-only); `ConvertTo-RapNormalizedException`; composite policy rejects unsupported class / forged `DefaultResolution`; `AUTOMATION_FAILURE` added to lineage blockers |
| 003 | `WorkflowEngine.psm1` | `Get-RapDownstreamImpact` (evidence-derived, transitive, cycle/missing-reference blocking); `Test-RapDependentOperationPermitted`; PDF/STALE/AI evidence enriched; `RetainedAlternatives`; verification errors `DEPENDENT_LINEAGE_REWRITTEN`, `AI_ALTERNATIVE_NOT_RETAINED` |
| 004 | `WorkflowEngine.psm1`, `WorkflowPersistence.psm1` | lifecycle events per case; hash-chained `WorkflowLifecycleEvents` + `WorkflowChainHead`; audit schema `SPR-011-TURN-E` (actor, prior state, transitions, failure reason); `Submit-RapHumanReviewDecision`; `Get-RapExceptionLifecycle`; `Test-RapWorkflowAuditChain` |
| 005 | `docs/SPR-011-SCENARIO-MATRIX.md`, `WorkflowMatrixTraceabilityTests.ps1` | 180-row full-schema matrix; static literal resolution + runtime bidirectional ID equality |
| 006 | `WorkflowEngine.psm1`, `WorkflowPersistence.psm1` | `Test-RapWorkflowSnapshot`; OperationId validation; SQL literal escaping; `-FaultPoint` injection; `RecordFailure` → `OPERATION_FAILED` |

Wiring: root module and manifest export 8 new commands; the self-test Workflow check requires them; `Bootstrap.Tests.ps1` runs the 3 new suites. Policy version `SPR-011-TURN-E-1`; Workflow module `1.0.0-alpha.12`.

## 4. GREEN evidence (after repair)

`WorkflowTurnERemediationTests.ps1`: **85/85 PASS** (`turn-e-GREEN-results.json`).

Mutation check (non-vacuity): each deliberate break of the fix turned the targeted assertions red.

| Mutation | Break | Assertions turned red |
|---|---|---|
| M1 | drop upstream propagation | 7 (E2-04, 06, 07, 09, 15, 17, 21) |
| M2 | chain verifier always valid | 3 (E3-17~19) |
| M3 | fault after COMMIT | 2 (E5-16/17) |
| M4 | automation actor check weakened | 1 (E3-08) |
| M5 | unsupported-class check removed | 1 (E1-13) |

## 5. E01–E12 semantic results

**12/12** (E2-S-E01 ~ E2-S-E12: disposition, all verifications VERIFIED, HUMAN_OWNED / ResearcherConfirmed / Library_ID preserved, zero mutation for non-AUTO_SAFE). The four Turn-D failures are now closed at the required level:

| Scenario | Turn D gap | Turn E evidence |
|---|---|---|
| E05 | `DownstreamBlockModeled=false` | E2-01~05: modeled; PDF-dependent operation refused (`PDF_MISSING`); transitive to Synthesis/Output |
| E06 | dependents absent from evidence | E2-06~09: 4 dependents REVALIDATION_REQUIRED; 4 transition events; no recomputation |
| E10 | AI version not recorded; no typed retention | E2-10~14: AI value/model/version/run and confirmation provenance recorded; `RETAINED_NOT_APPLIED`; researcher value unchanged |
| E11 | dependents stayed `CURRENT` | E2-15~18: dependents listed; still REVALIDATION_REQUIRED after refresh; consumption refused; CURRENT only after new basis evidence |

## 6. Lifecycle audit reconstruction

Reconstructed from a freshly opened SQLite store (E3-13):

- Review case: `DETECTED>PLANNED>STATE_PRESERVED>VERIFIED>AWAITING_HUMAN_REVIEW>HUMAN_REVIEW_DECISION>FINAL_RESOLUTION`
- AUTO_SAFE case: `DETECTED>PLANNED>RECONCILIATION_APPLIED>VERIFIED>FINAL_RESOLUTION(RECONCILED)` (E3-04)

Audit rows record actor, prior state, and failure reason (E3-01, E3-02, E3-20). Tamper detection:

- in-place audit edit (E3-17)
- in-place event edit (E3-18)
- tail deletion (E3-19)
- forged append (EA-10)
- deleted audit row (EA-11)

## 7. Requirement coverage

| Rows | Mapped to executable assertion | Unmapped | Actual PASS | FAIL |
|---:|---:|---:|---:|---:|
| 180 (40 L + 20 R + 15 CA + 85 E + 20 EA) | 180 | 0 | 180 | 0 |

`WorkflowMatrixTraceabilityTests.ps1` 13/13 PASS; a deliberately broken token was detected (negative check).

## 8. Focused test counts

| Suite | Assertions | Result |
|---|---:|---|
| WorkflowExceptionTests (legacy core) | 69 | PASS |
| WorkflowExceptionAdversarialTests (legacy) | 16 | PASS |
| WorkflowCompositePolicyTests R01–R20 | 20 | PASS |
| WorkflowCompositePolicyAdversarialTests | 15 | PASS |
| **Legacy subtotal** | **120** | PASS |
| WorkflowTurnERemediationTests | 85 | PASS |
| WorkflowTurnEAdversarialTests | 20 | PASS |
| WorkflowMatrixTraceabilityTests | 13 | PASS |
| **Total** | **238** | **0 FAIL** |

Intentional legacy expectation updates:

- `'taxonomy count'` 13 → 14
- required list + `AUTOMATION_FAILURE`
- R20 and the recovery helper policy-version literal `SPR-011-TURN-C-1` → `SPR-011-TURN-E-1`

## 9. Adversarial results

`WorkflowTurnEAdversarialTests.ps1`: **20/20 PASS**. Cases:

- masked success
- PDF change combined with coding conflict
- a lying CURRENT status
- 4 forged decisions and a check that none reached the store
- a researcher decision not bypassing re-observed blockers
- forged append
- deleted audit row
- 5 malformed-payload permutations
- class-order permutation
- lineage-order permutation
- a padded class borrowing AUTO_SAFE
- an interrupted decision commit

## 10. Restart / partial persistence (process boundary)

For each of `AFTER_STATE`, `AFTER_AUDIT`, `AFTER_EVENTS`, `BEFORE_COMMIT`, four separate pwsh processes ran in sequence:

1. **Fault**: non-zero exit.
2. **Inspect**: 0 operations / 0 audit rows / 0 state rows, 1 `OPERATION_FAILED` with `INJECTED_FAULT:<point>`, chain valid.
3. **Complete**: `COMPLETED`.
4. **Replay**: `ALREADY_COMPLETED`.

A final inspect found exactly 1 operation, 1 audit row, 1 exception, 1 `OPERATION_COMPLETED`, and a valid chain. E5-10~17: **8/8 PASS**.

## 11. Full safe RAP regression

| Expected component suites | Available | Unavailable | Executed | PASS | FAIL |
|---:|---:|---:|---:|---:|---:|
| 11 | 10 | 1 (SPR-006, RISK-BASELINE-001) | 10 | 10 | 0 |

`tools/Invoke-Tests.ps1` exit 0. It ran Install, SelfTest, and 24 underlying scripts (21 prior + 3 Turn E). Separately, the SPR-009 Gate remediation suite passed 31/31. The self-test Overall Status is PASS, including the Workflow check that requires the new commands. Summary: `outputs/evidence/SPR-011-TURN-E/full-regression-summary.log`.

## 12. Production safety

- Production AI Provider: DISABLED
- Zotero Write: DISABLED
- Drive Mutation: DISABLED
- Notion Write: DISABLED
- Synthesis Write: DISABLED
- Output Write: DISABLED
- Exception-Recovery Write: DISABLED
- Real External Tests: TEST_DEFERRED

Production data changes: **Zotero 0 / Drive 0 / Notion 0**. Only fixtures and temporary SQLite files were used.

## 13. Risk state

**P0 = 0, open P1 = 0, open P2 = 6.**

Resolved in Turn E (verified locally, independent re-verification pending in Turn F):

- RISK-SPR011-002 ~ 006
- RISK-SPR011-012: P1, found during Turn E. OperationId was interpolated into SQL; now fixed.

Open P2:

| Risk | Summary |
|---|---|
| RISK-BASELINE-001 | SPR-006 executable artifacts absent |
| RISK-SPR011-007 | no external anchor for the hash chain |
| RISK-SPR011-008 | researcher identity is asserted, not authenticated |
| RISK-SPR011-009 | live Evidence-Graph → `Dependents` adapter not implemented |
| RISK-SPR011-010 | Linux mirror execution; Windows re-run pending |
| RISK-SPR011-011 | one vacuous legacy assertion, re-mapped |

## 14. Files

Created:

- `src/Local/Workflow/tests/WorkflowTurnERemediationTests.ps1`
- `src/Local/Workflow/tests/WorkflowTurnEAdversarialTests.ps1`
- `src/Local/Workflow/tests/WorkflowMatrixTraceabilityTests.ps1`
- `src/Local/Workflow/tests/TurnEFaultRecoveryProcess.ps1`
- `outputs/SPR-011-TURN-E-REMEDIATION-REPORT.md`
- `outputs/evidence/SPR-011-TURN-E/*`

Modified:

- `src/Local/Workflow/WorkflowEngine.psm1`
- `src/Local/Workflow/WorkflowPersistence.psm1`
- `src/Local/Workflow/ResearchAutomation.Workflow.psm1`
- `src/Local/Workflow/ResearchAutomation.Workflow.psd1`
- `src/Local/Workflow/tests/TestHarness.ps1`
- `src/Local/Workflow/tests/WorkflowExceptionTests.ps1`
- `src/Local/Workflow/tests/WorkflowCompositePolicyTests.ps1`
- `src/Local/Workflow/tests/CompositePolicyRecoveryProcess.ps1`
- `src/Local/ResearchAutomation.Local/ResearchAutomation.Local.psm1`
- `src/Local/ResearchAutomation.Local/ResearchAutomation.Local.psd1`
- `src/Local/ResearchAutomation.Local/modules/SelfTest.psm1`
- `src/Local/ResearchAutomation.Local/tests/Bootstrap.Tests.ps1`
- `docs/SPR-011.md`
- `docs/SPR-011-SCENARIO-MATRIX.md`
- `docs/RISK-REGISTER.md`
- `CHANGELOG.md`
- `ROADMAP.md`

Historical reports for Turns A–D were not modified.

## 15. Git

Commit = **NOT PERFORMED**
Push = **NOT PERFORMED**

## 16. Gate status

SPR-011 Final Gate re-verification = **NOT PERFORMED (Turn F)**
READY FOR NEXT SPRINT = **NOT EVALUATED**
SPR-011.5 = **NOT STARTED**

SPR-011 TURN E COMPLETE — P1 REMEDIATION VERIFIED LOCALLY, FINAL GATE RE-VERIFICATION REQUIRED (TURN F).
