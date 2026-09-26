# SPR-015 Turn G Remediation Report

> 문서 경로: `outputs/SPR-015-TURN-G-REMEDIATION-REPORT.md`
> 기록일: 2026-09-26 15:51:34 +09:00 (Asia/Seoul)

## Final result

**SPR-015 TURN G REMEDIATION = PASS**

**RISK-SPR015-011 = RED → GREEN; CLOSED PENDING INDEPENDENT FINAL RE-GATE**

**SPR-015 LOCAL/DURABLE CORE COMPLETE = NO**

**READY FOR CONNECTOR READ PILOT = NO**

## Baseline and scope

- Branch: `ASS_v1`
- Baseline: `bcf81378083d9225e4199b0fb9535f7d037a5d67`
- Initial local HEAD = refreshed `origin/ASS_v1`; working tree clean
- Environment: Windows / PowerShell 7 / LOCAL+FIXTURE
- Remediation scope: `RISK-SPR015-011` only
- Architecture preservation: `docs/adr/ADR-0013-research-lineage-branching-and-synthesis-architecture.md`
- SPR-016 implementation: **NOT STARTED**

## Root cause and RED reproduction

`CANDIDATE_PROMOTED` existed as a log event but its sequence and semantic evidence were absent from decision binding and replay proof. `Test-RapDecisionAuditProof` began at identity audit authority. On the unchanged baseline:

| RED probe | Baseline result |
|---|---:|
| G31: rename/remove authoritative `CANDIDATE_PROMOTED` event | **FAIL — replay accepted** |
| G32: sequence promotion audit after decision | **FAIL — replay accepted** |

Turn G Final Re-Gate recorded 30/32 PASS and registered `RISK-SPR015-011` as P1.

## Remediation

- Added one canonical promotion-audit evidence projection over Project, Research Question, Search Execution, Candidate, candidate identity hash, researcher, provenance, promoted time and `PromotionHash`.
- Persisted `PromotionAuditSequence` and `PromotionAuditEvidenceHash` in decision authority and advanced decision binding from v3 to **v4**. Durable store schema remains **v4**.
- Bound the same promotion-audit reference into `PRE_ZOTERO_DEDUP_DECIDED` audit evidence.
- Replay now requires exactly one authoritative `CANDIDATE_PROMOTED` event, recomputes semantic evidence from persisted promotion and actual audit Data, and verifies sequence/reference/hash equality.
- Enforced stable ordering `CANDIDATE_PROMOTED < IDENTITY_RESOLVED < decision-scoped canonical/Zotero authority < PROMOTION_LINEAGE_REVALIDATED < PRE_ZOTERO_DEDUP_DECIDED`.
- Missing, substituted, conflicting, duplicated or late promotion authority fails closed. Normal repeated PROMOTE remains idempotent and creates no duplicate audit event.

Raw read-only connector evidence may be prefetched before PROMOTE, but it gains no decision authority until the post-identity, decision-scoped lookup-audit chain is validated.

## GREEN evidence

| Evidence | Result |
|---|---:|
| GR01-GR14 remediation probes | **14/14 PASS** |
| Promotion audit presence | PASS |
| Semantic subject/binding | PASS |
| Stable ordering | PASS |
| Uniqueness/conflict handling | PASS |
| Restart/replay validation | PASS |
| Original Turn G G01-G32 | **32/32 PASS** |

GR01-GR10 cover every requested missing, late, wrong Candidate/Project/Search Execution, binding mismatch, conflicting event, idempotent replay and restart/reorder case. GR11-GR14 additionally cover evidence-hash substitution, decision reference substitution, decision-audit omission and valid restart replay.

## Full regression

The official `tools/Invoke-Tests.ps1` runner completed with **exit code 0**.

| Suite | Result |
|---|---:|
| Turn F remediation / independent | 14/14, 27/27 PASS |
| Turn E remediation / independent | 12/12, 22/22 PASS |
| Turn D remediation / independent | 12/12, 19/19 PASS |
| Turn C remediation / independent | 19/19, 13/13 PASS |
| Turn B restart / lookup / identity | 10/10, 10/10, 12/12 PASS |
| Turn A contract / dedup / Inbox / adversarial | 10/10, 10/10, 8/8, 13/13 PASS |
| SPR-014 CW / remediation / Gate | 20/20, 18/18, 14/14 PASS |
| SPR-013 | 21 assertions PASS |
| SPR-012 focused / adversarial / credential / boundary | 16/16, 17/17, 2/2, 7/7 PASS |
| Full safe RAP regression | **PASS** |

Historical `RISK-SPR015-003` through `RISK-SPR015-010` remain closed. No new P0/P1 was found.

## Safety state

- P0: **0**
- Open P1: **0**
- P2: **8**
- Secret leakage: **0**
- Zotero production mutation: **0**
- Drive production mutation: **0**
- Notion production mutation: **0**
- Production Write: **DISABLED**
- Production Pilot: **TEST_DEFERRED**
- Real Zotero lookup: **TEST_DEFERRED**

## Architecture preservation and handoff

ADR-0013 records the no-overwrite principle, versioned Research Questions, exploratory-to-systematic continuity, reverse traceability, corpus/analysis/finding/conclusion separation, first-class branching, higher-order synthesis, evidence-type extension points, SPR-015's intake-infrastructure position and SPR-016's provisional discovery/question-formation direction.

The handoff remains two-track:

- Safety: Turn G remediation → separate Independent Final Re-Gate → only then Local/Durable Core closure.
- Research: SPR-016 non-canonical topic/problem exploration, background research, search, Inbox and local reasoning may proceed. No SPR-016 feature was implemented here.

## Required next step

Run a separately commanded SPR-015 Independent Final Re-Gate. This remediation does not close SPR-015 and does not authorize the Connector Read Pilot or Production Write.

<요약>

1. RISK-SPR015-011은 promotion audit authority binding v4로 RED→GREEN 전환됐다.
2. GR01-GR14 14/14, Turn G 32/32 및 전체 안전 회귀가 통과했다.
3. 별도 Independent Re-Gate 전까지 CORE COMPLETE=NO, connector readiness=NO이다.

기록 시각: 2026-09-26 15:51:34 +09:00 (Asia/Seoul)
