# RAP Risk Register

Last verified: 2026-09-26, SPR-015 Turn G remediation

Open-risk summary: **P0 = 0, P1 = 0, P2 = 8**.

## Open risks

| Risk ID | Priority | Description and evidence | Impact | Affected component | Gate blocking |
|---|---|---|---|---|---|
| RISK-BASELINE-001 | P2 | No SPR-006 executable source/test artifacts are present in this checkout. | The historical SPR-006 baseline cannot be rerun locally as part of the safe regression. | Repository regression evidence | NO |
| RISK-SPR011-007 | P2 | Turn E: the lifecycle hash chain detects partial edits, forged appends, tail deletion, and deleted audit rows (E3-17~19, EA-10/11), but has no external anchor. An actor with local write access who recomputes the whole chain and head can rewrite history undetected. | Tamper evidence is local-only. | Workflow audit store | NO |
| RISK-SPR011-008 | P2 | Turn E: `Submit-RapHumanReviewDecision` checks the researcher against a configured `AuthorizedResearchers` list and rejects automation identities, but identity is asserted, not authenticated (single-user local agent). | A local process could claim a researcher identity. | Researcher decision workflow | NO |
| RISK-SPR011-009 | P2 | Turn E: downstream impact consumes a normalized Evidence-Graph lineage projection (`Snapshot.Dependents`); an adapter that builds this projection from live `Get-RapEvidenceDependents` / `Get-RapDerivedValueInputs` results is not implemented (same boundary as Turn A: detection consumes normalized snapshots). No competing lineage store was created. | Live wiring must be verified when connectors are enabled. | Workflow ↔ Evidence Graph boundary | NO |
| RISK-SPR011-011 | P2 | Turn E: legacy assertion `'partial commit marked complete'` in `WorkflowExceptionAdversarialTests.ps1` checks a local flag that is never set (vacuous). The requirement is re-mapped to E3-20 and E5-10~17; the historical test was left unchanged. | Legacy assertion count overstates evidence by 1. | Requirements/test evidence | NO |
| RISK-SPR0115-001 | P2 | Production reconciliation adapters remain intentionally deferred; only local/fixture recovery was verified. | Live reconciliation semantics require a separately authorized gate. | Reconciliation external boundary | NO |
| RISK-SPR0115-002 | P2 | Reconciliation and controlled-write persistence use local hashes without an external trust anchor. | A fully privileged local actor could rewrite state and recompute hashes. | Local persistence/audit | NO |
| RISK-SPR015-002 | P2 | Canonical-paper and Zotero lookups use bounded mock registries. Live/read-only connector wiring and normalization at that boundary are deferred. | Production data-shape and connector-read mismatches remain untested. | Research Intake lookup boundary | NO — production remains disabled |

## Resolved by SPR-015 Turn G remediation

| Risk ID | Former priority | RED → GREEN evidence | Status |
|---|---:|---|---|
| RISK-SPR015-011 | P1 | RED: G31/G32 allowed replay without an authoritative, correctly ordered `CANDIDATE_PROMOTED` event. GREEN: decision binding v4 binds unique promotion audit sequence and semantic evidence; actual event Data, subject, provenance, binding, uniqueness and PROMOTE-before-IDENTITY ordering are revalidated. GR01-GR14 14/14 and G01-G32 32/32 PASS. | RESOLVED — remediation; independent Final Re-Gate pending |

## Resolved by SPR-015 Turn F remediation

| Risk ID | Former priority | RED → GREEN evidence | Status |
|---|---:|---|---|
| RISK-SPR015-010 | P1 | RED: F25/F26 allowed replay after identity/lookup audit semantics were removed. GREEN: binding version 3 binds identity, raw lookup, scoped canonical/Zotero audit sequence and semantic evidence hashes; actual event Data, subject, outcome, target, uniqueness and ordering are revalidated. F01-F27 and FR01-FR14 PASS. | RESOLVED — remediation; independent Final Re-Gate pending |

## Resolved by SPR-015 Turn E remediation

| Risk ID | Former priority | RED → GREEN evidence | Status |
|---|---:|---|---|
| RISK-SPR015-008 | P1 | RED: E21 accepted a caller-mutated canonical identity and granted CREATE. GREEN: versioned `IdentityBindingHash`, detached return artifacts, and persisted authority verification block canonical/DOI/PMID/candidate/project/source-evidence substitution. E21, ER01-ER06, and Turn F F01-F05/F17/F24 PASS. | RESOLVED — independently reverified in Turn F |
| RISK-SPR015-009 | P1 | RED: E22 accepted a substituted `ZoteroItemId` after fresh-envelope restart. GREEN: decision/audit bind canonical target, Zotero item, library context, and exact matched-record evidence. E22, ER07-ER12, and Turn F F09-F11/F19/F27 PASS. | RESOLVED — independently reverified in Turn F |

## Resolved by SPR-015 Turn D remediation

