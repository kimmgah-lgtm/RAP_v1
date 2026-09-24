# RAP Risk Register

Last verified: 2026-09-24, SPR-011 Turn D Final Gate re-verification

Open-risk summary: **P0 = 0, P1 = 5, P2 = 1**.

## Open risks

| Risk ID | Priority | Description and evidence | Impact | Affected component | Gate blocking |
|---|---|---|---|---|---|
| RISK-BASELINE-001 | P2 | No SPR-006 executable source/test artifacts are present in this checkout. | The historical SPR-006 baseline cannot be rerun locally as part of the safe regression. | Repository regression evidence | NO |
| RISK-SPR011-002 | P1 | Turn B found no dedicated `AUTOMATION_FAILURE` taxonomy class and incomplete unsupported-type normalization. | Mandatory taxonomy/fail-closed coverage may be incomplete. | Workflow exception taxonomy | YES |
| RISK-SPR011-003 | P1 | Turn B found incomplete downstream behavior evidence for PDF blocking/change lineage, AI evidence retention, and dependent stale artifacts (E05/E06/E10/E11). | Exception handling may not fully protect downstream reproducibility. | Workflow scenario behavior | YES |
| RISK-SPR011-004 | P1 | Turn B found missing actor, explicit transition, failure-reason, human-review-decision, and final-resolution audit evidence. | Material lifecycle reconstruction may be incomplete. | Workflow audit | YES |
| RISK-SPR011-005 | P1 | Turn B found the pre-Turn-C matrix insufficiently traceable to exact test cases/assertions for all mandatory requirements. Turn C adds exact R01-R20 mapping but does not re-adjudicate the entire matrix. | Final Gate traceability remains pending. | Requirements/test evidence | YES |
| RISK-SPR011-006 | P1 | Turn B found incomplete deterministic malformed-payload and true partial-persistence/interruption coverage outside the bounded composite-policy recovery path. | Some failure paths remain unverified. | Workflow recovery/error handling | YES |

## Resolved by SPR-009 Turn C

| Risk ID | Former priority | Resolution evidence | Status |
|---|---:|---|---|
| RISK-SPR009-001 | P1 | Synthesis now rejects every unimplemented dependency strategy with `UNSUPPORTED_DEPENDENCY_STRATEGY`; ordinary independent effects continue to synthesize. Gate scenarios F–H pass. | RESOLVED |
| RISK-SPR009-002 | P1 | Model and estimator no longer have authoritative defaults; missing selections raise `ANALYSIS_MODEL_REQUIRED` or `ANALYSIS_ESTIMATOR_REQUIRED`. Gate scenarios R–T pass. | RESOLVED |
| RISK-SPR009-003 | P1 | `DERIVED_EFFECT` now requires source inputs plus transformation method/version and validated derived-input/evidence graph lineage. Gate scenarios A–C and Q pass. | RESOLVED |
| RISK-SPR009-004 | P1 | Dataset construction validates the SPR-008 Project-Paper → Meta Coding → Effect → Evidence/Paper path and derived-input path. Results retain Analysis Dataset, effect, input, evidence, and paper identities. Gate scenarios N–Q pass. | RESOLVED |
| RISK-SPR009-005 | P1 | Sensitivity analyses are persisted as distinct child runs with parent identity, dataset/config hashes, engine version, changed configuration, exclusions, statistics, provenance, and audit state. Independent-process reload passes scenario M. | RESOLVED |
| RISK-SPR009-006 | P1 | Missing moderator values remain null in the primary dataset and explicitly fail subgroup analysis with `MISSING_MODERATOR_VALUE`. Gate scenarios D–E pass. | RESOLVED |
| RISK-SPR009-007 | P2 | Added 25 traceable Gate-remediation scenarios with 31 assertions, including sensitivity replay/conflict and 6 numerical non-regression assertions. | RESOLVED |

## Resolved by SPR-010 Turn B

| Risk ID | Former priority | Resolution evidence | Status |
|---|---:|---|---|
| RISK-SPR010-001 | P1 | Package validation now recomputes the hash of actual artifact content; mutated scientific content fails both package validation and manifest construction in GATE-D. | RESOLVED |
| RISK-SPR010-002 | P1 | Analysis-scoped artifacts reject a correct-looking result carrying the wrong `Analysis_ID`; GATE-C compares actual SPR-009 output and verifies the mismatch failure. | RESOLVED |
| RISK-SPR010-003 | P1 | Required effect/analysis lineage now requires Evidence/Paper identity, and derived effects additionally require transformation method/version and statistical-input node references; GATE-B passes. | RESOLVED |
| RISK-SPR010-004 | P1 | HUMAN_OWNED protection now includes Reviewer Memo and Critical Appraisal, including blank fields; all six GATE-G attempts are blocked. | RESOLVED |
| RISK-SPR010-005 | P1 | Export Package generator/schema/validation metadata, package persistence, semantic audit reload, and two-version history are verified by GATE-J/M. | RESOLVED |

## Resolved by SPR-011 Turn D

| Risk ID | Former priority | Lifecycle and remediation evidence | Status |
|---|---:|---|---|
| RISK-SPR011-001 | P1 | Turn B reproduced `LIBRARY_ID_LINKAGE_BROKEN + STALE -> AUTO_SAFE/RECONCILED` and failed the Final Gate. Turn C added complete-set precedence and explicit safety predicates. Turn D independently reproduced the input and verified BLOCKED for both plans, AUTO_SAFE=false, zero mutation, order-independent policy hashes, and safe post-reconciliation blocker handling. | RESOLVED |

No risk was closed solely by documentation. SPR-011 Turn B Final Gate remains FAIL in the historical report. Turn D independently closes only `RISK-SPR011-001`; five other P1 risks remain open and therefore SPR-011 Turn D Final Gate is FAIL. `RISK-BASELINE-001` remains open, P2, and non-blocking.
