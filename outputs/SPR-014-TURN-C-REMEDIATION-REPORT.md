# SPR-014 Turn C P1 Remediation Report

Date: 2026-09-26

Branch: `ASS_v1`

Baseline HEAD: `2d601e07b637609c6757db2f15c1187b24f98f8a`

## Result

**SPR-014 TURN C = COMPLETE / PASS**

All three Turn-B Gate-blocking P1 defects are remediated. Required remediation tests R01-R18 pass, the original independent Gate probes pass 14/14, CW01-CW20 remain 20/20 PASS, and the full safe RAP regression passes.

This is remediation evidence, not a Final Gate. Global Production Write remains **DISABLED** and the actual production pilot remains **TEST_DEFERRED**.

## Root causes and remediation

### P1-A — Target capability binding

Root cause: the Turn-A fixture capability was bound only to target system/object and process-local state. It did not bind canonical Library ID, Project ID, field, Operation ID, approved plan hash, payload hash, or approval ID. Consequently, another valid Library ID or Project ID could reach the same target.

Remediation:

- capability issuance now requires the exact approved plan and registered approval;
- the sealed capability stores a hashed binding over Operation ID, Library ID, explicit Project ID (including the empty/absent case), target system, object, field, plan hash, payload hash, and approval ID;
- APPLY recomputes capability integrity and compares every binding field to the approved plan and persisted approval;
- target state independently carries current Library ID, Project ID, system, object, and field; any mismatch returns `CONTROLLED_WRITE_IDENTITY_CHANGED` before mutation;
- absent Project ID remains explicitly empty and cannot be inferred.

### P1-B — Apply-time identity and ownership revalidation

Root cause: Turn-A validated identity and ownership values embedded in the plan but did not read current target identity/ownership immediately before APPLY.

Remediation:

- the sealed fixture performs a fresh current-state read at APPLY time;
- current Library ID, Project ID, target system/object/field, canonical identity, PDF identity, identity status, ownership, field value/hash, and version are compared to the approved plan;
- changed identity returns `CONTROLLED_WRITE_IDENTITY_CHANGED`;
- changed ownership, including newly HUMAN_OWNED or ResearcherConfirmed state, returns `CONTROLLED_WRITE_OWNERSHIP_CHANGED`;
- changed value/hash or version returns `STALE_CONTROLLED_WRITE_PLAN`;
- no current-state mismatch reaches APPLY and no silent overwrite path exists.

### P1-C — Restart-safe operation and audit persistence

Root cause: capability, approval, operation, and audit state was process memory only, so VERIFIED replay and uncertain APPLYING/APPLIED recovery could not survive restart.

Remediation:

- reused the existing RAP native SQLite/Queue provider; no new database framework was created;
- added a local `ControlledWriteOperations` table containing a deterministic, SHA-256-protected operation envelope;
- persisted Operation ID, plan/payload hashes, Library/Project scope, target, approval binding and provenance, lifecycle state, before hash/version, apply result, read-back result, verification result, timestamps, and audit trail;
- state updates use either a local SQLite `BEGIN IMMEDIATE ... COMMIT` transaction or a single-statement compare-and-set transition for the concurrent `APPROVED -> APPLYING` claim;
- process-B reload of VERIFIED returns `ALREADY_COMPLETED` with mutation 0;
- process-B reload of APPLYING, APPLIED, or VERIFY_FAILED returns `RECOVERY_REQUIRED` with automatic mutation 0;
- persisted payload/hash corruption is detected as `CONTROLLED_WRITE_PERSISTENCE_CORRUPT`;
- all persistence is local/test-only and secret-free; no Zotero, Drive, or Notion storage is used.

## R01-R18 remediation tests

| Test | Result |
|---|---:|
| R01 Library ID cross-target attempt | PASS — BLOCKED |
| R02 Project ID cross-target attempt | PASS — BLOCKED |
| R03 target object substitution | PASS — BLOCKED |
| R04 target field substitution | PASS — BLOCKED |
| R05 approved payload substitution | PASS — BLOCKED |
| R06 ownership changed after approval | PASS — BLOCKED |
| R07 identity changed after approval | PASS — BLOCKED |
| R08 HUMAN_OWNED introduced after approval | PASS — BLOCKED |
| R09 ResearcherConfirmed introduced after approval | PASS — BLOCKED |
| R10 before hash/version changed | PASS — STALE/BLOCKED |
| R11 process A/B restart after PLANNED | PASS — state preserved, mutation blocked |
| R12 process A/B restart after APPROVED | PASS — approval reloaded, guards rerun, VERIFIED |
| R13 process A/B restart after APPLYING | PASS — RECOVERY_REQUIRED, mutation 0 |
| R14 process A/B restart after APPLIED | PASS — RECOVERY_REQUIRED, mutation 0 |
| R15 process A/B restart after VERIFIED | PASS — ALREADY_COMPLETED, mutation 0 |
| R16 process A/B restart after VERIFY_FAILED | PASS — RECOVERY_REQUIRED, mutation 0 |
| R17 duplicate Operation ID after repeated restart | PASS — ALREADY_COMPLETED, mutation 0 |
| R18 persisted payload/hash tampering | PASS — corruption detected |

