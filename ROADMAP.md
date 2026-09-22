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

Future integrations are deliberately excluded from this sprint and require separate approved sprint scope.
