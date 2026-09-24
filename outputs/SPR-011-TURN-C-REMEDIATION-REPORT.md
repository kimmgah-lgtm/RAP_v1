# SPR-011 Turn C Remediation Report

Date: 2026-09-24  
Scope: ambiguous identity / AUTO_SAFE policy hardening; local fixture/mock only

## 1. Confirmed Gate Failure

Reproduced: **YES**

Entity:

- Project_ID: `PR001`
- Library_ID: `LIB:L000001`

Detected exceptions before repair:

- `EXC-6bfb8d19dd6fae3c08f66167` — `LIBRARY_ID_LINKAGE_BROKEN`, expected `LIB:L000001`, observed `LIB:AMBIGUOUS`, default `BLOCKED`
- `EXC-6a96342013b17fdbf9032805` — `STALE`, source version 2, derived version 1, default `AUTO_SAFE`

Unsafe transition:

```text
LIBRARY_ID_LINKAGE_BROKEN -> BLOCKED / unchanged
STALE                     -> AUTO_SAFE / RECONCILED / changed
```

Root cause: `Invoke-RapWorkflowExceptionOperation` iterated the detected exceptions and called `New-RapExceptionResolutionPlan` independently for each one. The planner selected the exception's own default state. It had no complete active-exception safety context, so the STALE default bypassed the simultaneously active identity blocker.

## 2. Policy Repair

Identity blocker invariant: **PASS**

Conservative precedence: **PASS** — `BLOCKED > HUMAN_REVIEW_REQUIRED > AUTO_SAFE`

AUTO_SAFE allow-list: **PASS** — the following must all be explicitly true: unambiguous identity, resolved canonical entity, no identity blocker, no human-owned conflict, no researcher-confirmed conflict, non-destructive operation, idempotency, verification availability, valid required lineage, and no higher-priority exception.

Fail-closed behavior: **PASS** — missing/malformed safety evidence or unsupported policy state produces BLOCKED; an incomplete context cannot authorize AUTO_SAFE.

Order independence: **PASS** — reversed order and duplicated exception inputs produce the same resolution and policy hash.

Implementation:

- Added `Get-RapCompositeResolutionPolicy`.
- The operation computes one policy from the complete active exception set and supplies it to every plan.
- Added policy version `SPR-011-TURN-C-1` and deterministic policy hash.
- Plans, results, and audits retain policy version/hash/decision/reason.
- The exact former collision now produces both plans as BLOCKED, `AutoSafeEligible=false`, and zero changed reconciliation hashes.

## 3. Library_ID Protection

No automatic replacement: **PASS**

No arbitrary canonical selection: **PASS**

No destructive downstream rewrite: **PASS**

The broken-link candidate and Library_ID remain unchanged. No delete, merge, selection, Project_ID rewrite, Notion linkage rewrite, or confirmed Meta Coding write is emitted.

## 4. Researcher Protection

HUMAN_OWNED: **PASS**

Researcher-confirmed coding: **PASS**

Manual decisions: **PASS**

Composite identity/ownership collisions preserve the complete `HumanOwned` and `ResearcherConfirmed` branches. Ownership conflicts prevent AUTO_SAFE. Existing protected-field verification remains active, including blank-field ownership semantics inherited from prior RAP layers.

## 5. New Remediation Tests

R01-R20: **20 / 20 PASS**

Actual assertions: **20**

Failures: **0**

Coverage includes STALE-only eligibility, broken/duplicate/orphan identity, ownership conflicts, precedence, two compatible safe candidates, unknown/missing policy predicates, policy errors, Library_ID/canonical/destructive-action protection, researcher branches, idempotency/conflict, resolved-identity re-eligibility, and two-process history/policy determinism.

## 6. Adversarial Policy Tests

Executed: **9 cases / 15 assertions**

PASS: **9 cases / 15 assertions**

FAIL: **0**

Cases cover misleading STALE plus broken identity, order reversal, duplicate exceptions, UNKNOWN plus STALE, malformed identity evidence, a new blocker after previous reconciliation, missing review plus STALE, manual ambiguous review plus STALE, and automation-failure policy equivalence plus STALE.

## 7. Existing SPR-011 Scenarios

E01-E12 existing executable scenarios: **12 / 12 PASS**

Focused assertions: **120**

Failures: **0**

Breakdown:

- Core: 69
- Original adversarial: 16
- Turn-C R01-R20: 20
- Turn-C composite adversarial: 15

The 12/12 result refers to the existing executable detection/protection scenarios rerun after this bounded repair. Turn C did not perform a Final Gate or re-adjudicate broader Turn-B semantic findings; those remain in the risk register for Turn D.

## 8. Full Safe RAP Regression

Expected component suites: **11**

Available: **10**

Unavailable: **1** — SPR-006 executable source/test artifact

Executed: **10**

PASS: **10**

FAIL: **0**

The repository runner executed 21 underlying safe test scripts and returned PASS. The additional available SPR-009 Gate-remediation suite was also run separately: 31/31 assertions PASS. Capability dashboard: 25 capabilities and 55/55 component commands loaded, overall PASS.

## 9. Production Safety

Production Writes: **DISABLED**

Real External Tests: **TEST_DEFERRED**

Zotero changes: **0**

Drive changes: **0**

Notion changes: **0**

Production AI, Zotero, Drive migration, Notion, Synthesis, Output, and Workflow Exception write capabilities remain false. No real external provider or production data was accessed.

## 10. Risk State

P0: **0**

P1: **5 open from other Turn-B findings; 0 new Turn-C remediation failures**

P2: **1**

Turn-B Gate defect `RISK-SPR011-001`: **RESOLVED_PENDING_FINAL_GATE**

RISK-BASELINE-001: **OPEN VERIFIED NON-BLOCKING**

The Turn-B FAIL history is preserved. Turn C does not close SPR-011. Other Turn-B risks remain open for a later remediation/final-gate decision and were not broadened into this bounded repair.

## 11. Git

Commit: **NOT PERFORMED**

Push: **NOT PERFORMED**

## 12. Gate Status

SPR-011 FINAL GATE: **NOT PERFORMED**

READY FOR SPR-011.5: **NOT EVALUATED**

SPR-011.5: **NOT STARTED**

SPR-012: **NOT STARTED**

## 13. STOP

SPR-011 TURN C COMPLETE — REMEDIATION VERIFIED, FINAL GATE NOT PERFORMED.
