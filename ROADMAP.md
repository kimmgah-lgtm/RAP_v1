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

## SPR-009 — Meta Analysis & Synthesis Engine (Turn A implemented; Final Gate pending)

- Researcher-confirmed, project-scoped analysis input gate and deterministic dataset builder
- Persistent hashed analysis specifications and versioned results
- Hedges' g derivation plus fixed/random pooling, Q, I², and tau²
- Explicit direction and dependency decisions; subgroup, sensitivity, and funnel-data pathways
- Evidence Graph-compatible lineage, shared operation-ledger idempotency, SQLite persistence, and audit
- Focused scenarios 68/68 PASS and full available safe regression PASS
- All production integrations and synthesis production writes remain disabled

SPR-009 Final Gate and any SPR-010 work are outside this Turn A result.
