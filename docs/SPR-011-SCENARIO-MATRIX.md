# SPR-011 Requirement-to-Assertion Matrix

Executable evidence:

- `src/Local/Workflow/tests/WorkflowExceptionTests.ps1` — 69 assertions
- `src/Local/Workflow/tests/WorkflowExceptionAdversarialTests.ps1` — 16 assertions
- `src/Local/Workflow/tests/WorkflowCompositePolicyTests.ps1` — 20 assertions (R01-R20)
- `src/Local/Workflow/tests/WorkflowCompositePolicyAdversarialTests.ps1` — 15 assertions across 9 adversarial cases

Result: **120 executable assertions PASS; 0 failures**.

| Requirement | Executable assertion/evidence | Result |
|---|---|---|
| Exception Taxonomy | Taxonomy contains exactly 13 required stable classes | PASS |
| Exception Registry | Same exception fingerprint is stored once across repeated operations | PASS |
| Integrity Detector | Clean snapshot produces zero exceptions | PASS |
| Zotero source deleted | `Zotero.Exists=false` produces `ZOTERO_SOURCE_DELETED` | PASS |
| Duplicate bibliographic registration | Two registration IDs produce `DUPLICATE_BIBLIOGRAPHIC_REGISTRATION` | PASS |
| Notion Review missing | Missing review produces `NOTION_REVIEW_MISSING` | PASS |
| Manually-created Notion Review | Manual/unregistered page produces `MANUALLY_CREATED_NOTION_REVIEW` | PASS |
| Library_ID linkage broken | Invalid/mismatched link produces `LIBRARY_ID_LINKAGE_BROKEN` | PASS |
| PDF missing/replaced | Missing PDF or changed hash produces `PDF_MISSING_OR_REPLACED` | PASS |
| Project linkage inconsistency | Invalid project link produces `PROJECT_LINKAGE_INCONSISTENCY` | PASS |
| Automation/manual conflict | Conflicting field set produces `AUTOMATION_MANUAL_EDIT_CONFLICT` | PASS |
| AI/researcher conflict | Conflicting confirmed field produces `AI_ASSISTED_RESEARCHER_CONFIRMED_CONFLICT` | PASS |
| ORPHAN | Orphan reference collection produces `ORPHAN` | PASS |
| STALE | Source version greater than derived version produces `STALE` | PASS |
| BROKEN_LINK | Each unreachable link produces a distinct `BROKEN_LINK` | PASS |
| UNKNOWN_EXCEPTION | Unknown signal produces a blocked `UNKNOWN_EXCEPTION` | PASS |
| Deterministic identity | Equivalent detection produces identical ExceptionId and SnapshotHash | PASS |
| Resolution Planner | Default state is derived from taxonomy and plan has deterministic ID/hash | PASS |
| AUTO_SAFE | Only STALE receives `REFRESH_LOCAL_DERIVED_STATE` | PASS |
| HUMAN_REVIEW_REQUIRED | Duplicate/review cases preserve the snapshot unchanged | PASS |
| BLOCKED | Deleted source and unknown exception default to BLOCKED | PASS |
| IGNORE_WITH_JUSTIFICATION | Blank justification rejects; non-empty justification is retained | PASS |
| No automatic deletion | Plans/audits contain zero delete actions | PASS |
| No automatic merge | Plans/audits contain zero merge actions; duplicate cannot be AUTO_SAFE | PASS |
| No arbitrary canonical selection | Plans/audits contain zero canonical selections | PASS |
| HUMAN_OWNED protection | Verification fails injected Introduction overwrite | PASS |
| Researcher-confirmed protection | Verification fails injected confirmed Outcome overwrite | PASS |
| Preserve Library_ID | Verification fails injected Library_ID change | PASS |
| Preserve source-of-truth boundaries | Non-AUTO_SAFE reconciliation has equal before/after hash | PASS |
| Recovery/Reconciliation | STALE updates only `DerivedVersion` to `SourceVersion` | PASS |
| Verification | Resolved STALE is no longer detected and invariants pass | PASS |
| Idempotency | Same OperationID/payload returns `ALREADY_COMPLETED` | PASS |
| Payload conflict | Same OperationID/different snapshot throws `PAYLOAD_CONFLICT` | PASS |
| Atomic persistence | State, audit, and operation are committed in one SQLite transaction | PASS |
| Persistence/reload | Exception, plan, reconciliation, verification, audit, and operation reload | PASS |
| Audit Trail | Audit records identities, states, verification status, and all safety counters | PASS |
| Compound failure | Deleted source + missing PDF + broken Library_ID remain three distinct exceptions | PASS |
| Atomic failure injection | Injected commit failure propagates and no completed state is recorded | PASS |
| Production Write disabled | `WorkflowExceptionsProductionWrite=false` assertion passes | PASS |
| External tests deferred | Write layer disabled and Drive target empty in local configuration | PASS |

