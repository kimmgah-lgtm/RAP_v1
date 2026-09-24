# SPR-012 Turn B Final Gate Report

Date: 2026-09-24

Branch: `ASS_v1`

HEAD: `0ab3a38d249462d5bafb0b81150e062470b90579`

## Gate decision

**SPR-012 FINAL GATE = FAIL**

**READY FOR NEXT SPRINT = NO**

The independent verification reproduced a Production Write firewall bypass.
Per the FAIL rule, code modification, remaining test execution, commit, and push
were stopped.

## Precondition

- HEAD: matched `0ab3a38d249462d5bafb0b81150e062470b90579`
- Branch: `ASS_v1`
- `origin/ASS_v1`: synchronized to the same commit
- Working tree before verification: clean
- HANDOFF and Turn-A report: present and consistent with the Turn-A parent,
  commit subject, tests, deferred probes, and production-write-disabled state

## Blocking evidence

The public `New-RapExternalReadAdapter` function accepts an arbitrary
`ReadProbe` scriptblock. `Invoke-RapExternalReadProbe` checks only the adapter's
declarative `AllowedMethod='GET'` and `ProductionWrite='DISABLED'` properties,
then executes that arbitrary callback. The callback is not constrained to a
trusted sealed read-only connector and is not mediated by the Production Write
firewall.

An isolated in-memory adversarial probe was created with:

- adapter method metadata: `GET`
- adapter production-write metadata: `DISABLED`
- injected callback side effect: increment a mutation counter
- normalized response: authorized, permitted, schema-compatible, object found

Observed result:

| Evidence | Actual |
|---|---:|
| Result status | PASS |
| Allowed method | GET |
| Injected mutation callback executions | 1 |
| Reported ProductionWrite | DISABLED |
| Reported ChangesApplied | false |

The layer therefore reported a safe read-only PASS while executing an
unmediated side-effecting callback. This violates the mandatory default-deny and
"bypass calls blocked" requirements.

No real Zotero, Drive, or Notion system was accessed or changed. The reproduced
side effect was an in-memory test counter only.

## Independent verification status

| Area | Result |
|---|---:|
| LOCAL/TEST/PRODUCTION environment guard | reviewed; no blocker found before STOP |
| Zotero/Drive/Notion adapter boundary | **FAIL — arbitrary callback execution** |
| Production Write firewall | **FAIL — adapter boundary bypass** |
| Preflight | reviewed; final determination stopped by blocker |
| Mutation manifest | reviewed; final determination stopped by blocker |
| Dry-run determinism | not re-executed after blocker |
| Credential/secret protection | no credential exposed during reproduction |

PR01–PR16, adversarial/negative suites, and the full safe RAP regression were
not re-executed after the P1 blocker was reproduced. Turn-A PASS evidence is not
substituted for this failed independent Gate.

## External probe status

- Zotero: **TEST_DEFERRED**
- Google Drive: **TEST_DEFERRED**
- Notion: **TEST_DEFERRED**

Deferred probes remain deferred and were not represented as PASS.

## Risk reassessment

- P0: **0**
- P1: **1** — `RISK-SPR012-001`, untrusted adapter callback can bypass the
  declared GET-only/write-disabled boundary
- P2: **7**, inherited non-blocking inventory

## Production mutations

- Zotero: **0**
- Google Drive: **0**
- Notion: **0**

Production Write remains configured as disabled. The Gate failure concerns the
enforcement boundary, not an observed production mutation.

## Required remediation

1. Remove arbitrary public scriptblock execution from the production adapter
   path, or restrict it to an explicitly test-only constructor unavailable from
   production composition.
2. Construct production adapters from trusted concrete GET-only transports for
   Zotero, Drive, and Notion.
3. Make adapter safety properties immutable or revalidate a sealed adapter type
   at invocation.
4. Route every external operation through one enforcing transport that rejects
   POST, PUT, PATCH, DELETE, create, update, move, merge, and apply regardless of
   caller-supplied metadata.
5. Add an adversarial test whose injected callback attempts a side effect and
   verify it is never invoked.
6. Re-run PR01–PR16, the expanded adversarial/credential suites, and the full
   safe RAP regression before another Final Gate.

## Git disposition

- Code changes: none
- Commit: prohibited and not performed
- Push: prohibited and not performed
- Failing evidence report/HANDOFF: left uncommitted for remediation handoff

SPR-012 TURN B COMPLETE — FINAL GATE FAIL.
REMEDIATION REQUIRED.
