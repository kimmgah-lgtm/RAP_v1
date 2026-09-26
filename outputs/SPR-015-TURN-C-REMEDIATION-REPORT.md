# SPR-015 Turn C Remediation Report

> 문서 경로: `outputs/SPR-015-TURN-C-REMEDIATION-REPORT.md`
> 기록일: 2026-09-26 (Asia/Seoul)

## Result

**SPR-015 TURN C REMEDIATION = PASS**

**P1 REMEDIATION EVIDENCE = READY**

**SPR-015 CORE COMPLETE = NO**

**READY FOR CONNECTOR READ PILOT = NO**

Turn C Final Gate의 FAIL 판정은 이 remediation으로 소급 변경하지 않는다. 별도 SPR-015 Turn D Independent Final Re-Gate가 필요하다.

## Baseline and precondition

- Branch: `ASS_v1`
- Failed Gate baseline: `8b5cd87ccd38b9ae11eca2c824f9bf5ddcc49d16`
- Initial local HEAD = `origin/ASS_v1`; working tree clean
- Original Gate state: P0=0, P1=2, P2=8
- Scope: `RISK-SPR015-003`, `RISK-SPR015-004` root-cause remediation only

## Original RED evidence

The unchanged Turn C probes were rerun before the fix:

- GC09 FAIL: TIMEOUT lookup could be ignored and converted to `CREATE_CANDIDATE`.
- GC10 FAIL: PARTIAL lookup could be ignored and converted to `CREATE_CANDIDATE`.
- GC13 FAIL: post-PROMOTE `SearchExecutionId` substitution was accepted.
- Result: **10/13 PASS, exit code 1**.

## P1-A — authoritative lookup fail-closed

- A persisted `LookupSnapshot` now records status, reason, execution identity, timestamp, counts, read-only state, and production-write state.
- `PASS` is the only authoritative lookup execution state. A new/default store starts as `LOOKUP_REQUIRED`; failure and uncertainty persist as `LOOKUP_FAILED` plus `UNKNOWN` canonical/Zotero state.
- Candidate-specific dedup evidence records canonical identity, `NOT_FOUND` / `FOUND` / `MULTIPLE` / `UNKNOWN`, lookup execution identity, timestamp, reason, and counts.
- `CREATE_CANDIDATE` requires resolved identity and authoritative `NOT_FOUND` for both canonical and Zotero lookup.
- TIMEOUT, PARTIAL, MALFORMED, AUTH_FAILURE, PERMISSION_AMBIGUITY, UNKNOWN, and MULTIPLE outcomes cannot fall through to CREATE.
- TIMEOUT/PARTIAL/UNKNOWN remain blocked after restart.

## P1-B — promotion lineage immutability

- PROMOTE now binds Project_ID, Research_Question_ID, SearchExecutionId, search mode/source/provenance, Candidate_ID, full candidate identity snapshot hash, researcher, promotion provenance, and normalized promotion timestamp.
- Identity and dedup entry points revalidate the persisted promotion hash and the current candidate lineage before advancement.
- Project, question, search execution, candidate, DOI, PMID, and metadata substitutions fail closed.
- The binding survives restart; a substituted SearchExecutionId remains blocked even after the changed envelope is saved with a valid generic persistence hash.

## Persistence and schema

- Research Intake persistence schema advanced from v1 to v2 to require `LookupSnapshot` and expanded promotion binding fields.
- v1/legacy state is not silently trusted or inferred; it fails closed with `RESEARCH_INTAKE_SCHEMA_UNSUPPORTED`.
- ISO timestamps are loaded as strings to preserve hash-stable precision and timezone semantics.
- Existing SHA-256 envelope integrity remains enabled and is complemented by semantic promotion-binding revalidation.

## RED → GREEN evidence

| Evidence | Before | After |
|---|---:|---:|
| REM-P1A-01 / GC09 TIMEOUT bypass | RED | GREEN |
| REM-P1A-02 / GC10 PARTIAL bypass | RED | GREEN |
| REM-P1B-01 / GC13 search lineage substitution | RED | GREEN |
| Expanded remediation assertions | not present | **19/19 PASS** |
| Turn C independent probes | 10/13 | **13/13 PASS** |

## Regression

| Suite | Result |
|---|---:|
| Turn B RS01-RS10 | 10/10 PASS |
| Turn B LU01-LU10 | 10/10 PASS |
| Turn B ID01-ID12 | 12/12 PASS |
| Turn A Contract CT01-CT10 | 10/10 PASS |
| Turn A Zero-Duplicate ZD01-ZD10 | 10/10 PASS |
| Turn A Research Inbox RI01-RI08 | 8/8 PASS |
| Turn A Adversarial AD01-AD13 | 13/13 PASS |
| SPR-014 CW01-CW20 | 20/20 PASS |
| SPR-014 R01-R18 | 18/18 PASS |
| SPR-014 independent probes | 14/14 PASS |
| SPR-013 | 21 assertions PASS |
| SPR-012 safety/credential/boundary | PASS; secret leakage 0 |
| Official full safe RAP regression | PASS; exit code 0 |

## Safety and disposition

- P0: **0**
- Open P1 after remediation: **0**
- P2: **8**, unchanged and non-blocking for remediation
- New P1 discovered: **0**
- Secret leakage: **0**
- Zotero/Drive/Notion production mutation: **0/0/0**
- Production Write: **DISABLED**
- Production Pilot: **TEST_DEFERRED**
- Real Zotero lookup: **TEST_DEFERRED**

## Remaining limitations and next step

- This is local/fixture remediation evidence, not production or connector-read authorization.
- Local SHA-256 persistence has no external trust anchor; the existing P2 remains open.
- Run a separately commanded **SPR-015 Turn D Independent Final Re-Gate**.
- Until Turn D passes, keep `SPR-015 CORE COMPLETE=NO` and `READY FOR CONNECTOR READ PILOT=NO`.

<요약>

1. 두 P1의 원래 RED 재현이 동일 프로브에서 GREEN으로 전환되었다.
2. 확장 19/19, Turn C 13/13, Turn A/B 및 전체 안전 회귀가 모두 통과했다.
3. remediation은 PASS지만 Final Gate PASS가 아니므로 Turn D 재검증 전에는 core 완료나 pilot 준비를 선언하지 않는다.

기록 시각: 2026-09-26 (Asia/Seoul)
