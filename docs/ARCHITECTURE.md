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

## Meta Coding boundary

`ResearchAutomation.MetaCoding` consumes a project-paper membership and source-evidence snapshot through injected dependencies. Every operation is scoped by `Library_ID + Project_ID`; a deterministic input hash and payload hash protect replay and conflict handling. The project aggregate keeps typed collections and stable IDs for outcomes, comparisons, arms, measurements, time points, statistical inputs, sample sizes, moderators, and multiple effect sizes. Effect records retain reference IDs and a dependency-group identity instead of flattening within-study relationships.

Fixture persistence extends the existing RAP SQLite queue: the existing `Operations` table remains the operation ledger, while Project Registry, Project-Paper Map, coding-record, and audit tables store domain state. The workflow persists `PLANNED`, `EXTRACTED`, `VALIDATED`, `PATCH_PREPARED`, and `COMPLETED` checkpoints so an interrupted write can resume in an independent process without regenerating extraction.

The record has separate `AiAssisted` and `ResearcherConfirmed` branches. AI output is limited to the approved meta-coding schema and must carry an evidence status. HUMAN_OWNED judgments and Common Study Review fields are rejected at validation. Researcher confirmation has a separate explicit command and preserves assisted evidence. The module deliberately exposes only DryRun and Fixture modes; production external writes are disabled.

## Evidence Graph boundary

`ResearchAutomation.EvidenceGraph` is a traceability layer, not a source-of-truth replacement. Nodes hold stable references to Paper, Project, Project-Paper, Common Review, Evidence, AI Extraction, Meta Coding, outcome, comparison, effect, measurement, time point, statistical input, derived value, and researcher-confirmed records. Typed edges express provenance and lineage while validation rejects missing endpoints, invalid type pairs, cross-project contamination, Common Review misuse, and HUMAN_OWNED payloads.

The graph preserves global `Library_ID` identity alongside project scope `Library_ID + Project_ID`. Evidence status is carried by Evidence nodes and never inferred from edge existence. Derived values retain links to source statistical-input nodes; explicit confirmation edges do not change the AI-assisted origin node.

Fixture persistence extends the existing local SQLite queue with graph node, edge, snapshot, and audit tables while continuing to use the shared `Operations` ledger for OperationID/PayloadHash replay and recovery. No Neo4j, external graph service, or production connector is introduced. Six query functions provide bounded forward and reverse traversal rather than a general-purpose query language.

## Meta Analysis & Synthesis boundary

`ResearchAutomation.Synthesis` consumes only researcher-confirmed SPR-007 records in one `Project_ID` context. Its deterministic dataset rows retain Library, Meta Coding, effect, outcome, comparison, arm, measurement, time-point, dependency, provenance, and statistical-input identities. It rejects AI-only, conflicting, incomplete, cross-project, duplicate, unsupported, and invalid numerical inputs.

Analysis specifications make model, estimator, scopes, moderators, dependency strategy, diagnostics, and engine version explicit and hash them canonically. The engine implements fixed-effect and DerSimonian–Laird random-effects synthesis, Q/I²/tau², explicit Hedges' g derivation, approved direction reversal, subgroup summaries, leave-one-out sensitivity, and funnel data. It never writes scientific interpretation or selects research decisions automatically.

SQLite persistence reuses the RAP `Operations` ledger for OperationID/PayloadHash semantics and stores versioned specifications, results, lineage, and audit events locally. Analysis-result lineage references upstream effect/evidence/input identities compatible with the Evidence Graph; it does not mutate Meta Coding or replace graph provenance. Production synthesis writes remain disabled.
