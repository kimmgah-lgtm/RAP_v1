# Roadmap

## SPR-001 — Platform Bootstrap (complete)

- Local module packaging and configuration
- SQLite-backed queue schema
- Daily plain-text and JSON logging
- Installation, runtime health dashboard, and self-test

## SPR-001.1 — Version and Capability Metadata (complete)

- Semantic prerelease version and deterministic build number
- Configuration-backed capability registry
- Platform identity and capability visibility in the health dashboard

## SPR-002 — Zotero Read-Only Connector (complete)

- Connector facade with SQLite and Web API read routes
- Stable normalized item, attachment, and collection contracts
- Read-only library inventory, child metadata, storage discovery, and statistics
- Isolated unit, connector, normalization, SQLite, Web API, and acceptance tests

## SPR-003 — Transactional Write Layer (complete)

- Sandbox group library enforcement
- Command-based validation, dry-run, snapshot, write, verification, commit, audit pipeline
- Operation-owned compensating rollback and human-review error queue
- Library_ID, Extra, system tag, collection, metadata, and linked attachment commands

## SPR-004 — Google Drive Connector & Verification Engine (complete)

- GET-only Google Drive connector and recursive PDF discovery
- Rebuildable file index and SHA-256 verification
- Linked attachment, missing, broken, duplicate, mismatch, and orphan reporting
- Integrity dashboard, audit records, and no-modification acceptance tests

## SPR-005 — Production Bootstrap Engine (complete)

- Guided scan, report, dry-run, approval, backup, execution, verification, and report lifecycle
- Scoped Production Clean Reset preserving Zotero metadata, Drive PDFs, collections, tags, notes, and linked attachments
- Idempotent Library_ID assignment, Master construction, Notion review creation, and Library Index generation
- Verified second-bootstrap deduplication and Live-mode processing for newly collected papers

## SPR-007 — Meta Coding Engine (complete; Final Gate PASS)

- Project-specific records keyed by `Library_ID + Project_ID`
- AI-assisted evidence fields separated from researcher-confirmed coding
- HUMAN_OWNED and Common Study Review write firewalls
- Deterministic idempotency, checkpoints, audit, and restart recovery
- Multiple effect-size aggregates, dependency identities, transformation provenance, and local SQLite persistence
- Fixture/mock verification only; production external writes remain disabled
- Focused scenarios 42/42 PASS and full available safe regression PASS
- Next-sprint readiness is limited to local/mock development

The official baseline keeps SPR-006 complete. Its code/test artifacts are absent from this checked-out revision, so no SPR-006 tests were locally available to execute during the SPR-007 gate.

## SPR-008 — Evidence Graph (complete; Final Gate PASS)

- Explicit typed node/edge traceability over authoritative RAP references
- Global `Library_ID` and project-specific `Library_ID + Project_ID` contexts preserved
- Evidence status, conflict, AI origin, researcher confirmation, and transformation lineage preserved
- Six targeted forward/reverse traceability queries
- Referential integrity, duplicate-edge prevention, OperationID/PayloadHash replay safety, audit, and SQLite persistence
- Focused scenarios 47/47 PASS and full available safe regression PASS
- Production external graph database and all production writes remain disabled
- Next-sprint readiness is limited to local/mock development

No next Sprint was started during the SPR-008 Final Gate.

## SPR-009 — Meta Analysis & Synthesis Engine (complete; Final Gate PASS)

- Researcher-confirmed, project-scoped analysis input gate and deterministic dataset builder
- Persistent hashed analysis specifications and versioned results
- Hedges' g derivation plus fixed/random pooling, Q, I², and tau²
- Explicit direction and dependency decisions; subgroup, sensitivity, and funnel-data pathways
- Evidence Graph-compatible lineage, shared operation-ledger idempotency, SQLite persistence, and audit
- Focused scenarios 68/68 PASS and full available safe regression PASS
- All production integrations and synthesis production writes remain disabled
- Turn B independently validated the implemented statistical formulas and found six Gate-blocking P1 risks
- Turn C remediated all six P1 risks with 25 new scenarios and 31 assertions; 68/68 legacy scenarios, 25/25 remediation scenarios, and 16/16 available safe test scripts pass
- Turn D reconstructed the missing persistent Gate evidence by rerunning 93 focused scenarios and all 16 available safe test scripts; Final Gate PASS
- P0=0, P1=0, P2=1; `RISK-BASELINE-001` remains open and verified non-blocking
- Next-sprint readiness: YES — LOCAL/MOCK DEVELOPMENT ONLY

## SPR-010 — Research Output & Reproducible Report Engine (complete; Final Gate PASS)

- Explicit, hashed Output Specifications and deterministic project-scoped Output Datasets
- Versioned structured table, result, flow, evidence-summary, and figure-data artifacts
- Record-, Analysis-, Effect Size-, Evidence-, and Paper-level lineage
- Reproducibility Manifest, deterministic Export Package validation, and stale detection
- HUMAN_OWNED narrative firewall and factual-only result statements
- Atomic SQLite state/audit/operation commit using the shared Operations ledger
- 92/92 required core, 10/10 Turn-A adversarial, and 15/15 independent Gate scenarios PASS (173 executable assertions)
- Turn B independently verified SPR-009 value equivalence, reverse traceability, actual-content tamper detection, persistence/audit, and artifact version history
- All 9 available safe local suites PASS; SPR-006 remains unavailable under `RISK-BASELINE-001`
- Production output writes and all real external tests remain disabled/deferred

SPR-010 Final Gate passed. Next-sprint readiness is **YES — LOCAL/MOCK DEVELOPMENT ONLY**. SPR-011 was not started.

## SPR-011 — Research Workflow & Exception Management Engine (Turn D Final Gate FAIL; remediation required)

- Thirteen-class exception taxonomy and deterministic registry identities
- Fixture integrity detector for Zotero, bibliography, Notion, Library_ID, PDF, project, edit, coding, orphan, stale, link, and unknown conditions
- Four resolution states with unsafe AUTO_SAFE escalation and unjustified ignore rejection
- Bounded local STALE reconciliation plus post-resolution safety verification
- No-delete, no-merge, no-canonical-selection, HUMAN_OWNED, confirmed-coding, Library_ID, and source-boundary invariants
- Shared Operations-ledger idempotency, atomic SQLite persistence, and semantic audit trail
- Turn B Final Gate failed after reproducing `LIBRARY_ID_LINKAGE_BROKEN + STALE -> AUTO_SAFE/RECONCILED`
- Turn C added conservative complete-set resolution precedence, explicit AUTO_SAFE safety predicates, fail-closed evidence handling, deterministic policy version/hash audit, and cross-process verification
- Core 69, original adversarial 16, R01-R20 remediation 20, and composite adversarial 15 assertions PASS (120 total); all 10 available safe local suites PASS
- Turn D independently verified the original AUTO_SAFE defect is fixed, but Final Gate failed on remaining E05/E06/E10/E11 semantics, lifecycle auditability, and complete requirement/assertion traceability
- Production workflow writes disabled and external tests deferred

Turn D Final Gate is **FAIL**. Readiness for SPR-011.5 is **NO**; SPR-011.5 and SPR-012 were not started.