| Risk ID | Former priority | RED → GREEN evidence | Status |
|---|---:|---|---|
| RISK-SPR015-005 | P1 | RED: D15/D17 returned stale CREATE after NOT_FOUND changed to TIMEOUT/FOUND. GREEN: decisions bind lookup execution and exact evidence hash; changed/removed/reordered evidence blocks replay. D15/D17 and RD01-RD04/RD12 PASS. | RESOLVED — remediation accepted |
| RISK-SPR015-006 | P1 | RED: D18 accepted a forged CREATE inside a fresh generic envelope. GREEN: versioned semantic `DecisionBindingHash` binds project/question/search/candidate/promotion/identity/lookup/decision/reason/state/time; fresh-envelope and cross-scope laundering fail closed. D18 and RD05-RD07 PASS. | RESOLVED — remediation accepted |
| RISK-SPR015-007 | P1 | RED: D19 found no pre-decision revalidation proof. GREEN: durable `PROMOTION_LINEAGE_REVALIDATED` event is bound by sequence/evidence hash and must precede the decision audit; missing/late/wrong proof and audit-write failure fail closed. D19 and RD08-RD11 PASS. | RESOLVED — remediation accepted |

## Closed by SPR-015 Turn D independent re-verification

| Risk ID | Former priority | Closure evidence | Status |
|---|---:|---|---|
| RISK-SPR015-003 | P1 | Turn D D01-D07 independently confirms default/missing/failed/uncertain lookup cannot create; original Turn C probes 13/13 and remediation 19/19 also pass. | RESOLVED — TURN D |
| RISK-SPR015-004 | P1 | Turn D D08-D12 independently confirms search/project/candidate/DOI and restart-bound lineage substitution fail closed. | RESOLVED — TURN D |

## Resolved by SPR-015 Turn B

| Risk ID | Former priority | Resolution evidence | Status |
|---|---:|---|---|
| RISK-SPR015-001 | P2 | Versioned/hash-verified SQLite persistence retains intake lineage and final decisions; RS01-RS10 verify restart, replay, recovery-required intermediate states, corruption, and invalid transitions. | RESOLVED |

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

## Resolved by SPR-011 Turn E (remediation verified on native Windows; independent re-verification pending in Turn F)

| Risk ID | Former priority | RED → GREEN evidence | Status |
|---|---:|---|---|
| RISK-SPR011-002 | P1 | RED: E1-01~04, E1-06~15 failed before repair. GREEN: `AUTOMATION_FAILURE` (BLOCKED) incl. masked exit-0 failures; ordinal-only class normalization to `UNKNOWN_EXCEPTION`; composite policy rejects unsupported classes and forged `DefaultResolution`; E1-01~15 and EA-01/17/19 PASS. Mutation M5 (disable class check) turns E1-13 red. | RESOLVED (Turn E) |
| RISK-SPR011-003 | P1 | RED: E2-01~04, E2-06/07/09~21 failed. GREEN: lineage-derived impact with executable gate; E05 block modeled and transitive; E06 four dependents REVALIDATION_REQUIRED with transition events and no recomputation; E10 typed retention with model/version/run and confirmation provenance; E11 dependents stay non-CURRENT after DerivedVersion refresh; E01–E12 semantic 12/12 (E2-S-*). Mutation M1 (drop propagation) turns 7 assertions red. | RESOLVED (Turn E) |
| RISK-SPR011-004 | P1 | RED: E3-01~15, E3-17~20 failed. GREEN: hash-chained append-only lifecycle store; actor/actor type, persisted prior state, from/to transitions, failure reason, researcher decision event, distinct final resolution; lifecycle reconstructed from a freshly opened store (E3-13); tamper/tail-deletion detection (E3-17~19, EA-10/11). Mutations M2 and M4 turn the corresponding assertions red. | RESOLVED (Turn E) |
| RISK-SPR011-005 | P1 | Matrix re-mapped to 180 rows (40 legacy + 20 R + 15 CA + 85 E + 20 EA) with the full schema; `WorkflowMatrixTraceabilityTests.ps1` (13 assertions) enforces literal resolution for static rows and bidirectional runtime equality for Turn-E rows; a deliberately broken token is detected. | RESOLVED (Turn E) |
| RISK-SPR011-006 | P1 | RED: E5-01~17 failed. GREEN: deterministic `MALFORMED_SNAPSHOT:*` / `MALFORMED_OPERATION_ID` rejection with zero mutation (E5-01~09, EA-12~16); fault injection at AFTER_STATE, AFTER_AUDIT, AFTER_EVENTS, BEFORE_COMMIT with separate fault / inspect / complete / replay processes: full rollback, `OPERATION_FAILED` recorded, one completion, no duplicates (E5-10~17). Mutation M3 (fault after COMMIT) turns E5-16/17 red. | RESOLVED (Turn E) |
| RISK-SPR011-012 | P1 (found in Turn E) | `GetOperation`/`CommitWorkflow` interpolated `OperationId` into SQL. Fixed by OperationId validation before store access (E5-09) and SQL literal escaping in persistence. | RESOLVED (Turn E) |
| RISK-SPR011-010 | P2 | Native Windows PowerShell re-run after applying the Turn-E bundle: 238/238 focused assertions PASS; 24-script repository regression PASS; SPR-009 Gate remediation 31/31 PASS; Production writes remained disabled. | RESOLVED (Turn E Windows verification) |

No risk above was closed by documentation alone; each has RED evidence before repair and executable GREEN evidence after. Independent Final Gate re-verification (Turn F) has not been performed. `RISK-BASELINE-001` remains open, P2, and non-blocking.
