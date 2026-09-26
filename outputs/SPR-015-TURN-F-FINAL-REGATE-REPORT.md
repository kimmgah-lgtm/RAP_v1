# SPR-015 Turn F Independent Final Re-Gate Report

> 문서 경로: `outputs/SPR-015-TURN-F-FINAL-REGATE-REPORT.md`
> 기록일: 2026-09-26 14:52:35 +09:00 (Asia/Seoul)

## Final result

**SPR-015 TURN F INDEPENDENT FINAL RE-GATE = FAIL**

**SPR-015 LOCAL/DURABLE CORE COMPLETE = NO**

**READY FOR CONNECTOR READ PILOT = NO**

Turn F에서 제품 remediation과 connector pilot은 수행하지 않았다. Production Write는 **DISABLED**, Production Pilot과 Real Zotero lookup은 **TEST_DEFERRED**다.

## Repository and prerequisite

- Branch: `ASS_v1`
- Full baseline HEAD: `8292dd5a0ca3e0b500fd11315fbb8a1f2d38b77c`
- Baseline lineage includes `8292dd5 fix: close SPR-015 Turn E P1 remediation`
- Initial local HEAD = refreshed `origin/ASS_v1`; working tree clean
- Environment: Windows / PowerShell 7 / LOCAL+FIXTURE
- Turn E remediation prerequisite: PASS; ER01-ER12 12/12 and E01-E22 22/22
- The repository uses `outputs/SPR-015-TURN-D-FINAL-REGATE-REPORT.md`; this is the naming-convention equivalent of the requested `FINAL-RE-GATE` path.

Prior report counts were used only as prerequisite context. Every executable result below was rerun in Turn F.

## Independent end-to-end authority review

The Research Question → Search Execution → Candidate → PROMOTE → Promotion Binding → Identity Authority → canonical/Zotero lookup → lineage revalidation → exact absence/target evidence → Decision Binding → durable persistence chain is consistently bound for identity, lookup state, decision type, exact REUSE target, restart, and generic persistence-envelope attacks.

CREATE requires sealed promotion and identity authority, authoritative canonical/Zotero `NOT_FOUND`, no ambiguity/conflict, current lookup evidence, pre-decision revalidation, and valid decision/audit binding. REUSE additionally binds canonical target, `ZoteroItemId`, library context, and exact matched-record evidence. F01-F24 and F27 confirm those paths fail closed under substitution, replay, restart, laundering, legacy-schema, and combined attacks.

The chain is nevertheless incomplete at the audit-authority layer: replay validates promotion revalidation and the final decision audit, but it does not require the recorded identity-resolution audit or read-only lookup-execution audit to retain their authoritative event semantics.

## Turn F independent probes

**25 PASS / 2 FAIL / 27 total; exit code 1**

| Probe scope | Result | Evidence |
|---|---:|---|
| F01-F24 | 24/24 PASS | Identity/DOI/PMID and cross-scope replay, lookup uncertainty, exact target, decision-type substitution, restart, audit failure, legacy schema, and combined envelope attacks fail closed |
| F25 | **FAIL** | Rename/remove the semantic meaning of the persisted `IDENTITY_RESOLVED` audit event while preserving sequence; the existing CREATE decision remains authoritative on replay |
| F26 | **FAIL** | Rename/remove the semantic meaning of the persisted `READ_ONLY_LOOKUP_EXECUTED` audit event while preserving sequence; the existing CREATE decision remains authoritative on replay |
| F27 | PASS | Missing exact-target evidence in the REUSE decision audit blocks replay |

## New P1 blocker

### RISK-SPR015-010 — Upstream authority audits are not required by decision replay

- Severity: **P1 / Gate blocking**
- Affected invariant: audit must reconstruct and validate identity resolution and authoritative lookup execution before a persisted CREATE/REUSE decision is reusable.
- Reproduction: create a valid decision, change the identity-resolution or lookup-execution audit event type without changing its sequence, then invoke the public decision path with otherwise unchanged evidence. The cached decision is returned rather than blocked.
- Root cause: `Test-RapDecisionAuditProof` verifies only `PROMOTION_LINEAGE_REVALIDATED` and `PRE_ZOTERO_DEDUP_DECIDED`. Identity and lookup hashes are bound in the decision, but their authoritative audit-event references and semantics are not.
- Impact: durable provenance can no longer prove the full end-to-end authority chain even though decision replay reports authoritative success.
- Recommended remediation: bind identity-resolution and lookup-execution audit sequence/evidence hashes into the decision; verify exact event type, scope, status, ordering, and evidence on replay and after restart. Missing or semantically changed upstream audit evidence must block.

Turn F did not remediate this blocker.

## Historical P1 review

