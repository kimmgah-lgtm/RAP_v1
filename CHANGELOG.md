# Changelog

## Unreleased — SPR-015 Turn C P1 remediation

- Persisted authoritative lookup outcomes and required canonical/Zotero `NOT_FOUND` evidence before any `CREATE_CANDIDATE` decision; lookup uncertainty now remains blocked across restart.
- Sealed PROMOTE search lineage, candidate identity, researcher provenance, and timestamp, with revalidation before identity/dedup advancement and after reload.
- Advanced Research Intake persistence to schema v2 with fail-closed legacy/default handling; passed original probes 13/13, expanded remediation 19/19, Turn A/B suites, and full safe regression.
- Kept SPR-015 CORE COMPLETE=NO, connector-read pilot blocked, Production Write disabled, and production mutations 0/0/0 pending an independent Turn D Final Re-Gate.

## Unreleased — SPR-015 Turn C independent Final Gate

- Independently reran the Turn A/B suites and the full safe regression successfully, with secret leakage 0 and production Zotero/Drive/Notion mutations 0/0/0.
- Added 13 independent semantic/adversarial Gate probes; 10 passed and 3 exposed two Gate-blocking P1 risks in lookup-failure enforcement and search-lineage promotion binding.
- Recorded Turn C as FAIL with SPR-015 CORE COMPLETE=NO and READY FOR CONNECTOR READ PILOT=NO; no remediation or production activation was performed.

## Unreleased — SPR-015 Turn B durable intake

- Added versioned, hash-verified SQLite persistence for Research Intake lineage, identity, lookup, decision, audit, and lifecycle state.
- Added restart-safe replay, RECOVERY_REQUIRED intermediate states, DOI/PMID and title-author-year conflict hardening, and fail-closed read-only lookup outcomes.
- Passed 32/32 new restart/lookup/identity tests, Turn A 41/41 regression, and the full safe regression with production mutations 0/0/0.

## Unreleased — SPR-015 Turn A Research Intake core

- Added a typed LOCAL/MOCK Research Intake workflow from Research Question through explicit PROMOTE ONE and a non-mutating pre-Zotero CREATE/REUSE decision.
- Added fail-closed DOI normalization, identity priority, candidate/project binding, fuzzy ambiguity, incomplete-mapping blocking, idempotent promotion, and lineage audit.
- Passed 41/41 new contract, zero-duplicate, Inbox safety, and adversarial assertions plus the full available safe regression.
- Kept Production Write disabled, Production Pilot TEST_DEFERRED, and Zotero/Drive/Notion production mutations at 0/0/0.

## Unreleased — SPR-014 Turn D Final Gate and SPR-015 architecture preservation

- Independently passed R01-R18, CW01-CW20, 14 Gate probes, SPR-012/013 regressions, and the full available safe regression.
- Closed SPR-014 with P0/P1 0/0, secret leakage 0, and production mutations 0/0/0 while keeping Production Write disabled and the production pilot TEST_DEFERRED.
- Accepted ADR-0012 and refined the SPR-015 one-paper zero-duplicate intake requirements without implementing SPR-015.

## Unreleased — SPR-013 controlled read-only validation Turn A

- Added a pure read-only cross-system identity classifier and PLAN-only reconciliation-case builder; no APPLY path is exposed.
- Read three real Zotero/Drive/Notion paper chains: `L000003` MATCHED, while `L000001` and `L000002` were conservatively classified AMBIGUOUS.
- Verified real PDF title/author/year/DOI identity and SHA-256 evidence, Notion review schema/status, and missing project mappings without modifying any external system.
- Passed 21 focused assertions and the full safe RAP regression with zero focused failures, zero secret leakage, P0/P1 0/0, and production mutations 0/0/0.
- Kept Production Write disabled, did not perform the Final Gate, and did not start SPR-014.

## Unreleased — SPR-012 production readiness Turn A

- Added explicit LOCAL/TEST/PRODUCTION environment guards, read-only Zotero/Drive/Notion probe adapters, fail-closed preflight, a production write firewall, and deterministic mutation manifests with apply disabled.
- Passed PR01–PR16 (16/16), adversarial (17/17), credential leakage (2/2), and the full available safe RAP regression.
- Recorded live Zotero, Drive, and Notion probes as `TEST_DEFERRED` because no credential or explicit target was configured; production mutations remained 0/0/0.
- Did not perform the SPR-012 Final Gate, determine next-sprint readiness, start Turn B, or enable any production write.

## SPR-011.5 reconciliation Final Gate

- Added the local/fixture Data Integrity, Reconciliation, and Exception Recovery
  Engine with ownership-aware decisions, plan-before-apply, stale-plan blocking,
  idempotency, persisted read-back verification, audit, and transactional
  restart/fault recovery.
