# RAP Handoff

> 문서 경로: `docs/HANDOFF.md`
> 최종 갱신일: 2026-09-26 15:11:30 +09:00 (Asia/Seoul)

## Current Sprint

SPR-015 — Turn F remediation PASS; LOCAL/DURABLE CORE COMPLETE=NO; independent Final Re-Gate pending.

## Baseline HEAD before SPR-015 Turn A

`ef89b0073d172edb7efcc2680b32ca2b7dcbcdf4`

## Branch

`ASS_v1`, tracking `origin/ASS_v1`.

## Gate status

- SPR-011.5 Turn B Final Gate: **PASS**
- SPR-012 Turn A implementation verification: **PASS**
- SPR-012 Turn B Final Gate: **FAIL** (historical; `RISK-SPR012-001`)
- SPR-012 Turn C targeted remediation: **COMPLETE / PASS**
- SPR-012 Turn D Final Gate: **PASS**
- SPR-012: **COMPLETE**
- Ready for SPR-013 Controlled Read-Only Validation: **YES**
- SPR-013 Turn A implementation and real read-only validation: **COMPLETE / PASS**
- Actual papers inspected: **3**
- `LIB:L000003`: **MATCHED** through Notion Common Review
- `LIB:L000001`, `LIB:L000002`: **AMBIGUOUS / HUMAN ACTION REQUIRED**
- SPR-013 Turn B Final Gate: **PASS**
- SPR-013: **COMPLETE**
- Ready for SPR-014 Controlled Write Pilot: **YES**
- SPR-014 Turn A controlled-write implementation: **COMPLETE / PASS**
- SPR-014 actual production pilot: **TEST_DEFERRED**
- SPR-014 Turn B Final Gate: **FAIL**
- SPR-014 Turn C P1 remediation: **COMPLETE / PASS**
- SPR-014 Turn D Final Gate: **PASS**
- SPR-014: **COMPLETE**
- Ready for SPR-015 E2E Research Intake Pilot: **YES — REQUIREMENTS/LOCAL-MOCK DEVELOPMENT ONLY**
- SPR-015 product requirements: **ACCEPTED** in `docs/SPR-015-REQUIREMENTS.md`
- SPR-015 Turn A local/mock core: **COMPLETE / PASS**
- SPR-015 Turn B durable intake: **COMPLETE / PASS**
- SPR-015 Turn C independent Final Gate: **FAIL — 2 P1 blockers**
- SPR-015 Turn C remediation: **PASS — both P1 RED→GREEN; Final Re-Gate pending**
- SPR-015 Turn D independent Final Re-Gate: **FAIL — 15/19 probes PASS, 4 FAIL, 3 new P1 blockers**
- SPR-015 Turn D remediation: **PASS — RISK-SPR015-005/006/007 RED→GREEN; 12/12 remediation and 19/19 Turn D probes; Final Re-Gate pending**
- SPR-015 pre-Turn E user disposition (historical): **LOCAL/DURABLE CORE COMPLETE=YES; READY FOR CONNECTOR READ PILOT=CONDITIONAL**
- SPR-015 Turn E independent Final Re-Gate: **FAIL — 20/22 probes PASS, E21/E22 FAIL, 2 new P1 blockers**
- SPR-015 Turn E remediation: **PASS — E01-E22 22/22 and ER01-ER12 12/12; open P1=0; Final Re-Gate pending**
- SPR-015 Turn F independent Final Re-Gate: **FAIL — 25/27 probes PASS; F25/F26 exposed RISK-SPR015-010; P0/P1/P2=0/1/8**
- SPR-015 Turn F remediation: **PASS — F01-F27 27/27 and FR01-FR14 14/14; P0/P1/P2=0/0/8; Final Re-Gate pending**
- SPR-015 current Gate disposition: **LOCAL/DURABLE CORE COMPLETE=NO; READY FOR CONNECTOR READ PILOT=NO**
- SPR-015 production implementation/pilot: **NOT STARTED / TEST_DEFERRED**
- SPR-015R implementation: **NOT STARTED**

Passing component suites verify their bounded local/mock contracts, but Turn F does not close the end-to-end Gate. Nothing here authorizes Production Write or converts deferred live probes to PASS.

## Tests