| Risk | Root cause / original attack | Equivalent and alternate paths | Regression evidence | Result |
|---|---|---|---|---:|
| RISK-SPR015-003 | Lookup uncertainty fell through to CREATE | Required/timeout/partial/malformed/auth/multiple paths blocked | F06-F08; C/D/E suites | PASS |
| RISK-SPR015-004 | Promotion omitted search lineage | Candidate/project/search/DOI and restart substitutions blocked | F04-F05, F15-F17; C/D suites | PASS |
| RISK-SPR015-005 | Cached CREATE ignored changed lookup | Changed lookup and restart invalidate replay | F18; D/E suites | PASS |
| RISK-SPR015-006 | Generic envelope laundered decision semantics | Type, scope, stale and combined envelope substitutions blocked | F12-F16, F24 | PASS |
| RISK-SPR015-007 | Pre-decision revalidation lacked durable proof | Missing/wrong/failed revalidation evidence blocked | F20-F22 | PASS |
| RISK-SPR015-008 | Mutable caller identity could redirect CREATE | Identity/DOI/PMID/candidate/project and restart attacks blocked | F01-F05, F17, F24 | PASS |
| RISK-SPR015-009 | REUSE omitted exact target | Item/library/canonical target and restart attacks blocked | F09-F11, F19, F27 | PASS |

The seven historical P1 patches form a coherent semantic binding for promotion, identity, lookup evidence, decision and target. `RISK-SPR015-010` is a distinct remaining end-to-end audit-authority gap.

## Required test execution

| Suite | Turn F result |
|---|---:|
| Turn F independent probes | **25/27 PASS; 2 FAIL** |
| Turn E remediation / probes | 12/12, 22/22 PASS |
| Turn D remediation / probes | 12/12, 19/19 PASS |
| Turn C remediation / probes | 19/19, 13/13 PASS |
| Turn B restart / lookup / identity | 10/10, 10/10, 12/12 PASS |
| Turn A contract / zero-duplicate / Inbox / adversarial | 10/10, 10/10, 8/8, 13/13 PASS |
| SPR-014 CW / remediation / Gate | 20/20, 18/18, 14/14 PASS |
| SPR-013 | 21 assertions PASS |
| SPR-012 focused / adversarial / credential / capability | 16/16, 17/17, 2/2, 7/7 PASS |
| Full safe RAP regression | PASS; exit code 0 |

## Semantic Gate disposition

| Gate | Result |
|---|---:|
| End-to-end authority chain | **FAIL — upstream audit authority not mandatory on replay** |
| CREATE authority | PASS for bound identity/absence/decision semantics; **FAIL for complete audit authority** |
| REUSE authority and exact target | PASS |
| Identity authority | PASS |
| Lookup authority / uncertainty fail-closed | PASS |
| Decision binding and decision-type substitution resistance | PASS |
| Persistence integrity / schema v4 | PASS |
| Restart/replay and laundering resistance | PASS for bound evidence |
| Audit authority | **FAIL — F25/F26** |
| Legacy schema automatic authority | BLOCKED / PASS |
| Zero-duplicate semantic review | **FAIL — Final Gate cannot close with incomplete authority provenance** |

## Schema final review

- Current durable schema: **v4**
- Required promotion, identity, lookup, exact target, decision binding, revalidation, decision audit, safety and integrity fields are persisted.
- v1/v2/v3 and unsupported versions do not automatically acquire v4 authority.
- Remaining defect is not a schema-version bypass; it is missing identity/lookup audit-reference validation in decision replay.

## P2 review

| P2 risk | Turn F classification |
|---|---|
| RISK-BASELINE-001 | still valid; historical SPR-006 executable absence |
| RISK-SPR011-007 | still valid; privileged full-chain local rewrite lacks external anchor |
| RISK-SPR011-008 | future work; asserted local researcher identity is not authenticated |
| RISK-SPR011-009 | future work; live Evidence Graph adapter wiring deferred |
| RISK-SPR011-011 | still valid; legacy vacuous assertion remains separately remapped |
| RISK-SPR0115-001 | future work; production reconciliation adapter deferred |
| RISK-SPR0115-002 | still valid; local persistence lacks external trust anchor |
| RISK-SPR015-002 | future work; real connector-read normalization deferred |

No P2 is resolved, duplicated, superseded, or misclassified as P1. The new audit-authority defect is recorded separately as P1.

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

## Required next step

Run a separately commanded **SPR-015 Turn F Remediation** for `RISK-SPR015-010`, requiring original F25/F26 RED→GREEN evidence, identity/lookup audit binding across restart and fresh-envelope paths, and full regression. Do not start the Connector Read Pilot or enable Production Write.

<요약>

1. 기존 P1 003-009와 필수 24개 공격은 모두 차단됐고 전체 안전 회귀도 통과했다.
2. 추가 audit-authority probe에서 identity 및 lookup audit의 의미가 사라져도 decision replay가 성공하는 새 P1 한 건이 확인됐다.
3. Turn F는 FAIL이며 CORE COMPLETE=NO, connector pilot readiness=NO를 유지한다.

기록 시각: 2026-09-26 14:52:35 +09:00 (Asia/Seoul)
