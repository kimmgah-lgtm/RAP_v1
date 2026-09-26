# SPR-015 Turn D Remediation Report

> 문서 경로: `outputs/SPR-015-TURN-D-REMEDIATION-REPORT.md`
> 기록일: 2026-09-26 (Asia/Seoul)

## Result

**SPR-015 TURN D REMEDIATION = PASS**

**SPR-015 LOCAL/DURABLE CORE COMPLETE = NO**

**READY FOR CONNECTOR READ PILOT = NO**

이 결과는 remediation 완료이며 독립 Final Re-Gate PASS 선언이 아니다. Production Write는 **DISABLED**, Production Pilot과 Real Zotero lookup은 **TEST_DEFERRED**를 유지한다.

## Baseline and environment

- Branch: `ASS_v1`
- Remediation baseline: `bf5db9f36c99c894b63cf00e03031c67f7c37032`
- Initial local HEAD = `origin/ASS_v1`; working tree clean
- OS/runtime: Windows, PowerShell 7
- Turn D original result: 15/19 PASS, P0=0, open P1=3
- Scope: `RISK-SPR015-005`, `RISK-SPR015-006`, `RISK-SPR015-007` only

## RED reproduction and root cause

| Risk | RED evidence | Root cause |
|---|---|---|
| RISK-SPR015-005 | D15/D17 FAIL | Cached decision returned before comparison with the current lookup execution and evidence |
| RISK-SPR015-006 | D18 FAIL | Generic persistence envelope protected bytes but no decision-semantic binding existed |
| RISK-SPR015-007 | D19 FAIL | No durable event proved that exact promotion lineage was revalidated immediately before decision |

## Remediation

- Persistence advanced from schema v2 to v3; legacy schema continuation fails closed.
- Added a distinct, versioned `DecisionBindingHash` covering DecisionId, ProjectId, ResearchQuestionId, SearchExecutionId, CandidateId, PromotionHash, candidate identity, resolved identity evidence, canonical key, lookup execution/evidence, statuses/counts, decision, reason, state, revalidation proof, decision time, and safety state.
- Cached reuse now recomputes current identity and lookup evidence hashes. Exact same evidence permits idempotent reuse; changed, missing, substituted, or semantically forged evidence returns `BLOCKED`.
- Added durable `PROMOTION_LINEAGE_REVALIDATED` audit evidence immediately before decision. The decision binds its sequence and evidence hash, and replay verifies that this event precedes the matching decision audit.
- Audit proof missing, late, wrong-candidate, or inconsistent fails closed. Audit write failure cannot create a decision or increment CREATE authority.
- The official full runner now includes the Turn D final probes and remediation probes.

## Verification results

| Suite | Result |
|---|---:|
| Turn D remediation probes RD01-RD12 | 12/12 PASS |
| Turn D original probes D01-D19 | 19/19 PASS |
| Turn C remediation | 19/19 PASS |
| Turn C independent probes | 13/13 PASS |
| Turn B restart / lookup / identity | 10/10, 10/10, 12/12 PASS |
| Turn A contract / zero-duplicate / Inbox / adversarial | 10/10, 10/10, 8/8, 13/13 PASS |
| SPR-014 controlled write | CW01-CW20 PASS |
| SPR-014 remediation / Gate | R01-R18, G01-G14 PASS |
| SPR-013 | 21 assertions PASS |
| SPR-012 | focused 16/16, adversarial 17/17, capability boundary 7/7 PASS |
| Full safe RAP regression | PASS; exit code 0 |

## Semantic and adversarial disposition

- Decision evidence immutability: **PASS**
- Decision/evidence binding: **PASS**
- Replay safety and same-evidence idempotency: **PASS**
- No authority laundering through a fresh envelope: **PASS**
- Pre-decision revalidation audit proof: **PASS**
- Audit failure fail-closed: **PASS**
- Restart plus changed evidence: **PASS**
- Cross-candidate and cross-project substitution: **PASS**

## Risk and safety state

- P0: **0**
- Open P1: **0**
- P2: **8**, unchanged and non-blocking for this remediation
- Secret leakage: **0**
- Zotero production mutation: **0**
- Drive production mutation: **0**
- Notion production mutation: **0**
- Production Write: **DISABLED**
- Production Pilot: **TEST_DEFERRED**
- Real Zotero lookup: **TEST_DEFERRED**

## Known limitations and exact next step

- Semantic binding and audit protection are local SHA-256 evidence without an external trust anchor.
- Real connector normalization and production behavior remain untested and unauthorized.
- Remediation success does not independently establish Final Gate closure.

Next: run a separately commanded independent SPR-015 Final Re-Gate. Do not modify remediation code during that Gate and do not start connector or production pilots.

<요약>

1. 세 P1의 원래 RED를 재현하고 결정-증거 결합, replay 검증, 재검증 감사 증거로 모두 GREEN 전환했다.
2. 독립 12/12, Turn D 19/19, 모든 요구 회귀와 전체 안전 회귀가 통과했으며 open P1은 0이다.
3. 이것은 remediation PASS일 뿐 Final Gate PASS가 아니므로 CORE COMPLETE와 connector pilot readiness는 여전히 NO이다.

기록 시각: 2026-09-26 14:08:40 +09:00