- Verified the 53/53 focused assertions, repeated the negative 16/16 and
  adversarial 13/13 suites independently, and passed the full available safe RAP
  regression.
- Passed the SPR-011.5 Turn B Final Gate with P0=0, P1=0, production
  Zotero/Drive/Notion changes 0/0/0, and production writes disabled.
- Retained seven non-blocking P2 limitations and deferred all external/live
  reconciliation integrations. SPR-012 was not started.

## SPR-011 Turn E P1 remediation

- Applied the Turn-E remediation bundle to the native Windows workspace and verified 238/238 focused assertions, the 24-script full available regression, and the SPR-009 Gate suite (31/31); resolved `RISK-SPR011-010`.
- Reproduced every open P1 (RISK-SPR011-002~006) as failing assertions first: 69/85 Turn-E assertions failed against the Turn-D engine (RED), 85/85 pass after repair (GREEN).
- Taxonomy: added `AUTOMATION_FAILURE` (BLOCKED), including masked failures (exit 0 with error evidence); `ConvertTo-RapExceptionClass` / `ConvertTo-RapNormalizedException` normalize unsupported, null, differently-cased, or padded classes to `UNKNOWN_EXCEPTION`; the composite policy rejects forged classes and forged `DefaultResolution` values.
- Downstream semantics: `Get-RapDownstreamImpact` derives effective artifact status (CURRENT < STALE < REVALIDATION_REQUIRED < BLOCKED) transitively from the snapshot's normalized Evidence-Graph lineage projection; missing references and cycles block. `Test-RapDependentOperationPermitted` is the executable downstream gate. PDF, STALE, and AI-conflict evidence now carry affected artifacts / typed conflict provenance; AI alternatives are retained as `RETAINED_NOT_APPLIED`.
- Audit: append-only SHA-256 hash-chained `WorkflowLifecycleEvents` + `WorkflowChainHead`; audit rows carry actor, actor type, prior state, transitions, failure reason, final status; `Submit-RapHumanReviewDecision` (researcher-only, authorized list, idempotent) and `Get-RapExceptionLifecycle`; `Test-RapWorkflowAuditChain` detects in-place edits, forged appends, tail deletion, and deleted audit rows.
- Error paths: deterministic `MALFORMED_SNAPSHOT:*` and `MALFORMED_OPERATION_ID` rejection before any store access; SQL literal escaping for OperationKey; fault injection at four transaction boundaries with cross-process rollback/restart/replay verification; `OPERATION_FAILED` event recorded after rollback.
- Traceability: `docs/SPR-011-SCENARIO-MATRIX.md` re-mapped to 180 rows with the full schema; `WorkflowMatrixTraceabilityTests.ps1` enforces it statically and at runtime.
- Policy version `SPR-011-TURN-E-1`; Workflow module `1.0.0-alpha.12`. Two legacy pins were updated intentionally (taxonomy count 13→14; policy version in R20/recovery helper).
- Final Gate not performed (Turn F); no production write, real external data access, commit, push, SPR-011.5, or SPR-012 work.

## Unreleased — SPR-011 Turn D Final Gate

- Independently verified that the Turn-B `LIBRARY_ID_LINKAGE_BROKEN + STALE` defect is fixed: both plans are BLOCKED, AUTO_SAFE is false, and no reconciliation mutation occurs.
- Passed order independence, fail-closed policy, Library_ID protection, post-reconciliation blocker, ownership firewall, R01-R20, 120/120 focused assertions, two-process recovery, and all 10 available safe component suites.
- Reconfirmed missing mandatory evidence/behavior for E05, E06, E10, and E11, incomplete lifecycle audit fields, and incomplete legacy requirement/assertion traceability; five P1 risks remain open.
- Recorded SPR-011 Turn D Final Gate FAIL and readiness for SPR-011.5 = NO. No production write, real external data access, commit, push, SPR-011.5, or SPR-012 work occurred.

## Unreleased — SPR-011 Turn C remediation

- Preserved the Turn B Final Gate FAIL and reproduced the unsafe `LIBRARY_ID_LINKAGE_BROKEN + STALE -> AUTO_SAFE/RECONCILED` transition before repair.
- Added a conservative complete-exception-set policy with `BLOCKED > HUMAN_REVIEW_REQUIRED > AUTO_SAFE`, explicit AUTO_SAFE allow-list predicates, and fail-closed handling for missing/malformed safety evidence.
- Added policy version `SPR-011-TURN-C-1`, deterministic policy hashing, and persisted policy decision/reason metadata.
- Added R01-R20 and 9 independent adversarial cases, including order/duplicate invariance and two-process persistence/restart determinism; 120 total SPR-011 assertions pass.
- Passed all 10 available safe local RAP component suites; retained unavailable SPR-006 as `RISK-BASELINE-001`.
- Did not perform the Final Gate, start SPR-011.5/SPR-012, enable production writes, access real external data, commit, or push.

