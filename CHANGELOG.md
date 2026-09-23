# Changelog

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