Remediation total: **18/18 PASS; failures 0**.

## Existing and Gate suites

- CW01-CW10 focused: **10/10 PASS**
- CW11-CW20 adversarial: **10/10 PASS**
- Original independent Gate probes: **14/14 PASS; failures 0**
- SPR-013 read-only regression: **21 assertions PASS; failures 0**
- SPR-012 production readiness focused: **16/16 PASS**
- SPR-012 production readiness adversarial: **17/17 PASS**
- SPR-012 credential leakage: **2/2 PASS; leaks 0**
- SPR-012 read capability boundary: **7/7 PASS**
- Reconciliation core/negative/adversarial/traceability: **PASS**
- Full safe RAP regression: **PASS**
- Health dashboard: **PASS; 29 capabilities; 67/67 component commands**

## Persistence and restart evidence

R11-R17 execute separate PowerShell process A and process B instances against the same temporary local SQLite store. The plan and approval token are serialized only as test transport; process B reconstructs the token type and validates its approval ID, Operation ID, plan hash, and payload hash against the protected persisted binding before use.

Uncertain states never replay automatically:

- `APPLYING` -> `RECOVERY_REQUIRED`
- `APPLIED` -> `RECOVERY_REQUIRED`
- `VERIFY_FAILED` -> `RECOVERY_REQUIRED`
- `VERIFIED` -> `ALREADY_COMPLETED`

## P2 re-evaluation

All seven inherited P2 items were re-evaluated individually. None was deleted, downgraded, or represented as resolved.

| P2 item | Turn-C assessment | Blocking |
|---|---|---:|
| `RISK-BASELINE-001` — SPR-006 executable artifacts unavailable | unchanged; historical suite still cannot be rerun | NO |
| `RISK-SPR011-007` — workflow lifecycle chain has no external trust anchor | unchanged; controlled-write persistence also remains locally anchored | NO |
| `RISK-SPR011-008` — researcher identity is asserted, not externally authenticated | unchanged; human approval provenance remains a local identity assertion | NO |
| `RISK-SPR011-009` — live Evidence Graph lineage adapter is not wired | unchanged and outside this remediation | NO |
| `RISK-SPR011-011` — one legacy workflow assertion is vacuous | unchanged; replacement evidence remains authoritative | NO |
| SPR-011.5 production reconciliation adapters deferred | unchanged; production adapters remain intentionally absent | NO |
| SPR-011.5 reconciliation audit has no external trust anchor | unchanged; local hash/corruption evidence is not an external anchor | NO |

Open risk result: **P0 = 0, P1 = 0, P2 = 7 non-blocking**.

## Production safety

- Global Production Write: **DISABLED**
- Actual production pilot: **TEST_DEFERRED**, not PASS
- Production mutations: Zotero **0** / Drive **0** / Notion **0**
- Secret leakage: **0**
- Actual papers changed: **0**
- Ambiguous identities resolved: **0**
- Project mappings created: **0**

## Changed files

- `src/Local/ProductionReadiness/ControlledWritePilot.psm1`
- `src/Local/ProductionReadiness/ControlledWritePersistence.psm1`
- `src/Local/ProductionReadiness/ResearchAutomation.ProductionReadiness.psm1`
- `src/Local/ProductionReadiness/ResearchAutomation.ProductionReadiness.psd1`
- `src/Local/ProductionReadiness/tests/ControlledWritePilotTests.ps1`
- `src/Local/ProductionReadiness/tests/ControlledWritePilotAdversarialTests.ps1`
- `src/Local/ProductionReadiness/tests/ControlledWriteRemediationTests.ps1`
- `src/Local/ProductionReadiness/tests/ControlledWriteGateProbeTests.ps1`
- `src/Local/ProductionReadiness/tests/ControlledWriteRestartProcess.ps1`
- `tools/Invoke-Tests.ps1`
- `outputs/SPR-014-TURN-B-FINAL-GATE-REPORT.md`
- `outputs/SPR-014-TURN-C-REMEDIATION-REPORT.md`
- `docs/HANDOFF.md`

## Remaining limitations

- This implementation remains local/fixture-only; no live production mutation adapter was added.
- The production pilot remains TEST_DEFERRED and Global Production Write remains disabled.
- Local SHA-256 corruption detection is not an external trust anchor, consistent with the inherited P2 inventory.
- Human approval identity is locally asserted rather than backed by an external identity provider, also retained as inherited P2.
- APPLYING/APPLIED/VERIFY_FAILED require explicit human recovery; automatic mutation replay is prohibited.

## Exact next step

Perform an independently commanded **SPR-014 Turn D Final Gate**. Do not run the actual production pilot, enable Production Write, resolve ambiguous identities, create project mappings, or begin SPR-015.

SPR-014 TURN C COMPLETE —
CONTROLLED WRITE P1 REMEDIATION VERIFIED.
P0/P1 = 0/0.
PRODUCTION MUTATIONS = 0/0/0.
FINAL GATE NOT PERFORMED.
