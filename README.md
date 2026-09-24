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

The current prerelease is `v1.0.0-alpha.8`, build `20260922.004`. The health dashboard reads the configuration-backed capability registry and distinguishes enabled capabilities from integrations that remain outside the current sprint.

The Zotero connector exposes normalized, read-only items and collections through either a SQLite reader opened with `SQLITE_OPEN_READONLY` or a GET-only Web API reader. Configure the selected route in `config/config.json`; keep API keys in the named environment variable rather than in configuration.

The Write Layer is disabled by default and accepts only a verified Zotero group whose name contains `Sandbox`. Every operation uses a command object and follows validation, optional dry-run, snapshot, write, verification, commit, audit, or compensating rollback. It never writes directly to Zotero SQLite.

Google Drive is the canonical PDF repository. The Drive connector is GET-only and builds a disposable local index containing file IDs, optional Library_ID values, names, SHA-256 hashes, sizes, modified times, relative folders, and status. Integrity scans report problems but never repair, rename, move, upload, or delete files.

SPR-005 adds the approved Bootstrap and Live lifecycle. Bootstrap always starts with a report-only dry run, requires the exact approval token, performs a scoped clean reset that cannot receive research-asset paths, creates a backup, applies idempotent Library_ID/Master/Notion upserts, verifies integrity, and only then switches to Live mode. Connector operations are injected at the boundary; the engine never accesses Zotero SQLite, Drive, or Notion storage directly.

SPR-007 Turn A adds a fixture-only Meta Coding Engine scoped by `Library_ID + Project_ID`. Typed collections preserve multiple outcomes, comparisons, arms, measurements, time points, statistical inputs, sample sizes, moderators, and effect sizes with dependency and derivation provenance. AI-assisted evidence extraction and researcher-confirmed decisions are stored separately; HUMAN_OWNED fields and Common Study Review content are blocked from AI writes. The existing SQLite Operations ledger provides deterministic checkpoints, replay protection, audit, persistence, and independent-process recovery. Production AI, Notion, Zotero, and Drive writes remain disabled.

SPR-008 Turn A adds a local Evidence Graph as a typed traceability layer over existing RAP identities. Stable Paper, Project, Project-Paper, Evidence, Meta Coding, outcome, effect, statistical input, derived-value, AI-extraction, and researcher-confirmation references are linked by validated edges. Six focused traversal functions expose provenance and lineage without replacing Zotero, Drive, Notion, Project Sheets, or Meta Coding. The graph reuses the SQLite Operations ledger and has no external graph database or production write mode.

SPR-009 Turn A adds a fixture-only Meta Analysis & Synthesis Engine. It accepts researcher-confirmed project coding, creates deterministic analysis datasets and specifications, computes validated fixed/random pooled results and heterogeneity statistics, and supports explicit direction, dependency, subgroup, sensitivity, and diagnostic workflows. Results retain dataset/configuration hashes and Evidence Graph lineage; no scientific interpretation or production write is generated.

SPR-010 adds a fixture-only Research Output & Reproducible Report Engine. It builds deterministic, project-scoped output datasets and versioned structured artifacts, preserves record/analysis/effect/evidence lineage, creates reproducibility manifests and validated export-package abstractions, and detects stale outputs. Turn B verified actual SPR-009 value equivalence, reverse traceability, content rehash/tamper detection, atomic persistence/audit, and version history; Final Gate passed for local/mock development only. Researcher narrative fields, unconfirmed inputs, credentials, private notes, canonical PDFs, external transfers, and production output writes remain blocked. Figure-ready data is implemented; figure rendering is not.

SPR-011 Turn A adds a fixture-only Research Workflow & Exception Management Engine. It provides a 13-class taxonomy, deterministic exception registry, integrity detector, four-state resolution planner, bounded STALE reconciliation, invariant verification, shared-ledger idempotency, atomic SQLite persistence, and semantic audit. It cannot automatically delete, merge, choose a canonical record, overwrite HUMAN_OWNED or researcher-confirmed content, or write to production systems.

See [Installation](docs/INSTALLATION.md), [Architecture](docs/ARCHITECTURE.md), [ADR-0011](docs/adr/ADR-0011-bootstrap-live-operation-policy.md), [SPR-005](docs/SPR-005.md), [SPR-007](docs/SPR-007.md), [SPR-008](docs/SPR-008.md), [SPR-009](docs/SPR-009.md), [SPR-010](docs/SPR-010.md), and [SPR-011](docs/SPR-011.md).