## Turn-C remediation mapping

Evidence file for R01-R20: `src/Local/Workflow/tests/WorkflowCompositePolicyTests.ps1`.

| Requirement ID | Test case and actual assertion | Result | Evidence location |
|---|---|---:|---|
| R01 | STALE-only operation requires `AutoSafeEligible`, AUTO_SAFE plan, and RECONCILED result | PASS | `WorkflowCompositePolicyTests.ps1` R01 |
| R02 | STALE + broken Library_ID requires BLOCKED, zero AUTO_SAFE plans, zero changed hashes | PASS | same, R02 |
| R03 | STALE + duplicate registration requires HUMAN_REVIEW_REQUIRED and zero AUTO_SAFE plans | PASS | same, R03 |
| R04 | STALE + unresolved orphan requires HUMAN_REVIEW_REQUIRED and identity blocker | PASS | same, R04 |
| R05 | STALE + ownership conflict requires HUMAN_REVIEW_REQUIRED and ownership blocker | PASS | same, R05 |
| R06 | AUTO_SAFE candidate + BLOCKED requires all plans BLOCKED | PASS | same, R06 |
| R07 | AUTO_SAFE candidate + human review requires all plans HUMAN_REVIEW_REQUIRED | PASS | same, R07 |
| R08 | Two compatible AUTO_SAFE exceptions require all allow-list predicates | PASS | same, R08 |
| R09 | Incomplete/unknown safety context must throw `AUTO_SAFE_NOT_PERMITTED` | PASS | same, R09 |
| R10 | Missing LibraryLinkage evidence requires failed policy evaluation and BLOCKED | PASS | same, R10 |
| R11 | Malformed exception/policy evidence requires BLOCKED and unchanged hash | PASS | same, R11 |
| R12 | Broken Library_ID leaves LibraryId and linked candidate unchanged | PASS | same, R12 |
| R13 | Broken Library_ID emits no canonical-selection action | PASS | same, R13 |
| R14 | Broken Library_ID emits no delete/merge and no changed state hash | PASS | same, R14 |
| R15 | ResearcherConfirmed branch is unchanged | PASS | same, R15 |
| R16 | HumanOwned branch is unchanged | PASS | same, R16 |
| R17 | Same OperationID/payload returns ALREADY_COMPLETED with one audit | PASS | same, R17 |
| R18 | Same OperationID/different payload throws PAYLOAD_CONFLICT | PASS | same, R18 |
| R19 | Resolved identity plus STALE restores eligibility and reconciliation | PASS | same, R19 |
| R20 | Two-process persistence/reload preserves history, version, decision, and deterministic policy hash | PASS | same, R20; `CompositePolicyRecoveryProcess.ps1` |

Independent adversarial evidence: order reversal, duplicate exception, unknown exception, malformed identity, newly discovered blocker after reconciliation, missing/manual records, and automation-failure policy equivalence are asserted in `WorkflowCompositePolicyAdversarialTests.ps1`.

## Safety summary

| Invariant | Actual assertion | Result |
|---|---|---|
| Zotero mutation | Production write capability false; delete count 0 | PASS |
| Drive mutation | Production migration false; no automatic PDF action | PASS |
| Notion mutation | Production Notion write false; missing/manual review goes to human review | PASS |
| HUMAN_OWNED mutation | Injected mutation makes verification fail | PASS |
| Confirmed coding mutation | Injected mutation makes verification fail | PASS |
| Git mutation | No commit/push command executed | PASS |