## Unreleased — SPR-011 Turn A

- Added the fixture-only Research Workflow & Exception Management Engine with 13 explicit exception classes and stable exception fingerprints.
- Added deterministic integrity detection, registry deduplication, four-state resolution planning, bounded STALE reconciliation, invariant verification, and semantic safety audit.
- Enforced no automatic deletion, merge, arbitrary canonical selection, HUMAN_OWNED overwrite, researcher-confirmed overwrite, Library_ID change, or production write.
- Added shared Operations-ledger replay/conflict handling and atomic SQLite persistence for exceptions, plans, reconciliations, verifications, and audit.
- Passed 69 core and 16 adversarial executable assertions, plus all 10 available safe RAP suites. SPR-006 remains unavailable under `RISK-BASELINE-001`.
- SPR-011 Final Gate was not performed; SPR-012 was not started; no external production tests, commit, or push occurred.

## Unreleased — SPR-010 Turn B Final Gate

- Independently verified 15/15 Gate scenarios with 62 executable assertions, including bidirectional project isolation and actual SPR-009 result equivalence at `1e-12` tolerance.
- Strengthened required Evidence/Paper and derived statistical-input lineage, Analysis_ID scope validation, and Reviewer Memo/Critical Appraisal HUMAN_OWNED protection.
- Changed tamper validation to recompute hashes from actual artifact, manifest, and package content instead of trusting stored hash metadata.
- Added generator/schema/validation metadata to Export Packages, package persistence/reload, semantic audit reload, and independent artifact-version history verification.
- Passed 117/117 total SPR-010 scenarios with 173 assertions and all 9 available safe RAP suites; retained `RISK-BASELINE-001` as the sole open non-blocking P2.
- Recorded SPR-010 Final Gate PASS and next-sprint readiness for local/mock development only. No production write, external-system test, commit, push, or SPR-011 implementation was performed.

## Unreleased — SPR-010 Turn A

- Added the fixture-only Research Output & Reproducible Report Engine with explicit specifications, deterministic output datasets, versioned artifact identities, content/config/source hashes, and stale detection.
- Added structured study, Meta Coding, effect, synthesis, heterogeneity, moderator, sensitivity, publication-bias, screening-flow, evidence-summary, and figure-data outputs without scientific interpretation.
- Added reproducibility manifests, deterministic export-package validation, researcher narrative firewalls, verified-input gates, project isolation, credential/PDF/private-note exclusion, and path safety.
- Added atomic SQLite state/audit/operation commits through the existing Operations ledger and preserved artifact version history.
- Passed 92/92 core and 10/10 adversarial scenarios with 111 executable assertions, plus all 9 available safe RAP suites. SPR-006 remains unavailable under the open non-blocking `RISK-BASELINE-001`.
- Kept every production write disabled and real external tests deferred. SPR-010 Final Gate was not performed and SPR-011 was not started.

## Unreleased — SPR-009 Turn D Final Gate state reconciliation

- Reconstructed missing Turn D evidence by rerunning 93/93 focused scenarios (99 assertions, 17 numerical) and all 16 available safe local test scripts.
- Verified P0=0, P1=0, P2=1; retained `RISK-BASELINE-001` as an open, verified non-blocking P2 because SPR-006 executable artifacts remain absent.
- Recorded SPR-009 Final Gate PASS and next-sprint readiness for local/mock development only while preserving the historical Turn B FAIL and Turn C remediation history.
- Verified all production writes disabled and production data changes Zotero=0, Drive=0, Notion=0. SPR-010 was not started.

## Unreleased — SPR-009 Turn C remediation

- Enforced complete derived-effect provenance, explicit model/estimator selection, missing-moderator rejection, and explicit failure for unsupported dependency strategies.
- Integrated synthesis dataset eligibility with validated SPR-008 Project-Paper, Meta Coding, Effect, Evidence, statistical-input, derived-value, and Paper lineage.
- Persisted leave-one-out sensitivity analyses as reproducible child runs with hashes, engine version, provenance, audit metadata, idempotent replay, and independent-process reload coverage.
- Added 25 Gate-remediation scenarios with 31 assertions, retained 68/68 legacy passes, and passed all 16 available safe test scripts.
- Resolved the six Turn B P1 risks without performing the Final Gate, starting SPR-010, enabling production writes, or using external data.

## Unreleased — SPR-009 Turn B Final Gate