- Read capability boundary A–G: **7/7 PASS**
- Security assertion `ReadProbe callback cannot obtain or invoke mutation capability`: **PASS**
- PR01–PR16 focused: **16/16 PASS**
- Production readiness adversarial: **17/17 PASS**
- Credential leakage: **2/2 PASS; leaks 0**
- Reconciliation core/negative/adversarial/traceability: **53/53 PASS**
- Health dashboard: **PASS**, 29 capabilities and 67/67 component commands
- Evidence Graph: **47/47 PASS**
- Synthesis: **68/68 PASS**
- Output core/adversarial/gate: **92/92, 10/10, 15/15 PASS**
- Workflow core/adversarial/remediation/traceability: **PASS**, including Turn-E 85/85 and 20/20 adversarial
- Full available safe RAP regression: **PASS**
- Mandatory failures: **0**
- SPR-015 Turn F independent probes: **25/27 PASS; F25/F26 FAIL**
- SPR-015 Turn F probes after remediation: **27/27 PASS; remediation 14/14 PASS**
- SPR-013 focused validation: **21 assertions PASS; failures 0**
- Reconciliation negative/adversarial Gate rerun: **16/16 and 13/13 PASS**
- SPR-013 Turn B full safe regression: **PASS**
- SPR-014 controlled-write focused CW01-CW10: **10/10 PASS**
- SPR-014 controlled-write adversarial CW11-CW20: **10/10 PASS**
- SPR-014 Turn A full safe RAP regression: **PASS**
- SPR-014 mandatory failures: **0**
- SPR-014 Turn B independent Final Gate adversarial probes: **10/14 PASS; 4 FAIL**
- SPR-014 Turn B full safe RAP regression: **PASS**
- SPR-014 Turn B mandatory Gate failures: **4**
- SPR-014 Turn C remediation R01-R18: **18/18 PASS**
- SPR-014 independent Gate probes after remediation: **14/14 PASS**
- SPR-014 CW01-CW20 after remediation: **20/20 PASS**
- SPR-014 Turn C full safe RAP regression: **PASS**
- SPR-014 Turn C mandatory failures: **0**
- SPR-014 Turn D remediation R01-R18: **18/18 PASS**
- SPR-014 Turn D independent Gate probes: **14/14 PASS**
- SPR-014 Turn D CW01-CW20: **20/20 PASS**
- SPR-014 Turn D SPR-013 regression: **21 assertions PASS**
- SPR-014 Turn D SPR-012 focused/adversarial/boundary: **16/16, 17/17, 7/7 PASS**
- SPR-014 Turn D full safe RAP regression: **PASS; exit code 0**
- SPR-014 Turn D mandatory failures: **0**
- SPR-015 Turn A contract: **10/10 PASS**
- SPR-015 Turn A zero-duplicate: **10/10 PASS**
- SPR-015 Turn A Research Inbox safety: **8/8 PASS**
- SPR-015 Turn A adversarial: **13/13 PASS**
- SPR-015 Turn A total: **41/41 PASS**
- SPR-015 Turn A full safe RAP regression: **PASS; exit code 0**
- SPR-015 Turn B restart/lookup/identity: **10/10, 10/10, 12/12 PASS**
- SPR-015 Turn B full safe RAP regression: **PASS; exit code 0**

## Risks

- P0: **0**
- P1: **0 open** — `RISK-SPR015-008/009` remediated with executable RED→GREEN evidence; independent Final Re-Gate pending
- P2: **8**; Turn A in-memory persistence deferral resolved, real connector-read limitation retained

`RISK-SPR012-001` remains remediated: arbitrary callbacks cannot enter the production read boundary, registered module-owned capability state controls execution, and only the fixed GET transport is available.

- `RISK-SPR014-001` (**RESOLVED**): capability now binds Operation/Library/Project/system/object/field/plan/payload/approval and cross-scope probes block.
- `RISK-SPR014-002` (**RESOLVED**): APPLY now rereads and compares current identity, ownership, value/hash, and version before mutation.
- `RISK-SPR014-003` (**RESOLVED**): protected local SQLite operation/audit envelopes survive real process A/B restarts; uncertain states return RECOVERY_REQUIRED and VERIFIED returns ALREADY_COMPLETED.

## External connectivity

- Zotero: **PASS** through the existing read-only SQLite connector against the real local library
- Google Drive: **PASS** for authenticated search, metadata, and raw PDF reads
- Notion: **PASS** for authenticated search, page/schema fetch, and data-source query

