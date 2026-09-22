# Research Automation Platform (RAP)

This repository contains the local RAP agent and its read-only Zotero connector. Cloud controller internals and all write integrations remain outside this repository's local scope.

## Requirements

- PowerShell 7 or later
- Windows 10/11 (uses the Windows-provided SQLite library)

## Quick start

```powershell
pwsh -NoProfile -File ./src/Local/ResearchAutomation.Local/Install.ps1
pwsh -NoProfile -File ./src/Local/ResearchAutomation.Local/Run-Agent.ps1 -SelfTest
```

Installation is idempotent. Runtime state is stored beneath `src/Local/ResearchAutomation.Local`: configuration in `config`, the SQLite queue in `queue`, daily plain/JSON logs in `logs`, and disposable runtime files in `temp`.

The current prerelease is `v1.0.0-alpha.5`, build `20260922.001`. The health dashboard reads the configuration-backed capability registry and distinguishes enabled capabilities from integrations that remain outside the current sprint.

The Zotero connector exposes normalized, read-only items and collections through either a SQLite reader opened with `SQLITE_OPEN_READONLY` or a GET-only Web API reader. Configure the selected route in `config/config.json`; keep API keys in the named environment variable rather than in configuration.

The Write Layer is disabled by default and accepts only a verified Zotero group whose name contains `Sandbox`. Every operation uses a command object and follows validation, optional dry-run, snapshot, write, verification, commit, audit, or compensating rollback. It never writes directly to Zotero SQLite.

Google Drive is the canonical PDF repository. The Drive connector is GET-only and builds a disposable local index containing file IDs, optional Library_ID values, names, SHA-256 hashes, sizes, modified times, relative folders, and status. Integrity scans report problems but never repair, rename, move, upload, or delete files.

SPR-005 adds the approved Bootstrap and Live lifecycle. Bootstrap always starts with a report-only dry run, requires the exact approval token, performs a scoped clean reset that cannot receive research-asset paths, creates a backup, applies idempotent Library_ID/Master/Notion upserts, verifies integrity, and only then switches to Live mode. Connector operations are injected at the boundary; the engine never accesses Zotero SQLite, Drive, or Notion storage directly.

See [Installation](docs/INSTALLATION.md), [Architecture](docs/ARCHITECTURE.md), [ADR-0011](docs/adr/ADR-0011-bootstrap-live-operation-policy.md), and [SPR-005](docs/SPR-005.md).
