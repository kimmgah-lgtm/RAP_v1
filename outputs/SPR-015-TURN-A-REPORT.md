# SPR-015 Turn A Research Intake Core Report

> 문서 경로: `outputs/SPR-015-TURN-A-REPORT.md`
> 기록일: 2026-09-26 (Asia/Seoul)

## Result

**SPR-015 TURN A COMPLETE = YES / PASS**

The LOCAL/MOCK Research Intake core now executes the bounded golden path from Research Question through a non-mutating Zotero CREATE/REUSE decision. Production Write remains **DISABLED** and the production pilot remains **TEST_DEFERRED**.

## Baseline and prerequisite

- Branch: `ASS_v1`
- Baseline HEAD: `ef89b0073d172edb7efcc2680b32ca2b7dcbcdf4`
- Baseline `origin/ASS_v1`: identical
- Initial working tree: clean
- SPR-014 Turn D: PASS
- SPR-014 COMPLETE: YES
- READY FOR SPR-015: YES — requirements/local-mock only
- Baseline P0/P1: 0/0
- Baseline production mutations: Zotero 0 / Drive 0 / Notion 0

## Implementation scope

Added a local `ResearchIntake` module implementing:

```text
Research Question
→ unified SearchRequest (QUICK implemented; SYSTEMATIC contract reserved)
→ typed Search Results
→ typed Research Inbox Candidates
→ explicit researcher PROMOTE ONE
→ canonical identity resolution
→ pre-Zotero canonical and Zotero lookup
→ CREATE_CANDIDATE / REUSE_EXISTING / AMBIGUOUS / IDENTITY_CONFLICT / BLOCKED
```

No production connector, PDF pipeline, Drive promotion, Library_ID allocation, Paper Review creation, ResearcherConfirmed write, or external mutation was added.

## Contracts and state model

| Contract | Result |
|---|---:|
| Research Question entry with explicit Project_ID | PASS |
| Unified QUICK/SYSTEMATIC request architecture | PASS |
| Search Result ≠ Inbox Candidate ≠ Promotion ≠ Zotero Decision | PASS |
| Search and Inbox canonical side effects | 0 |
| Explicit PROMOTE ONE binding | PASS |
| Candidate/Project/Question substitution prevention | PASS |
| Canonical identity priority | PASS |
| Pre-Zotero deduplication | PASS |
| Non-mutating CREATE/REUSE decision | PASS |
| Controlled Write bypass surface | none exported |

Implemented states: `DEFINED`, `SEARCHED`, `INBOXED`, `PROMOTED`, `IDENTITY_RESOLVED`, `CREATE_CANDIDATE`, `REUSE_EXISTING`, `AMBIGUOUS`, `IDENTITY_CONFLICT`, and `BLOCKED`. Invalid or untrusted transitions fail closed.

## Identity resolution

Priority is DOI → PMID/PMCID → publisher/source identity → normalized title+author+year → fuzzy-only ambiguity. DOI normalization accepts `doi:`, `doi.org`, `dx.doi.org`, case, and surrounding whitespace variations. Malformed DOI becomes INVALID/BLOCKED. Fuzzy-only evidence never grants merge or reuse authority.

Identifier/metadata conflict, multiple existing matches, orphan canonical mapping, and orphan Zotero mapping require human review or block automatically.

## Lineage and audit

The local audit reconstructs Project, Research Question, Search execution/mode, candidate rank/source, Inbox reason, researcher promotion and binding hash, observed identifiers, normalization authority, compared canonical/Zotero match counts, decision reason, final state, timestamp, and provenance. Audit entries are non-mutating and marked `ProductionWrite=DISABLED`.

## Turn A tests

| Suite | Result |
|---|---:|
| Contract CT01-CT10 | 10/10 PASS |
| Zero-duplicate ZD01-ZD10 | 10/10 PASS |
| Research Inbox RI01-RI08 | 8/8 PASS |
| Adversarial AD01-AD13 | 13/13 PASS |
| Total SPR-015 Turn A | **41/41 PASS** |

The matrix covers duplicate Candidate_ID/PROMOTE, DOI formatting/case, malformed DOI, DOI and candidate substitution, conflicting metadata, different DOI with same title, strong external ID, title-author-year policy, fuzzy-only false positive, stale candidate, missing provenance, invalid transition, incomplete canonical/Zotero mappings, retry, and absence of callback/recovery/direct-write exports.

## Regression

Official `tools/Invoke-Tests.ps1` exit code: **0**.

- SPR-014 CW01-CW20: 20/20 PASS
- SPR-014 R01-R18: 18/18 PASS
- SPR-014 independent probes: 14/14 PASS
- SPR-013: 21 assertions PASS
- SPR-012 focused/adversarial/credential/boundary: PASS
- Full available safe RAP regression: PASS

## Safety result

- P0: **0**
- P1: **0**
- Secret leakage: **0**
- Zotero production mutation: **0**
- Drive production mutation: **0**
- Notion production mutation: **0**
- Library_ID production allocation: **0**
- Paper Review production creation: **0**
- Production Write: **DISABLED**
- Production Pilot: **TEST_DEFERRED**

## Known limitations / P2

- Turn A state is in-memory; durable restart-safe promotion/decision persistence is deferred.
- Canonical and Zotero lookups are bounded mock registries; production/read-only connector integration is deferred.
- QUICK execution is implemented; SYSTEMATIC is represented in the shared contract but execution remains deferred.
- Researcher identity is asserted locally rather than externally authenticated.
- CREATE_CANDIDATE is only a decision and grants no write capability.

## Recommended Turn B

Research Intake Identity/Dedup Hardening with durable restart-safe persistence, integrity-protected replay, multi-identifier conflict expansion, and bounded read-only canonical/Zotero connector integration. Production mutation and the actual production pilot remain out of scope unless separately authorized.

<요약>

1. Research Question부터 Zotero CREATE/REUSE 결정까지의 LOCAL/MOCK core를 구현했다.
2. 신규 41/41과 기존 전체 안전 회귀가 통과했으며 중복 생성과 production mutation은 0건이다.
3. Turn B는 영속성·identity hardening·read-only lookup 연동이 권고되며 Production Write는 계속 비활성이다.

기록 시각: 2026-09-26 (Asia/Seoul)
