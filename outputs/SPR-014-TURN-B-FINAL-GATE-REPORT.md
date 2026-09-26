# SPR-014 Turn B Final Gate Report

Date: 2026-09-25

Branch: `ASS_v1`

Verified HEAD: `2d601e07b637609c6757db2f15c1187b24f98f8a`

## Final Gate decision

**SPR-014 FINAL GATE = FAIL**

**SPR-014 COMPLETE = NO**

**READY FOR SPR-015 = NO**

The Turn-A controlled-write implementation and its declared CW01-CW20 suites are present and executable, but independent Final Gate probes found scope-binding, current-state revalidation, and restart/replay gaps. These are P1 blockers for any controlled-write path. No implementation was changed during this verification Turn.

Global Production Write remains **DISABLED**. The actual production pilot remains **TEST_DEFERRED**.

## Preconditions

- SPR-014 Turn A: **COMPLETE / PASS**
- Turn-A report: **PRESENT**
- `HEAD == origin/ASS_v1`: **PASS** at `2d601e07b637609c6757db2f15c1187b24f98f8a`
- HANDOFF and Turn-A report consistency: **PASS**
- Working tree before Final Gate verification: **CLEAN**

## Implementation verification

The implementation is code, not documentation or a stub. It contains executable plan hashing, Operation ID binding, sealed approval registries, human approval checks, allowlists, ownership checks, before-value/version checks, fixture apply, read-back comparison, idempotent in-process replay, audit construction, and explicit partial/verification failure states.

Verified controls:

- immutable plan hash: **PASS**
- Operation ID and payload approval binding: **PASS**
- approval absent / different operation / changed payload / changed target: **BLOCKED**
- AI/self approval: **BLOCKED**
- forged approval and forged Operation ID: **BLOCKED**
- stale value/version: **BLOCKED**
- RAP-owned field allowlist: **PASS**
- HUMAN_OWNED and ResearcherConfirmed plan ownership: **BLOCKED**
- read-back mismatch: **VERIFY_FAILED, not success**
- same-process verified replay: **ALREADY_COMPLETED; additional mutation 0**
- DELETE, MERGE, MOVE, PDF, batch, second-object, nested adapter, and callback bypass: **BLOCKED by declared suites**

## Independent Final Gate adversarial probes

| Probe | Result | Evidence |
|---|---:|---|
| approval absent | PASS | `HUMAN_APPROVAL_REQUIRED` |
| different Operation ID approval | PASS | `APPROVAL_BINDING_MISMATCH` |
| payload changed after approval | PASS | `CONTROLLED_WRITE_PLAN_TAMPERED` |
| target changed after approval | PASS | `CONTROLLED_WRITE_PLAN_TAMPERED` |
| approval/idempotent replay | PASS | `ALREADY_COMPLETED`, mutation count remains 1 |
| AI self approval | PASS | `SELF_APPROVAL_BLOCKED` |
| forged approval | PASS | `UNTRUSTED_CONTROLLED_WRITE_APPROVAL` |
| forged Operation ID | PASS | `CONTROLLED_WRITE_PLAN_TAMPERED` |
| stale value/version | PASS | `STALE_CONTROLLED_WRITE_PLAN` |
| partial failure/retry | PASS | partial state explicit; blind retry blocked |
| cross-project mutation | **FAIL** | plan for `PR999` reached `VERIFIED` on an adapter with no Project ID binding |
| canonical Library ID target binding | **FAIL** | plan for `LIB:L000004` reached `VERIFIED` on the `L000003` target because the adapter has no Library ID binding |
| restart/replay | **FAIL** | module reload loses capability/operation state; replay returns `UNTRUSTED_CONTROLLED_WRITE_ADAPTER`, not `ALREADY_COMPLETED` |
| fresh ownership/identity revalidation | **FAIL** | apply-time state exposes only system, object, fields, version, mutation count, and audit count; no current Library ID, Project ID, ownership, or identity state exists to compare |

Independent Final Gate probes: **10/14 PASS, 4/14 FAIL**.

## P1 blockers

### RISK-SPR014-001 — Target scope identity is not bound

Severity: **P1 / Gate blocking**

The sealed fixture adapter binds only `TargetSystem` and `TargetObject`. It does not bind canonical `LibraryId` or `ProjectId`. A signed and human-approved plan for another project or another valid Library ID can reach `VERIFIED` against the same target object.

Required remediation: bind the target capability and read-back snapshot to canonical Library ID and Project ID, then require exact equality during the final pre-apply guard and read-back verification.

### RISK-SPR014-002 — Current ownership and identity are not revalidated

Severity: **P1 / Gate blocking**

The pre-apply guard validates ownership and identity values embedded in the signed plan, but the adapter state does not expose current ownership or current identity. Therefore a target-side ownership or identity change after planning cannot be independently detected unless some unrelated field/version also changes.

Required remediation: obtain a fresh, sealed target snapshot immediately before apply containing ownership, canonical identity, project scope, field value/hash, and version; compare every guard input to the approved plan and fail closed on drift.

### RISK-SPR014-003 — Restart-safe idempotency and audit recovery are absent

Severity: **P1 / Gate blocking**

Capability, approval, operation, and audit registries are process memory only. Reloading the module loses verified-operation state, so a replay cannot resolve to `ALREADY_COMPLETED`. This does not meet the required restart/replay guarantee for a write engine.

Required remediation: persist operation identity, plan hash, approval binding, mutation state, read-back result, and audit/recovery evidence atomically in a durable local store; demonstrate restart-safe replay and partial-failure recovery before another Final Gate.

## Required suite results

- CW01-CW10 focused: **10/10 PASS**
- CW11-CW20 adversarial: **10/10 PASS**
- Independent Gate adversarial: **10/14 PASS; 4 FAIL**
- SPR-013 read-only regression: **21 assertions PASS; failures 0**
- SPR-012 production readiness focused: **16/16 PASS**
- SPR-012 production readiness adversarial: **17/17 PASS**
- SPR-012 credential leakage: **2/2 PASS; leaks 0**
- SPR-012 read capability boundary: **7/7 PASS**
- Reconciliation core/negative/adversarial/traceability: **PASS**
- Full safe RAP regression: **PASS**
- Health dashboard: **PASS; 29 capabilities; 67/67 component commands**

The existing suites pass but do not cover the four independent Gate failures above. Full regression PASS does not override a mandatory Final Gate adversarial failure.

## Production safety and risk accounting

- Global Production Write: **DISABLED**
- Actual production pilot: **TEST_DEFERRED**, not PASS
- Production mutations: Zotero **0** / Drive **0** / Notion **0**
- Secret leakage: **0**
- P0: **0**
- P1: **3** — all Gate blocking
- P2: **7** inherited, non-blocking; no new P2 was needed for this decision
- Actual papers modified: **0**
- Ambiguous identities resolved: **0**
- Project mappings created: **0**

## Gate conclusion

The Final Gate PASS conditions require adversarial failures 0, project and canonical identity isolation, fresh ownership/identity revalidation, restart-safe idempotency, and P0/P1 0/0. Those conditions are not met. Per command, no implementation remediation, commit, push, production mutation, or SPR-015 work is authorized in this Turn.

## Exact next step

Run a separately commanded SPR-014 targeted remediation Turn for `RISK-SPR014-001` through `RISK-SPR014-003`, add regression coverage for all four failing probes, and then repeat SPR-014 Final Gate. Do not start SPR-015 and do not enable Production Write.

SPR-014 TURN B COMPLETE — FINAL GATE FAIL.
REMEDIATION REQUIRED.
