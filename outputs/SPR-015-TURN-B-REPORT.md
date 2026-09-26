# SPR-015 Turn B Durable Research Intake Report

> 문서 경로: `outputs/SPR-015-TURN-B-REPORT.md`
> 기록일: 2026-09-26 (Asia/Seoul)

## Result

**SPR-015 TURN B COMPLETE = YES / PASS**

Research Intake is now backed by a versioned, hash-verified local SQLite envelope. Restart/replay, intermediate-state recovery blocking, identity conflict hardening, and sealed read-only lookup outcomes were verified. Production Write remains **DISABLED**; Production Pilot remains **TEST_DEFERRED**.

## Baseline and prerequisite

- Branch: `ASS_v1`
- Baseline HEAD: `924e81ed98e9d6e9ac98541fc24c03cd5ca9c80d`
- Local/origin baseline: identical; initial tree clean
- Turn A: COMPLETE / PASS, 41/41
- P0/P1: 0/0
- Production mutations: Zotero 0 / Drive 0 / Notion 0

## Implementation

- Reused RAP native SQLite/Queue persistence.
- Persisted schema version, project/question/search/candidate/promotion bindings, observed and normalized identifiers, identity result, canonical/Zotero lookup result, dedup decision, lifecycle, timestamps, provenance, audit, counters, and safety state.
- Added SHA-256 envelope integrity and required-field/schema/state validation.
- Persisted `IDENTITY_RESOLVING` and `DEDUP_CHECKED` are `RECOVERY_REQUIRED`; automatic advancement is false.
- Restarted final CREATE/REUSE decisions return the same lineage without production mutation.
- Hardened DOI/PMID conflicts and title-author-year near-match conflicts.
- Added a sealed local read-only lookup contract. Timeout, malformed, auth, permission, network, and partial outcomes remain UNKNOWN/LOOKUP_FAILED and never become “absent”.

## State and decision semantics

Durable states: `INBOXED`, `PROMOTED`, `IDENTITY_RESOLVING`, `IDENTITY_RESOLVED`, `DEDUP_CHECKED`, `CREATE_CANDIDATE`, `REUSE_EXISTING`, `AMBIGUOUS`, `IDENTITY_CONFLICT`, `BLOCKED`.

`CREATE_CANDIDATE` is a persisted decision only; it is not a Zotero CREATE and carries no write capability.

## Tests

| Suite | Result |
|---|---:|
| Turn A regression | 41/41 PASS |
| Restart RS01-RS10 | 10/10 PASS |
| Lookup LU01-LU10 | 10/10 PASS |
| Identity ID01-ID12 | 12/12 PASS |
| New Turn B assertions | **32/32 PASS** |
| Official full safe regression | PASS; exit code 0 |

SPR-014 CW01-CW20, R01-R18, 14 probes; SPR-013 21 assertions; and SPR-012 safety suites remain PASS.

## Read-only integration disposition

Local sealed read-only lookup integration: **PASS**. Real Zotero read-only lookup: **DEFERRED** because this Turn had no separately specified authoritative target/credential scope. No credential, endpoint permission, or connector capability was broadened. No mutation method is exposed.

## Safety

- P0/P1: **0/0**
- Secret leakage: **0**
- Zotero/Drive/Notion production mutation: **0/0/0**
- Production Write: **DISABLED**
- Production Pilot: **TEST_DEFERRED**

## Known limitations

- Real connector data-shape and permission behavior remains deferred.
- Persistence integrity is locally anchored SHA-256, not an external trust anchor.
- Human recovery is required for incomplete intermediate states.
- Production CREATE/UPDATE/DELETE/MERGE and downstream PDF/Drive/Library_ID/Paper Review remain out of scope.

## Recommended next step

An independently commanded Turn C Final Gate should adversarially reverify durable replay, corruption handling, lookup failure semantics, multi-identifier conflict policy, all Turn A/B suites, and full regression. It must not activate Production Write or run the production pilot.

<요약>

1. Intake lineage와 결정이 restart-safe local SQLite persistence로 승격되었다.
2. Turn B 신규 32/32와 전체 회귀가 통과했고 production mutation은 0건이다.
3. 실제 Zotero read-only 접근은 안전한 대상 지정이 없어 DEFERRED이며 다음 단계는 독립 Final Gate다.

기록 시각: 2026-09-26 (Asia/Seoul)
