# Changelog

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
