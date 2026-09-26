# SPR-015 Turn E Remediation Report

> 문서 경로: `outputs/SPR-015-TURN-E-REMEDIATION-REPORT.md`
> 기록일: 2026-09-26 14:43:48 +09:00 (Asia/Seoul)

## Result

**SPR-015 TURN E REMEDIATION = PASS**

**SPR-015 LOCAL/DURABLE CORE COMPLETE = NO**

**READY FOR CONNECTOR READ PILOT = NO**

이 결과는 remediation 완료이며 독립 Final Re-Gate PASS가 아니다. Production Write는 **DISABLED**, Production Pilot과 Real Zotero lookup은 **TEST_DEFERRED**다.

## Baseline and scope

- Branch: `ASS_v1`
- Turn E failure baseline: `50a79df0908aae449a97fe7ad6abf58867b759a7`
- Initial local HEAD = `origin/ASS_v1`; working tree clean
- Scope: `RISK-SPR015-008`, `RISK-SPR015-009` only
- Initial state: P0/P1/P2 = 0/2/8; Turn E probes 20/22 PASS

## RED reproduction and root cause

| Risk | RED evidence | Root cause |
|---|---|---|
| RISK-SPR015-008 | E21: mutated returned identity obtained `CREATE_CANDIDATE` | Public dedup trusted a caller-controlled mutable identity and had no persisted identity-authority binding |
| RISK-SPR015-009 | E22: `ZoteroItemId` substitution survived fresh envelope/restart | Exact REUSE target was omitted from `DecisionBindingHash` and decision audit |

## Remediation

### Canonical identity authority

- Added versioned `IdentityBindingHash` binding Project, Research Question, SearchExecutionId, Candidate, PromotionHash, candidate snapshot hash, observed and normalized identifiers, metadata, resolution method/outcome, canonical key, evidence, provenance, and resolution time.
- Public dedup now reloads and verifies the persisted identity authority and compares it with the caller artifact. Caller mutation, cross-candidate/project use, normalized DOI/PMID change, and stale source evidence fail closed.
- Identity resolution returns a detached copy rather than the store-owned mutable object. Same-evidence replay reuses the sealed identity idempotently.

### Exact REUSE target authority

- Decision binding version 2 now includes `IdentityBindingHash`, canonical target identity, exact `ZoteroItemId`, Zotero library context, and `ExactTargetEvidenceHash` over the matched canonical/Zotero records.
- Decision audit records the same exact-target fields and audit-proof validation compares them with the persisted decision.
- Target, library, canonical target, candidate, project, replay, and fresh-envelope substitutions fail closed.

### Persistence

- Research Intake persistence advanced to schema v4 because schema v3 cannot express the required identity and exact-target authority evidence.
- v1/v2/v3 records cannot automatically acquire v4 authority; unsupported legacy state fails closed.

## Verification results

| Suite | Result |
|---|---:|
| Turn E remediation ER01-ER12 | 12/12 PASS |
| Turn E original E01-E22 | 22/22 PASS |
| Turn D remediation / probes | 12/12, 19/19 PASS |
| Turn C remediation / probes | 19/19, 13/13 PASS |
| Turn B RS / LU / ID | 10/10, 10/10, 12/12 PASS |
| Turn A Contract / Zero-Duplicate / Inbox / Adversarial | 10/10, 10/10, 8/8, 13/13 PASS |
| SPR-014 CW / R / Gate | 20/20, 18/18, 14/14 PASS |
| SPR-013 | 21 assertions PASS |
| SPR-012 | focused 16/16, adversarial 17/17, capability boundary 7/7 PASS |
| Full safe RAP regression | PASS; exit code 0 |

## Semantic review

- Identity authority binding: **PASS**
- Identity substitution resistance: **PASS**
- CREATE authority completeness: **PASS**
- Exact REUSE target binding: **PASS**
- REUSE target substitution resistance: **PASS**
- DecisionBindingHash semantic completeness: **PASS**
- Exact-target audit reconstruction: **PASS**
- Restart/replay and same-evidence idempotency: **PASS**
- Legacy automatic authority upgrade: **BLOCKED / PASS**
- Historical `RISK-SPR015-003` through `007` closure: **PRESERVED**

## Safety state

- P0: **0**
- Open P1: **0**
- P2: **8**, unchanged
- New P1 discovered: **0**
- Secret leakage: **0**
- Zotero production mutation: **0**
- Drive production mutation: **0**
- Notion production mutation: **0**
- Production Write: **DISABLED**
- Production Pilot: **TEST_DEFERRED**
- Real Zotero lookup: **TEST_DEFERRED**

## Required next step

Run a separately commanded independent Final Re-Gate. Until it passes, keep `SPR-015 LOCAL/DURABLE CORE COMPLETE=NO` and `READY FOR CONNECTOR READ PILOT=NO`. Do not start connector or production pilots.

<요약>

1. Identity authority와 exact REUSE target을 독립 semantic binding과 audit evidence로 봉인했다.
2. Turn E 22/22, remediation 12/12, 모든 이전 suite와 전체 안전 회귀가 통과하여 open P1은 0이다.
3. Remediation PASS는 Final Gate PASS가 아니므로 core 완료와 connector pilot readiness는 아직 NO이다.

기록 시각: 2026-09-26 14:43:48 +09:00 (Asia/Seoul)
