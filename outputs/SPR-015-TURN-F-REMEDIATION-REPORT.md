# SPR-015 Turn F Remediation Report

> 문서 경로: `outputs/SPR-015-TURN-F-REMEDIATION-REPORT.md`
> 기록일: 2026-09-26 15:11:30 +09:00 (Asia/Seoul)

## Result

**SPR-015 TURN F REMEDIATION = PASS**

**RISK-SPR015-010 = CLOSED PENDING INDEPENDENT FINAL RE-GATE**

**SPR-015 LOCAL/DURABLE CORE COMPLETE = NO**

**READY FOR CONNECTOR READ PILOT = NO**

Production Write는 **DISABLED**, Production Pilot과 Real Zotero lookup은 **TEST_DEFERRED**다. Connector Read Pilot은 시작하지 않았다.

## Baseline and scope

- Branch: `ASS_v1`
- Failed Turn F baseline: `b5d402b6cf4253451302705d87a5b19747b67e50`
- Initial local HEAD = refreshed `origin/ASS_v1`; working tree clean
- Scope: `RISK-SPR015-010` only
- Initial P0/P1/P2: 0/1/8
- Original Turn F result: 25/27 PASS; F25/F26 FAIL

## RED reproduction

Before remediation, the unchanged Turn F probes reproduced:

- F25: replacing the semantic type of `IDENTITY_RESOLVED` while preserving audit sequence still allowed cached CREATE replay.
- F26: replacing the semantic type of `READ_ONLY_LOOKUP_EXECUTED` while preserving audit sequence still allowed cached CREATE replay.
- Root cause: replay validated only revalidation and final decision audits; upstream identity and lookup audit authority was not referenced by `DecisionBindingHash` or revalidated semantically.

## Remediation

### Upstream identity and lookup audit authority

- Identity audit now binds Project, Research Question, SearchExecution, Candidate, PromotionHash, identity authority, normalized identifiers, canonical key, and `IdentityBindingHash` in a semantic evidence hash.
- Raw read-only lookup execution now carries a semantic evidence hash over execution identity, result, reason, canonical/Zotero authority state, counts, read-only state, and disabled production-write state.
- Candidate-scoped `CANONICAL_LOOKUP_AUTHORITY_VALIDATED` and `ZOTERO_LOOKUP_AUTHORITY_VALIDATED` events bind the decision subject, identity authority, lookup execution/evidence, outcome/counts, and exact target fields for REUSE.
- A truthful `READ_ONLY_LOOKUP_NOT_EXECUTED` event represents the default LOOKUP_REQUIRED path; it cannot become NOT_FOUND or CREATE authority.

### Replay validation

- Decision binding version advanced from 2 to 3 and binds identity, raw lookup, canonical lookup and Zotero lookup audit sequence/evidence hashes.
- Replay reloads each exact event and recomputes the semantic hash from the event's actual Data rather than trusting its stored hash string.
- Event type, subject, identity, outcome, exact target and ordering are checked. Missing, duplicated, contradictory, cross-candidate/project, altered, reordered or re-enveloped upstream audit evidence fails closed.
- Valid cached replay no longer writes a new revalidation event before verification, preserving deterministic idempotency.

### Ordering and persistence

- Raw read-only lookup execution may precede candidate identity resolution because it is a bounded registry read.
- Candidate-scoped canonical/Zotero authority validation must follow identity authority and precede lineage revalidation and the decision audit.
- Durable store schema remains **v4** because it safely represents the additional decision fields. No unnecessary schema bump was made.
- Older v4 decisions without the mandatory binding fields fail closed; authority is not inferred or upgraded.

## RED → GREEN evidence

| Evidence | Before | After |
|---|---:|---:|
| F25 identity audit semantic omission | FAIL | PASS |
| F26 lookup audit semantic omission | FAIL | PASS |
| Turn F probes F01-F27 | 25/27 | **27/27 PASS** |
| Expanded remediation FR01-FR14 | not present | **14/14 PASS** |

## Expanded adversarial coverage

- Wrong Candidate, Project, identity binding and lookup identity
- Canonical outcome contradiction
- Zotero Candidate and exact target substitution
- Missing identity/canonical audit
- Duplicate/conflicting audit chain
- Upstream audit failure during replay
- Restart plus fresh-envelope upstream audit substitution
- Forged upstream ordering/reference
- CREATE and REUSE paths

All fail closed.

## Required regression

| Suite | Result |
|---|---:|
| Turn F remediation | 14/14 PASS |
| Turn F independent probes | 27/27 PASS |
| Turn E remediation / probes | 12/12, 22/22 PASS |
| Turn D remediation / probes | 12/12, 19/19 PASS |
| Turn C remediation / probes | 19/19, 13/13 PASS |
| Turn B restart / lookup / identity | 10/10, 10/10, 12/12 PASS |
| Turn A contract / zero-duplicate / Inbox / adversarial | 10/10, 10/10, 8/8, 13/13 PASS |
| SPR-014 CW / remediation / Gate | 20/20, 18/18, 14/14 PASS |
| SPR-013 | 21 assertions PASS |
| SPR-012 focused / adversarial / credential / capability | 16/16, 17/17, 2/2, 7/7 PASS |
| Full safe RAP regression | PASS; exit code 0 |

## Semantic review

- Upstream identity audit authority: **PASS**
- Canonical lookup audit authority: **PASS**
- Zotero lookup audit authority: **PASS**
- CREATE absence audit chain: **PASS**
- REUSE exact-target audit chain: **PASS**
- Audit omission/substitution/contradiction: **FAIL-CLOSED / PASS**
- Audit ordering: **PASS**
- Replay/restart/fresh-envelope validation: **PASS**
- DecisionBindingHash completeness: **PASS**
- Historical `RISK-SPR015-003` through `009`: **PRESERVED**
- New P0/P1 discovered: **0**

## Safety state

- P0: **0**
- Open P1: **0**
- P2: **8**, unchanged
- Secret leakage: **0**
- Zotero production mutation: **0**
- Drive production mutation: **0**
- Notion production mutation: **0**
- Production Write: **DISABLED**
- Production Pilot: **TEST_DEFERRED**
- Real Zotero lookup: **TEST_DEFERRED**

## Required next step

Run a separately commanded independent Final Re-Gate. Until it passes, keep `SPR-015 LOCAL/DURABLE CORE COMPLETE=NO` and `READY FOR CONNECTOR READ PILOT=NO`. Do not start the connector or production pilot.

<요약>

1. Identity와 canonical/Zotero lookup audit authority를 decision binding과 replay 검증에 결합했다.
2. 원본 F25/F26, Turn F 27/27, remediation 14/14와 전체 안전 회귀가 모두 통과했다.
3. Remediation PASS는 Final Gate PASS가 아니므로 COMPLETE와 connector readiness는 계속 NO이다.

기록 시각: 2026-09-26 15:11:30 +09:00 (Asia/Seoul)
