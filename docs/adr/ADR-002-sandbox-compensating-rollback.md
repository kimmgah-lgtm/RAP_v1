# ADR-002 — Sandbox Compensating Rollback Exception

- Status: Accepted
- Date: 2026-09-21

## Problem

Zotero Web API calls cannot share one database transaction. Adding a tag, collection membership, or linked attachment cannot be rolled back without a compensating removal, while SPR-003 otherwise prohibits deletion and tag removal.

## Decision

Permit compensating removal only in a verified Sandbox group library and only for an element created by the same active `OperationID`. Existing elements are never eligible. Linked-attachment rollback additionally requires the exact key returned by the create response and operation ownership metadata.

## Benefits

- Makes verification failure recoverable.
- Preserves the no-data-loss rule for pre-existing research data.
- Keeps all test writes inside the Sandbox boundary.

## Risks and controls

- Compensation is not atomic with the initial API call. Failed compensation enters the error queue for human review.
- Incorrect ownership could delete unrelated data. Exact operation identity and returned keys are mandatory.
- A misleading library name could weaken isolation. Only group libraries are accepted and deployment still requires an explicitly configured group ID.

