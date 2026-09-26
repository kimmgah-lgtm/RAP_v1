# SPR-015 Turn D Independent Final Re-Gate Report

> 문서 경로: `outputs/SPR-015-TURN-D-FINAL-REGATE-REPORT.md`
> 기록일: 2026-09-26 (Asia/Seoul)

## Final result

**SPR-015 TURN D INDEPENDENT FINAL RE-GATE = FAIL**

**SPR-015 LOCAL/DURABLE CORE COMPLETE = NO**

**READY FOR CONNECTOR READ PILOT = NO**

Turn D에서 remediation은 수행하지 않았다. Production Write는 **DISABLED**, Production Pilot과 Real Zotero lookup은 **TEST_DEFERRED** 상태를 유지한다.

## Baseline and prerequisites

- Branch: `ASS_v1`
- Accepted remediation baseline: `2e24584c0ff02e1e08bf3a5d3ff697a03cd8d98e`
- Initial local HEAD = `origin/ASS_v1`; working tree clean
- Turn C Final Gate: FAIL, original P1=2
- Turn C remediation: PASS; original RED reproduced, P1-A/P1-B GREEN, expanded 19/19, open P1=0
- Preconditions were internally consistent and sufficient to start Turn D.

## Independent semantic result

The original P1 closures were independently confirmed:

- P1-A: TIMEOUT, PARTIAL, LOOKUP_REQUIRED, missing, malformed, auth failure, and multiple/unknown lookup states cannot create a new decision.
- P1-B: search, project, candidate, DOI, and restart-bound lineage substitutions fail closed.
- Schema v2, legacy v1 rejection, unsupported schema rejection, and ordinary idempotent replay passed.

However, alternate paths exposed new Gate blockers after a decision already exists.

## Turn D independent probes

**15 PASS / 4 FAIL / 19 total; exit code 1**

| Probe | Result | Evidence |
|---|---:|---|
| D01-D14 | PASS | Lookup uncertainty, missing evidence, lineage substitutions, restart, legacy/schema attacks fail closed |
| D15 | **FAIL** | A prior CREATE decision survives a later TIMEOUT lookup and is returned unchanged |
| D16 | PASS | Same-evidence duplicate replay remains idempotent |
| D17 | **FAIL** | A prior CREATE decision survives replacement FOUND evidence that should force reuse/re-evaluation |
| D18 | **FAIL** | A semantically forged CREATE decision inside a newly valid generic persistence envelope is accepted |
| D19 | **FAIL** | Audit history contains no explicit proof that promotion lineage was revalidated before decision |

## New P1 blockers

### RISK-SPR015-005 — Existing decision bypasses fresh lookup evidence

- Severity: **P1 / Gate blocking**
- Evidence: D15, D17
- Affected invariant: decision must remain bound to the exact authoritative lookup evidence used to create it.
- Reproduction: create an authoritative NOT_FOUND decision, replace lookup evidence with TIMEOUT or FOUND, then invoke the public decision path. `Get-RapPreZoteroDedupDecision` returns the cached decision before comparing the current lookup execution.
- Impact: stale CREATE authority can survive evidence that is failed or proves an existing item, reintroducing duplicate-creation risk.
- Recommended remediation: seal decision-to-lookup execution/status/identity binding and revalidate it before cached replay; changed evidence must invalidate or block the old decision.

### RISK-SPR015-006 — Decision semantics are not independently integrity-bound

- Severity: **P1 / Gate blocking**
- Evidence: D18
- Affected invariant: a valid generic record hash cannot substitute for semantic decision integrity.
- Reproduction: persist a blocked TIMEOUT decision, change its decision/state to CREATE, save a new valid envelope, reload, and invoke the public decision path. The forged cached CREATE is returned.
- Impact: local semantic corruption can convert a blocked decision into CREATE while envelope integrity passes.
- Recommended remediation: add a decision binding/hash covering promotion, resolved identity, lookup evidence, decision, reason, state, and counters; validate it on load and before replay.

### RISK-SPR015-007 — Lineage revalidation is not audit-provable

- Severity: **P1 / Gate blocking**
- Evidence: D19
- Affected invariant: audit/provenance must reconstruct whether promotion lineage revalidation passed before decision.
- Reproduction: complete a normal decision and inspect persisted audit. No `PROMOTION_LINEAGE_REVALIDATED` event or equivalent decision record containing the promotion binding is present.
- Impact: restart/replay history cannot independently prove that the mandatory pre-decision revalidation occurred.
- Recommended remediation: append a durable revalidation event or bind the validated promotion hash and outcome into the decision audit evidence.

No blocker was remediated in Turn D.

## Required test execution

| Suite | Turn D result |
|---|---:|
| Turn C remediation | 19/19 PASS |
| Turn C independent probes | 13/13 PASS |
| Turn D independent probes | **15/19 PASS; 4 FAIL** |
| Turn B RS01-RS10 | 10/10 PASS |
| Turn B LU01-LU10 | 10/10 PASS |
| Turn B ID01-ID12 | 12/12 PASS |
| Turn A Contract | 10/10 PASS |
| Turn A Zero-Duplicate | 10/10 PASS |
| Turn A Research Inbox | 8/8 PASS |
| Turn A Adversarial | 13/13 PASS |
| SPR-014 CW01-CW20 | 20/20 PASS |
| SPR-014 R01-R18 | 18/18 PASS |
| SPR-014 independent probes | 14/14 PASS |
| SPR-013 | 21 assertions PASS |
| SPR-012 safety regression | PASS; secret leakage 0 |
| Full safe RAP regression | PASS; exit code 0 |

## P2 reassessment

| Risk | Turn D disposition |
|---|---|
| RISK-BASELINE-001 | still P2; historical SPR-006 executable absence, non-blocking for this core |
| RISK-SPR011-007 | still P2; privileged full-chain rewrite limitation, no new severity evidence |
| RISK-SPR011-008 | still P2; asserted local researcher identity, future authentication work |
| RISK-SPR011-009 | still P2; live Evidence Graph adapter wiring deferred |
| RISK-SPR011-011 | still P2; legacy vacuous assertion retained but remapped evidence exists |
| RISK-SPR0115-001 | still P2; production reconciliation adapter deferred |
| RISK-SPR0115-002 | still P2; local persistence lacks external trust anchor |
| RISK-SPR015-002 | still P2; real connector-read normalization remains deferred |

No listed P2 was reclassified. The new decision-binding defects are separately recorded as P1 rather than hidden under an existing P2.

## Safety state

- P0: **0**
- P1: **3 open Gate blockers**
- P2: **8**
- Secret leakage: **0**
- Zotero production mutation: **0**
- Drive production mutation: **0**
- Notion production mutation: **0**
- Production Write: **DISABLED**
- Production Pilot: **TEST_DEFERRED**
- Real Zotero lookup: **TEST_DEFERRED**

## Required next step

Run a separately commanded **SPR-015 Turn D Remediation** for `RISK-SPR015-005`, `RISK-SPR015-006`, and `RISK-SPR015-007`. Require RED→GREEN evidence and another independent Final Re-Gate. Do not start connector-read or production pilots.

<요약>

1. 원래 P1-A/P1-B는 독립적으로 닫혔지만 alternate path에서 새 P1 3건이 발견되었다.
2. 공식 전체 회귀는 통과했어도 Turn D 독립 프로브 4건 실패로 Final Re-Gate는 FAIL이다.
3. Production Write와 외부 mutation은 계속 0이며 별도 remediation이 필요하다.

기록 시각: 2026-09-26 (Asia/Seoul)