Credential values, authorization headers, and temporary signed URLs were not printed into or persisted in repository artifacts. The Zotero desktop local HTTP endpoint was not running, but the real library was available through the read-only SQLite route, so Zotero validation was not deferred.

Real trace summary:

- `LIB:L000003`: Zotero `BCMYA9ZJ` -> Drive `1fJgUzCYIHM4pPo6Lo-SfBGT8mqE4-em9` -> Notion `3e25745c-693d-8120-890f-c4ffd0819b5a` = **MATCHED**
- `LIB:L000001`: two attachment hashes = **AMBIGUOUS**
- `LIB:L000002`: duplicate Zotero bibliographic records = **AMBIGUOUS**
- `Pr1 | Study Review`: readable but 0 rows; project mappings are **MISSING**

## Production safety

**SAFE / WRITE DISABLED.**

- environment and expected environment: `LOCAL`
- `productionReadiness.productionWriteEnabled = false`
- `ProductionReadinessProductionWrite = false`
- Zotero/Drive/Notion/Reconciliation/AI/Synthesis/Output/Workflow production-write capabilities remain disabled
- create/update/delete/move/merge/apply and direct HTTP mutation verbs remain default-denied
- external snapshots cannot overwrite local truth
- Production mutations: Zotero **0** / Drive **0** / Notion **0**

## Remaining limitations

- `L000001` requires human canonical-PDF selection and structured Zotero/Drive linkage backfill.
- `L000002` requires human resolution of duplicate Zotero records; automatic merge is prohibited.
- Drive File ID, PDF URL, Master Row, lifecycle, and Projects fields remain incomplete on inspected Notion rows.
- The project review data source has no rows, so Common Review -> Project mapping is not complete.
- Zotero `attachments:` base-path configuration remains unresolved for direct linked-file existence checks.
- Production Write and reconciliation APPLY remain disabled and unauthorized.
- The production controlled-write pilot remains TEST_DEFERRED; the implemented adapter is sealed and fixture-only.
- Controlled-write operation/audit state is persisted in a local SHA-256-protected SQLite envelope. It has no external trust anchor and does not authorize a production adapter.

## Exact next step

Run a separately commanded independent Final Re-Gate for the Turn F remediation. Do not start a connector read pilot. Production Write remains disabled and Production Pilot remains TEST_DEFERRED.

## SPR-015 architecture and Turn A implementation handoff

The approved future direction is recorded in `docs/adr/ADR-0012-research-intake-architecture.md` and `docs/SPR-015-REQUIREMENTS.md`. It starts from Research Question, uses one Quick/Systematic Research Search Pipeline, holds results as non-canonical Research Inbox candidates, and requires explicit researcher PROMOTE before canonicalization.

The future golden path must perform canonical identity resolution and pre-Zotero deduplication before CREATE/REUSE, use stateful PDF acquisition plus PDF identity verification, preserve discovery lineage, create one Library_ID and one Paper Review per canonical paper, and protect HUMAN_OWNED and ResearcherConfirmed content. AMBIGUOUS, PDF_AMBIGUOUS, and PDF_MISMATCH remain blocked for human review.

Turn A implemented the bounded local/mock path through a non-mutating CREATE/REUSE decision. Turn B added durable restart/retry and bounded read-only lookup contracts. SPR-015R later covers missing/mismatched PDF, cross-system duplicate, partial failure, and lineage-break scenarios.

Unresolved external configuration includes search-source permissions, the authoritative Research Inbox store/schema, researcher PROMOTE identity/provenance, identity evidence thresholds, approved PDF acquisition routes, exact production targets, Project_ID authority, and separately authorized Production Write/recovery procedures.

## Next command

Issue a separate SPR-015 independent Final Re-Gate command. Keep global Production Write disabled and connector/production pilots deferred.

<요약>

1. Turn F remediation은 identity/lookup audit authority를 binding하고 F25/F26을 GREEN으로 전환했다.
2. Turn F 27/27과 remediation 14/14가 통과했지만 별도 Final Re-Gate 전까지 LOCAL/DURABLE CORE COMPLETE=NO이다.
3. Production Write remains disabled and production mutations remain Zotero 0 / Drive 0 / Notion 0.

기록 시각: 2026-09-26 15:11:30 +09:00 (Asia/Seoul)
