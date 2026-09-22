# Local Architecture

`Run-Agent.ps1` is the composition root. It imports `ResearchAutomation.Local.psd1`, reads validated configuration, initializes logging and the SQLite queue, then asks `SelfTest` for a health report. The report carries the semantic platform version, deterministic build number, and configuration-backed capability registry.

The root module composes four focused modules:

- `Config`: path resolution, JSON loading, version/build/capability validation, and first-run creation
- `Logger`: append-only daily plain and JSON-lines logging
- `Queue`: SQLite native binding, schema creation, integrity checks, and queue probes
- `SelfTest`: independent checks and aggregate health status

Runtime dependencies point inward through exported PowerShell functions. Configuration contains relative data paths; they resolve against the application root and cannot escape it. Database schema creation uses `CREATE TABLE IF NOT EXISTS`, logger initialization is repeatable, and configuration creation never overwrites an existing file.

## Zotero connector boundary

The platform imports only `ZoteroConnector.psm1`, which acts as the `IZoteroConnector` facade. The facade selects `SQLiteReader.psm1` or `WebApiReader.psm1`; platform code never imports either reader directly. `Normalizer.psm1` converts both source shapes to the same item, attachment, and collection models, so SQLite table details and Web API response details do not cross the connector boundary.

The SQLite adapter opens databases with `SQLITE_OPEN_READONLY` and rejects write-capable SQL keywords. The Web API adapter implements HTTP GET only and requires HTTPS for non-loopback endpoints. Neither adapter contains a create, update, delete, upload, or synchronization operation.

## Transactional Write Layer

The write path is separate from the read connector: platform → `IWriteConnector` facade → Zotero Web API write connector → transaction engine → verification → audit. It never writes SQLite. Command objects provide Validate, Execute, Verify, and Rollback behaviors. The transaction engine implements a compensating transaction because Zotero Web API requests cannot participate in one atomic database transaction.

All write contexts are bound to a verified Sandbox group. Rollback removal follows ADR-002 and is limited to data created by the same operation.

## Google Drive verification boundary

Platform code reaches Drive only through the `IDriveConnector` facade implemented by `GoogleDrive.psm1`. Its connector issues GET requests only. The verification engine consumes the rebuildable Drive index and normalized Zotero linked-attachment descriptors, computes SHA-256 from read content, and emits integrity reports and append-only audit records. It never repairs links or modifies PDF content, names, parents, or sharing state.

## Bootstrap and Live lifecycle

`ResearchAutomation.Bootstrap` orchestrates approved connector boundaries and never directly accesses Zotero SQLite, Drive storage, or Notion persistence. Dry run is side-effect free. Production execution requires an exact approval token, a safe reset result declaring research assets preserved, a backup snapshot, Drive integrity PASS, and final verification PASS. Only a fully successful bootstrap may change the mode to Live. Live processing handles one detected normalized item at a time and reuses the same idempotent ID, Master, Notion, queue, and dashboard boundaries.
