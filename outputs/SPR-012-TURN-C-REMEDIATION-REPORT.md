# SPR-012 Turn C Remediation Report

Date: 2026-09-24

Branch: `ASS_v1`

HEAD before commit: `0ab3a38d249462d5bafb0b81150e062470b90579`

## Outcome

**SPR-012 Turn C targeted remediation: COMPLETE / PASS**

The sole P1 blocker from the Turn B Final Gate was reproduced, corrected at the execution boundary, and verified. Production Write remains disabled. The post-remediation Final Gate was not performed, READY FOR NEXT SPRINT was not evaluated, and SPR-013 was not started.

## RED evidence

Before remediation, public `New-RapExternalReadAdapter` accepted an arbitrary `ReadProbe` scriptblock. A callback incremented an in-memory side-effect counter while the adapter reported `AllowedMethod=GET`, `ProductionWrite=DISABLED`, `ChangesApplied=false`, and a PASS result. Observed callback executions: **1**.

No real external service was accessed or mutated during the reproduction.

## Implementation

The production read boundary now:

- removes `ReadProbe`/scriptblock injection from the public external adapter constructor;
- accepts only system, HTTPS endpoint, credential environment-variable name, and a validated relative resource path;
- creates an unguessable capability token backed by a module-private capability registry;
- resolves only registered `Rap.ReadOnlyCapabilityToken` instances and rejects forged tokens;
- invokes a fixed, fully qualified `Invoke-RestMethod -Method Get` transport;
- refuses missing credentials, unsafe endpoints, path escape, unknown capability kinds, and unknown external states;
- keeps structured fixture responses behind a read-only test adapter with no executable callback;
- continues to return `ProductionWrite=DISABLED` and `ChangesApplied=false` for every probe outcome.

The mutation firewall remains default-deny for CREATE, UPDATE, DELETE, MOVE, MERGE, APPLY, UPSERT, PATCH, POST, and PUT. External results do not overwrite local truth.

## Changed files

- `src/Local/ProductionReadiness/ProductionReadinessAdapters.psm1`
- `src/Local/ProductionReadiness/ResearchAutomation.ProductionReadiness.psm1`
- `src/Local/ProductionReadiness/ResearchAutomation.ProductionReadiness.psd1`
- `src/Local/ProductionReadiness/tests/TestHarness.ps1`
- `src/Local/ProductionReadiness/tests/ProductionReadinessTests.ps1`
- `src/Local/ProductionReadiness/tests/ProductionReadinessAdversarialTests.ps1`
- `src/Local/ProductionReadiness/tests/ReadCapabilityBoundaryTests.ps1`
- `tools/Invoke-Tests.ps1`
- `docs/HANDOFF.md`
- `outputs/SPR-012-TURN-B-FINAL-GATE-REPORT.md` (preserved failed-Gate evidence)
- `outputs/SPR-012-TURN-C-REMEDIATION-REPORT.md`

## Required A–I verification

| Requirement | Result |
|---|---:|
| A. Normal GET/read probe | PASS |
| B. Callback-internal write attempt | BLOCKED |
| C. Forged write-disabled metadata | BLOCKED / canonical capability unchanged |
| D. Indirect/nested write callback | BLOCKED |
| E. Adapter-bypass write attempt | BLOCKED |
| F. Exception followed by write retry | BLOCKED |
| G. Production mutation accounting | Zotero/Drive/Notion **0/0/0** |
| H. PR01–PR16 regression | **16/16 PASS** |
| I. Full safe RAP regression | **PASS** |

Focused capability-boundary result: **A–G 7/7 PASS; failures 0**.

Security assertion: **PASS — `ReadProbe callback cannot obtain or invoke mutation capability`.**

## Regression evidence

- Production readiness focused PR01–PR16: **16/16 PASS**
- Production readiness adversarial/negative: **17/17 PASS**
- Credential leakage: **2/2 PASS; secret leakage 0**
- Reconciliation core: **16/16 PASS**
- Reconciliation negative: **16/16 PASS**
- Reconciliation adversarial: **13/13 PASS**
- Reconciliation traceability: **10/10 requirements mapped; 8 assertions PASS**
- Full safe RAP runner: **PASS**
- Health dashboard: **PASS; 29 capabilities; 67/67 component commands**
- Evidence Graph: **47/47 PASS**
- Synthesis: **68/68 PASS**
- Output core/adversarial/gate: **92/92, 10/10, 15/15 PASS**
- Workflow core/legacy adversarial/Turn-C remediation/composite adversarial: **PASS**
- Workflow Turn-E remediation/adversarial/traceability: **PASS**

Mandatory test failures: **0**.

## External probe status

| System | Credential present | Target present | Result |
|---|---:|---:|---:|
| Zotero | false | false | **TEST_DEFERRED** |
| Google Drive | false | false | **TEST_DEFERRED** |
| Notion | false | false | **TEST_DEFERRED** |

No live probe was attempted. Deferred results were not represented as PASS. Credential values were not printed or persisted.

## Risk reassessment

- P0: **0**
- P1: **0** — `RISK-SPR012-001` remediated and covered by an executable security assertion
- P2: **7**, inherited non-blocking inventory

## Production safety

- Environment: `LOCAL`; expected environment: `LOCAL`
- Production Readiness write: **DISABLED**
- Production reconciliation APPLY: **DISABLED / not invoked**
- DELETE/MERGE: **DISABLED / blocked**
- Zotero mutations: **0**
- Google Drive mutations: **0**
- Notion mutations: **0**

## Turn boundary

- SPR-012 Turn C remediation: complete
- Production Write: disabled
- External probes: TEST_DEFERRED
- SPR-012 Final Gate after remediation: not performed
- READY FOR NEXT SPRINT: not evaluated
- SPR-013: not started

SPR-012 TURN C COMPLETE — READPROBE P1 REMEDIATED.
FINAL GATE NOT PERFORMED.