- Re-ran all 68 SPR-009 focused assertions and all 15 available safe RAP test scripts; both suites passed.
- Independently reproduced the implemented Hedges' g, variance/SE, fixed-effect, DerSimonian-Laird random-effects, CI, Q, I², and tau² calculations.
- Recorded a failed SPR-009 Final Gate because six current P1 defects violate dependency safety, researcher-decision, provenance, lineage, sensitivity-persistence, and moderator-validation requirements.
- Added the current evidence-based Risk Register. No production write, external-data access, commit, push, or SPR-010 implementation was performed.

## 1.0.0-alpha.8 - 2026-09-22

- Added the SPR-009 fixture-only Meta Analysis & Synthesis Engine with researcher-confirmed input gating, deterministic datasets, explicit specifications, and analysis versioning.
- Added Hedges' g derivation, fixed/random pooling, Q/I²/tau², direction and dependency safeguards, subgroup summaries, leave-one-out sensitivity, and funnel diagnostic data.
- Added Evidence Graph-compatible lineage, shared operation-ledger idempotency, SQLite persistence/audit, 68 focused assertions, and safe regression integration.
- Kept production AI, Zotero, Drive, Notion, and synthesis writes disabled.

## 1.0.0-alpha.7 - 2026-09-22

- Added the SPR-008 Evidence Graph Turn A with typed nodes, typed edges, deterministic evidence/edge identities, project-context validation, and referential integrity checks.
- Added traceability queries for Library-to-Evidence, Project-Paper-to-Meta-Coding, Effect-to-Evidence, Derived-Value-to-Inputs, Evidence reverse dependencies, and Project-to-Project-Paper relationships.
- Added SQLite node/edge/state/audit persistence through the existing Operations ledger, replay conflict protection, and independent Process A/Process B recovery.
- Added 47 fixture/local assertions and full available safe regression integration; all production external writes remain disabled.
- Re-ran the focused suite and full safe regression, verified SPR-008 Final Gate PASS, and limited next-sprint readiness to local/mock development only.

## 1.0.0-alpha.6 - 2026-09-22

- Added the SPR-007 Meta Coding Engine Turn A with `Library_ID + Project_ID` scope.
- Added typed AI-assisted evidence output for outcomes, comparisons, effect data, samples, moderators, arms, measurements, time points, and statistical inputs.
- Added explicit separation and preservation of researcher-confirmed HUMAN_OWNED decisions and Common Study Review content.
- Added deterministic operation IDs, payload conflict detection, checkpoints, replay protection, append-only audit hooks, and restart-style recovery.
- Added local SQLite persistence through the existing Operations ledger, typed multiple-effect aggregates, derivation provenance, and independent Process A/Process B recovery.
- Added 42 fixture/mock scenario assertions; production AI, Notion, Zotero, and Drive writes remain disabled.
- Verified focused tests and the full available safe RAP regression, and recorded SPR-007 Final Gate PASS; next-sprint readiness is local/mock development only.

## 1.0.0-alpha.5 - 2026-09-22

- Approved ADR-0011 defining Bootstrap and Live operating modes.
- Added the Production Bootstrap Engine, guided wizard, library scanner/indexer, safe reset, Notion bootstrap boundary, and immutable reports.
- Added exact-token approval, mandatory backup, integrity gates, idempotent second-bootstrap behavior, and Live paper processing.
- Added unit and acceptance coverage proving zero duplicate IDs/pages and preservation of research assets.

## 1.0.0-alpha.4 - 2026-09-21

- Added the read-only Google Drive connector and recursive PDF discovery.
- Added rebuildable Drive indexing, SHA-256 verification, linked-attachment checks, duplicate detection, and integrity reports.
- Added report-only audit and acceptance tests proving no Drive or PDF modification.

## 1.0.0-alpha.3 - 2026-09-21

- Added the Sandbox-only transactional Zotero Write Layer.
- Added command objects for Library_ID, Extra, system tags, collections, metadata, and linked attachments.
- Added validation, dry-run, snapshots, verification, compensating rollback, audit, queue execution, events, and idempotency.
- Added transaction, rollback, verification, queue, audit, sandbox guard, and acceptance tests.

## 1.0.0-alpha.2 - 2026-09-21

- Added the read-only Zotero connector facade with SQLite and Web API readers.
- Added normalized items, collections, creators, tags, notes, attachments, annotations, storage discovery, and library statistics.
- Added isolated connector, SQLite, Web API, normalization, sample-library, and acceptance tests.
- Enabled the Zotero capability and extended the health dashboard.

## 1.0.0-alpha.1 - 2026-09-21

- Added semantic platform version and deterministic build number metadata.
- Added the configuration-backed capability registry.
- Added version, build, and capability visibility to the health dashboard.

## 0.1.0 - 2026-09-21

- Added the PowerShell 7 local agent bootstrap.
- Added idempotent configuration, directory, SQLite queue, and logging initialization.
- Added health dashboard and complete bootstrap self-test.
- Added operator and architecture documentation.
