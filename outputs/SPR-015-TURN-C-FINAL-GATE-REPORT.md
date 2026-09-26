# SPR-015 Turn C Independent Final Gate Report

> 문서 경로: `outputs/SPR-015-TURN-C-FINAL-GATE-REPORT.md`
> 기록일: 2026-09-26 (Asia/Seoul)

## Final Gate result

**SPR-015 TURN C FINAL GATE = FAIL**

**SPR-015 LOCAL/DURABLE CORE COMPLETE = NO**

**READY FOR CONNECTOR READ PILOT = NO**

Production Write remains **DISABLED**. Production Pilot and real Zotero read-only lookup remain **TEST_DEFERRED / DEFERRED**.

## Repository and prerequisites

- Branch: `ASS_v1`
- Verified baseline HEAD and `origin/ASS_v1`: `3785bcfd99359a9e808e07c550c6da6fb68c1c3f`
- Initial working tree: clean
- Environment: Windows / PowerShell 7.6.5 / LOCAL+FIXTURE only
- Turn A prerequisite: PASS, 41/41
- Turn B prerequisite: PASS, RS 10/10, LU 10/10, ID 12/12
- SPR-014/013/012 and full safe regression prerequisite: PASS

## Independent execution

The official runner was executed in Turn C and exited 0. Turn A 41/41, Turn B 32/32, SPR-014 CW 20/20 + R 18/18 + probes 14/14, SPR-013 21 assertions, SPR-012 safety suites, and the full available regression all passed.

The separate Turn C public-boundary probes produced **10 PASS / 3 FAIL / 13 total**:

- GC09 FAIL — lookup TIMEOUT followed by the public decision API became `CREATE_CANDIDATE`.
- GC10 FAIL — PARTIAL lookup followed by the same bypass became `CREATE_CANDIDATE`.
- GC13 FAIL — promoted candidate `SearchExecutionId` substitution was accepted.

## Semantic review

| Gate | Result |
|---|---:|
| Research Inbox boundary | PASS |
| Candidate/Project/DOI substitution | PASS |
| PROMOTE binding | **FAIL — search lineage omitted** |
| Durable persistence/integrity | PASS |
| Restart/replay and uncertain states | PASS |
| Identity authority/fuzzy firewall | PASS |
| DOI/PMID and metadata conflict | PASS |
| Lookup fail-closed | **FAIL — failure not bound to decision** |
| Dedup execution order | **FAIL — direct decision bypass exists** |
| Audit/provenance continuity | **FAIL for substituted search lineage** |
| Production mutation sentinel | PASS; 0/0/0 |

## P1 blockers

### RISK-SPR015-003 — Lookup failure can become CREATE_CANDIDATE

- Severity: **P1 / Gate blocking**
- Evidence: GC09 and GC10
- Affected invariant: `LOOKUP FAILURE != NOT FOUND != CREATE`
- Reproduction: perform TIMEOUT or PARTIAL lookup, ignore its returned object, then call the public decision API. Empty registries are treated as absent and yield `CREATE_CANDIDATE`.
- Impact: connector failure can recommend duplicate creation.
- Recommended remediation: persist candidate/identity-bound canonical and Zotero lookup status and require explicit successful results before dedup decision; failure/unknown must remain BLOCKED/LOOKUP_FAILED.

### RISK-SPR015-004 — PROMOTE binding omits search execution lineage

- Severity: **P1 / Gate blocking**
- Evidence: GC13
- Affected invariant: PROMOTE binding and durable provenance
- Reproduction: PROMOTE a candidate, replace its `SearchExecutionId`, then run identity/decision. The candidate identity hash excludes search execution and the call succeeds.
- Impact: a promoted paper can be reassigned to another search lineage without detection.
- Recommended remediation: bind SearchExecutionId, search mode/source provenance, and promotion timestamp into the sealed promotion body and revalidate them after reload and before decision.

No remediation was performed in Turn C.

## Risk and safety result

- P0: **0**
- P1: **2 Gate blockers**
- P2: **8 deferred/non-blocking items, re-reviewed**
- Secret leakage: **0**
- Zotero/Drive/Notion mutation: **0/0/0**
- Production Write: **DISABLED**
- Production Pilot: **TEST_DEFERRED**
- Real Zotero read-only lookup: **DEFERRED**

## Required next step

Run a separately commanded **SPR-015 Turn C Remediation** for `RISK-SPR015-003` and `RISK-SPR015-004`, with RED→GREEN probes and full regression. Do not start a connector read pilot or enable production writes.

<요약>

1. 기존 suite는 PASS했지만 독립 probes에서 lookup-failure bypass와 search-lineage substitution이 재현되었다.
2. P1 2건으로 Final Gate는 FAIL이며 SPR-015 durable core는 아직 완료가 아니다.
3. Production mutation은 0건이며 별도 remediation Turn이 필요하다.

기록 시각: 2026-09-26 (Asia/Seoul)
