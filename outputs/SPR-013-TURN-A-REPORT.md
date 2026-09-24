# SPR-013 Turn A Report

Date: 2026-09-24

Branch: `ASS_v1`

Baseline HEAD: `d3ab408092020d2caef82f9f12f835b6d424798c`

Mode: controlled read-only validation against real Zotero, Google Drive, and Notion research objects

## Outcome

**SPR-013 TURN A = PASS**

Three real papers were inspected. One paper completed the required Zotero -> Library_ID -> Drive PDF -> Notion Common Review identity trace. Two additional papers were safely stopped as `AMBIGUOUS`; neither was repaired or merged.

Production Write remained disabled. No Final Gate was performed and SPR-014 was not started.

## Mutation firewall

- Blocked verbs: CREATE, UPDATE, DELETE, MOVE, MERGE, APPLY
- Reconciliation output: PLAN only; `ApplyPermitted=false`, `ChangesApplied=false`
- Production mutations: Zotero **0** / Drive **0** / Notion **0**
- Secret leakage: **0**

## Preflight and system status

| System | Credential / permission result | Read route | Status |
|---|---|---|---:|
| Zotero | local profile and database readable; no secret required | existing SQLite connector opened `zotero.sqlite` read-only | PASS |
| Google Drive | authenticated profile and PDF search/metadata/raw-read permission verified | connector search, metadata, and streamed raw read | PASS |
| Notion | authenticated workspace; search/fetch/schema/query permission verified | connector self, search, fetch, data-source query | PASS |

The Zotero desktop local HTTP API preference was enabled but the app/port was not running. That route was not needed: the existing SQLite adapter read the real library in `SQLITE_OPEN_READONLY` mode. No credential value, authorization header, signed download URL, or secret was written to the repository.

## Real-paper validation

Actual papers inspected: **3**.

| Library_ID | Zotero item | Drive file ID | Notion page ID | Result |
|---|---|---|---|---:|
| `LIB:L000001` | `FA2MJMIB` | `1TiMDjD2R8zSoUbJcyuJ0KlpMnjeW32ic` | `3e15745c-693d-815c-83a9-d76a91e54e13` | AMBIGUOUS |
| `LIB:L000002` | `XFYHM72S` | `1vlyq2EBO4MmqFLQ_En1Iy500iWRfXXnO` | `3e25745c-693d-81a6-816d-c91d2d95a7df` | AMBIGUOUS |
| `LIB:L000003` | `BCMYA9ZJ` | `1fJgUzCYIHM4pPo6Lo-SfBGT8mqE4-em9` | `3e25745c-693d-8120-890f-c4ffd0819b5a` | MATCHED |

### `LIB:L000003` matched trace

- Title: *Perceptions vs. practices: academic integrity and actual ChatGPT use among EFL students*
- Author/year/DOI: Reem Alsadoon / 2026 / `10.3389/fpsyg.2026.1796737`
- Zotero: item `BCMYA9ZJ`; attachment reference present
- Drive: canonical PDF exists; file size 727,052 bytes
- PDF SHA-256: `1d1366faedb5514f2f3cd1d081d56cbe151464ece932c70cbff227f4244ff5ad`
- PDF metadata and first-page citation match the Zotero and Notion title, author, year, and DOI
- Notion: Common Review page present; `Library ID=L000003`, `Zotero Key=BCMYA9ZJ`, Review Status=`AI Draft`, PDF Lifecycle=`PDF_STAGED`

This is the successful end-to-end identity trace required by Turn A. The project-specific mapping remains missing, so the longer optional lineage stops after Common Review.

### `LIB:L000001` ambiguity

The Zotero bibliographic record, Drive filename, Notion review, PDF title, authors, year, and DOI all agree. However, Zotero contains multiple same-size attachment copies with two SHA-256 values:

- Drive-synchronized canonical and three Zotero copies: `295ba4600c189aa8404cf8698843eef4ceeaa3ed8a8977adc05de01eab6ffdac`
- another Zotero attachment: `d4f04e0b84b552168df877226c64cc61ee18c7f202a791e8cde3c9a16fff4b04`

Both variants expose the same 24-page bibliographic identity, but byte identity is not unique. The Notion `Zotero Key`, `Drive File ID`, `PDF`, `Master Row`, and lifecycle fields are also empty. Status is therefore `AMBIGUOUS`, not PASS or auto-repaired.

