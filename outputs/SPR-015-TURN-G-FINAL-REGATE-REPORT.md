# SPR-015 Turn G Independent Final Re-Gate Report

> 문서 경로: `outputs/SPR-015-TURN-G-FINAL-REGATE-REPORT.md`
> 기록일: 2026-09-26 15:20:41 +09:00 (Asia/Seoul)

## Final result

**SPR-015 TURN G INDEPENDENT FINAL RE-GATE = FAIL**

**SPR-015 LOCAL/DURABLE CORE COMPLETE = NO**

**READY FOR CONNECTOR READ PILOT = NO**

Turn G에서 제품 remediation, connector pilot, Production Write는 수행하지 않았다. Production Write는 **DISABLED**, Production Pilot과 Real Zotero lookup은 **TEST_DEFERRED**다.

## Repository and prerequisite

- Branch: `ASS_v1`
- Baseline HEAD: `7adeab785291261c38ddeac2df14ace10a72c06a`
- Baseline commit: `fix: bind SPR-015 upstream audit authority`
- Initial local HEAD = refreshed `origin/ASS_v1`; working tree clean
- Environment: Windows / PowerShell 7 / LOCAL+FIXTURE
- Turn F remediation prerequisite: **PASS**; FR01-FR14 14/14 and F01-F27 27/27
- Durable schema: **v4**; decision binding: **v3**

Prior reports were prerequisite context only. All executable results below were rerun independently in Turn G.

## Independent semantic review

Research Question → Search Execution → Candidate → PROMOTE → identity → canonical/Zotero lookup → revalidation → CREATE/REUSE decision is strongly bound against candidate, project, identity, DOI/PMID, lookup outcome, target, decision-type, stale-envelope, cross-scope, restart, legacy-schema, and combined substitution attacks.

However, replay does not require the original `CANDIDATE_PROMOTED` audit event to exist with its authoritative semantics or to precede identity and decision. Promotion binding data inside later artifacts is not equivalent to independently verifiable promotion audit provenance. Therefore the complete PROMOTE → IDENTITY → LOOKUP → DECISION audit order is not proven.

## Turn G independent probes

**30 PASS / 2 FAIL / 32 total; exit code 1**

| Probe scope | Result | Evidence |
|---|---:|---|
| G01-G30 | 30/30 PASS | Promotion object/search/candidate, identity, lookup uncertainty, post-decision mutation, exact target, decision type, laundering, audit substitution/omission/contradiction, restart, legacy and combined attacks fail closed |
| G31 | **FAIL** | Rename `CANDIDATE_PROMOTED` to a non-authoritative event; unchanged persisted decision still replays |
| G32 | **FAIL** | Move promotion audit sequence after the decision; unchanged persisted decision still replays |

## New P1 blocker

### RISK-SPR015-011 — Promotion audit authority is omitted from decision replay

- Severity: **P1 / Gate blocking**
- Affected invariant: replay must prove one authoritative `CANDIDATE_PROMOTED` event for the exact project/question/search/candidate/promotion binding and require `PROMOTE < IDENTITY < LOOKUP < REVALIDATION < DECISION` ordering.
- Reproduction: create a valid decision, then either rename the promotion audit event or move its sequence after the decision. Invoke the public decision path with otherwise unchanged evidence. Replay returns the cached decision instead of blocking.
- Root cause: `Test-RapDecisionAuditProof` validates identity, lookup, revalidation and decision audits but does not validate the promotion audit event or its position in the authority chain.
- Impact: durable provenance cannot prove that canonicalization/dedup began from an explicit, correctly scoped researcher promotion before identity resolution.
- Recommended remediation: bind the unique promotion audit sequence and semantic evidence hash into decision binding; recompute and verify exact event type, project/question/search/candidate, promotion hash, uniqueness and ordering before identity. Missing, contradictory, substituted or late promotion evidence must fail closed.

Turn G did not remediate this blocker.

## Historical P1 regression review

| Risks | Turn G evidence | Result |
|---|---|---:|
| RISK-SPR015-003/004 | Lookup fail-closed and promotion lineage substitutions blocked | PASS |
| RISK-SPR015-005/006/007 | Stale decision, envelope laundering and revalidation proof attacks blocked | PASS |
| RISK-SPR015-008/009 | Identity authority and exact REUSE target substitutions blocked | PASS |
| RISK-SPR015-010 | Identity/raw/scoped lookup audit omission and substitution blocked; F/FR suites pass | PASS |

`RISK-SPR015-011` is distinct: it concerns the authority and ordering of the original promotion audit, upstream of the already-bound identity and lookup audit chain.

## Required test execution

| Suite | Turn G result |
|---|---:|
| Turn G independent probes | **30/32 PASS; G31/G32 FAIL** |
| Turn F remediation / probes | 14/14, 27/27 PASS |
| Turn E remediation / probes | 12/12, 22/22 PASS |
| Turn D remediation / probes | 12/12, 19/19 PASS |
| Turn C remediation / probes | 19/19, 13/13 PASS |
| Turn B restart / lookup / identity | 10/10, 10/10, 12/12 PASS |
| Turn A contract / zero-duplicate / Inbox / adversarial | 10/10, 10/10, 8/8, 13/13 PASS |
| SPR-014 CW / remediation / Gate | 20/20, 18/18, 14/14 PASS |
| SPR-013 | 21 assertions PASS |
| SPR-012 focused / adversarial / credential / capability | 16/16, 17/17, 2/2, 7/7 PASS |
| Full safe RAP regression | **PASS; exit code 0** |

## Gate and safety disposition

| Item | Result |
|---|---:|
| End-to-end decision authority | **FAIL — promotion audit authority/order omitted** |
| Capability/identity/lookup/target binding | PASS |
| APPLY-time revalidation and ownership firewall regressions | PASS |
| Durable persistence, integrity, idempotency, restart/recovery | PASS for bound evidence |
| Read-back verification and alternate paths | PASS |
| Audit/provenance | **FAIL — G31/G32** |
| Legacy schema automatic authority | BLOCKED / PASS |
| Zero-duplicate semantic Gate | **FAIL** |

## P2 review

The eight existing P2 items remain correctly classified and non-blocking: `RISK-BASELINE-001`, `RISK-SPR011-007/008/009/011`, `RISK-SPR0115-001/002`, and `RISK-SPR015-002`. None is resolved, duplicated, superseded, or promoted by Turn G.

## Safety state

- P0: **0**
- Open P1: **1**
- P2: **8**
- Semantic blockers: **1**
- Secret leakage: **0**
- Zotero production mutation: **0**
- Drive production mutation: **0**
- Notion production mutation: **0**
- Production Write: **DISABLED**
- Production Pilot: **TEST_DEFERRED**
- Real Zotero lookup: **TEST_DEFERRED**

## Known limitations and next step

This Gate remains LOCAL+FIXTURE only. Live connector normalization, external trust anchoring and production pilots remain deferred. Run a separately commanded **SPR-015 Turn G Remediation** for `RISK-SPR015-011`, preserving G31/G32 as RED→GREEN evidence and rerunning the full safe regression. Do not start the Connector Read Pilot or enable Production Write.

<요약>

1. 기존 Turn F remediation과 모든 공식 안전 회귀는 통과했다.
2. 32개 독립 공격 중 G31/G32가 promotion audit의 누락·후행을 허용해 새 P1 한 건을 확인했다.
3. Turn G는 FAIL이며 CORE COMPLETE=NO, connector pilot readiness=NO이다.

기록 시각: 2026-09-26 15:20:41 +09:00 (Asia/Seoul)
