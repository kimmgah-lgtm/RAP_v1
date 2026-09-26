# SPR-015 Turn E Independent Final Re-Gate Report

> 문서 경로: `outputs/SPR-015-TURN-E-FINAL-REGATE-REPORT.md`
> 기록일: 2026-09-26 (Asia/Seoul)

## Final result

**SPR-015 TURN E INDEPENDENT FINAL RE-GATE = FAIL**

**SPR-015 LOCAL/DURABLE CORE COMPLETE = NO**

**READY FOR CONNECTOR READ PILOT = NO**

Production Write는 **DISABLED**, Production Pilot과 Real Zotero lookup은 **TEST_DEFERRED**다. Turn E에서 remediation이나 외부 connector pilot은 수행하지 않았다.

## Baseline and environment

- Branch: `ASS_v1`
- Baseline HEAD: `4f7d5e150472c3d1cb908017f022f82ec8c33625`
- Initial local HEAD = `origin/ASS_v1`; working tree clean
- Environment: Windows / PowerShell 7 / LOCAL
- Turn D remediation prerequisite: PASS; RD01-RD12 12/12, D01-D19 19/19
- Turn D 이후 기록된 COMPLETE=YES는 Gate evidence로 사용하지 않고 독립 재판정했다.

## Historical P1 closure

| Risk | Turn E result |
|---|---|
| RISK-SPR015-003 | PASS — lookup failure/unknown cannot become NOT_FOUND or CREATE |
| RISK-SPR015-004 | PASS — promotion/search/candidate lineage substitution fails closed |
| RISK-SPR015-005 | PASS — changed lookup evidence invalidates cached CREATE across restart |
| RISK-SPR015-006 | PASS for fields covered by `DecisionBindingHash`; E22 found a separate omitted target field |
| RISK-SPR015-007 | PASS — pre-decision revalidation and bound audit ordering are reconstructable |

The five historical failure classes are blocked on their tested paths. Two new alternate-path P1 defects prevent Gate closure.

## Turn E independent probes

**20 PASS / 2 FAIL / 22 total; exit code 1**

| Probe range | Result | Evidence |
|---|---:|---|
| E01-E20 | 20/20 PASS | Lookup uncertainty, changed evidence, lineage substitution, restart, audit proof/failure, and legacy schema fail closed |
| E21 | **FAIL** | A legitimate resolved-identity object can be mutated to a different canonical identity and passed to the public dedup API; it grants `CREATE_CANDIDATE` |
| E22 | **FAIL** | A persisted `REUSE_EXISTING` decision's `ZoteroItemId` can be changed, re-enveloped, reloaded, and replayed because the selected target ID is absent from `DecisionBindingHash` and decision audit |

## New P1 blockers

### RISK-SPR015-008 — Identity resolution authority is not sealed at the dedup boundary

- Severity: **P1 / Gate blocking**
- Affected invariant: resolved identity used for lookup and decision must be the exact candidate-derived, persisted, integrity-bound identity.
- Reproduction: resolve candidate identity, mutate `CanonicalKey` on the returned identity object, and call exported `Get-RapPreZoteroDedupDecision`. The forged absent identity receives `CREATE_CANDIDATE`.
- Root cause: the public dedup API checks only CandidateId and hashes the caller-supplied identity; it does not rederive identity or verify it against an immutable persisted identity binding.
- Impact: a caller can redirect dedup to a different identity namespace and obtain duplicate CREATE authority.
- Recommended remediation: seal identity resolution with its own versioned hash tied to candidate/promotion lineage; verify or rederive it at the dedup boundary and after reload; never trust a mutable caller object.

### RISK-SPR015-009 — Selected Zotero reuse target is omitted from decision semantic binding

- Severity: **P1 / Gate blocking**
- Affected invariant: a REUSE decision must bind the exact existing Zotero parent item that it authorizes.
- Reproduction: create a valid `REUSE_EXISTING` decision for `Z-GOOD`, change only `ZoteroItemId` to `Z-EVIL`, save a new valid persistence envelope, reload, and replay. The forged target is returned.
- Root cause: `Get-RapDecisionBinding` and `PRE_ZOTERO_DEDUP_DECIDED` omit `ZoteroItemId`.
- Impact: valid decision/evidence hashes can authorize reuse of the wrong Zotero parent, violating one-paper/one-parent identity safety.
- Recommended remediation: include target identity and complete decision payload in the semantic binding and audit proof; validate the target against the exact lookup evidence before replay.

Turn E did not remediate either blocker.

## Semantic Gate review

| Gate | Result |
|---|---:|
| Research Inbox boundary and pre-PROMOTE zero side effects | PASS |
| Promotion binding | PASS |
| Lookup positive authorization / uncertainty fail-closed | PASS |
| Post-decision lookup invalidation | PASS |
| Decision evidence immutability | **FAIL — identity authority and Zotero target are incomplete** |
| Authority laundering resistance | **FAIL — omitted Zotero target survives fresh envelope** |
| Schema v3 / legacy fail-closed | PASS for required schema fields and v1/v2 rejection |
| Pre-decision revalidation / audit proof / audit failure | PASS |
| Restart and same-evidence replay | PASS |
| Identity and zero-duplicate semantics | **FAIL — alternate identity can obtain independent CREATE authority** |

## Required test execution

| Suite | Turn E result |
|---|---:|
| Turn E independent probes | **20/22 PASS; 2 FAIL** |
| Turn D remediation | 12/12 PASS |
| Turn D probes | 19/19 PASS |
| Turn C remediation | 19/19 PASS |
| Turn C probes | 13/13 PASS |
| Turn B RS / LU / ID | 10/10, 10/10, 12/12 PASS |
| Turn A Contract / Zero-Duplicate / Inbox / Adversarial | 10/10, 10/10, 8/8, 13/13 PASS |
| SPR-014 CW / R / Gate | 20/20, 18/18, 14/14 PASS |
| SPR-013 | 21 assertions PASS |
| SPR-012 | focused 16/16, adversarial 17/17, capability boundary 7/7 PASS |
| Full safe RAP regression | PASS; exit code 0 |

## P2 review

All eight P2 items remain valid and non-blocking in their recorded scope: historical SPR-006 executable absence, privileged local audit rewrite, asserted local researcher identity, live Evidence Graph adapter wiring, legacy vacuous assertion, production reconciliation adapter, external trust anchor, and real connector-read normalization. None is reduced by documentation, and neither new P1 is hidden under a P2.

## Safety state

- P0: **0**
- Open P1: **2**
- P2: **8**
- Semantic blockers: **2**
- Secret leakage: **0**
- Zotero production mutation: **0**
- Drive production mutation: **0**
- Notion production mutation: **0**
- Production Write: **DISABLED**
- Production Pilot: **TEST_DEFERRED**
- Real Zotero lookup: **TEST_DEFERRED**

## Required next step

Run a separately commanded SPR-015 Turn E remediation for `RISK-SPR015-008/009`, with original RED→GREEN evidence, expanded public-boundary and restart/envelope probes, and full regression. Do not start the connector read pilot or enable Production Write.

<요약>

1. 기존 다섯 P1 경로와 전체 회귀는 통과했지만 Turn E 독립 probe 22개 중 2개가 실패했다.
2. 변조 identity resolution이 CREATE 권한을 얻고, REUSE의 Zotero target ID가 의미적 binding에서 누락되어 새 P1 두 건이 열렸다.
3. Final Gate는 FAIL이며 CORE COMPLETE=NO, connector read pilot readiness=NO이다.

기록 시각: 2026-09-26 14:24:00 +09:00