### `LIB:L000002` ambiguity

The canonical Drive/Zotero PDF hash matches exactly:

`9d58674e6c4762bbc94b3d6945b94aa569aac7af2a0d39cd5a23b07e86b55942`

The PDF title, authors, year, and DOI match the Notion review. However, Zotero has two bibliographic records for the same title and DOI (`IGAWUUXH` and `XFYHM72S`). Status is `AMBIGUOUS`; automatic merge or canonical selection was blocked.

## Notion schema and review state

The real `Library | Paper Review` data source was readable. Required identity/review fields were present, including Library ID, Paper Title, Authors, Year, DOI, Zotero Key/Link, Drive File ID, PDF, PDF Lifecycle, Review Status, Projects, and Master Row.

Schema result: **PASS**. No `SCHEMA_MISMATCH` was observed in the three live records. The focused suite separately verified fail-closed schema-mismatch behavior.

## Linkage errors

1. The `Pr1 | Study Review` project database is readable but currently contains **0 rows**. Project mappings for all three papers are `MISSING`.
2. `L000001` lacks structured Zotero, Drive, PDF, Master, lifecycle, and project linkage in Notion despite bibliographic content being present.
3. `L000002` and `L000003` have empty structured Drive File ID, PDF URL, Master Row, and Projects values.
4. Several Zotero attachment references use an unresolved `attachments:` base path. The canonical files exist, but the configured connector cannot prove those linked-path targets directly.

These are recorded as reconciliation cases only. No APPLY was performed.

## Research object lineage

For `L000003` the reconstructed lineage is:

`Zotero BCMYA9ZJ -> LIB:L000003 -> Drive 1fJgUz... -> Notion Common Review 3e257... -> Project mapping MISSING`

The first four nodes are verified. The optional Project mapping node is absent, accurately reported as `MISSING` rather than `TEST_DEFERRED` or PASS.

## Human actions required

1. Choose the authoritative `L000001` PDF byte variant after human review, then backfill the structured Zotero/Drive fields.
2. Resolve the duplicate `L000002` Zotero bibliographic records; do not auto-merge.
3. Populate Drive File ID, PDF URL, Master Row, and Projects from authoritative sources for `L000001`-`L000003`.
4. Add the intended paper rows to `Pr1 | Study Review` if these papers belong to that project.
5. Configure the Zotero `attachments:` base path so linked attachment existence can be verified without fallback discovery.

## Manual work and avoidable repetition per paper

Current manual stages are: select/import the Zotero record, assign/tag Library_ID, choose/copy/rename a canonical PDF, calculate/compare its hash, fill Notion identity links, create or review the Common Review, and add project-specific mapping.

Avoidable repetition observed:

- repeated copies of the same PDF in Zotero and Drive;
- repeated entry of title, authors, year, DOI, Library_ID, and filenames across systems;
- filenames and review body containing links that are not copied into structured Notion properties;
- a separate project review database that currently has no rows even though Common Reviews exist.

Turn A does not automate these writes. The next safe improvement is a read-only reconciliation dashboard or human-approved backfill plan, not production APPLY.

## Tests

- Focused research workflow validation: **21 assertions PASS; failures 0**
- Read-only enforcement and mutation verbs: **PASS**
- Identity mapping: **PASS**
- PDF mismatch classification: **PASS**
- Duplicate/ambiguous identity: **PASS**
- Missing object: **PASS**
- Schema mismatch: **PASS**
- Credential/authentication failure: **PASS**
- Timeout: **PASS**
- Secret leakage: **0**
- Reconciliation plan without APPLY: **PASS**
- Full safe RAP regression: **PASS**
- Health dashboard: **PASS; 29 capabilities; 67/67 component commands**
- P0 / P1: **0 / 0**

## Turn boundary

- SPR-013 Turn A implementation and controlled read-only validation: complete
- Actual papers validated: 3
- End-to-end matched traces through Common Review: 1
- Ambiguous cases awaiting human action: 2
- Project mapping: missing for all three; no project rows available
- Production Write: disabled
- Final Gate: not performed
- SPR-014: not started

SPR-013 TURN A COMPLETE —
CONTROLLED READ-ONLY RESEARCH WORKFLOW VERIFIED.
PRODUCTION WRITE REMAINS DISABLED.
FINAL GATE NOT PERFORMED.
