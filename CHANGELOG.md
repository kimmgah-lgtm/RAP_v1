# Changelog

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
