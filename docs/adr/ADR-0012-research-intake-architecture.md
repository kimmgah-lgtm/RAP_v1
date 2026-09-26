# ADR-0012 — Research Intake Architecture

- Status: ACCEPTED
- Date: 2026-09-26
- Scope: SPR-015 requirements only; implementation not started

## Context

Research practice exposed recurring DOI and bibliographic mismatches, duplicate Zotero records, repeated PDF acquisition attempts, repeated manual downloads, an unclear boundary between search candidates and canonical papers, and premature downstream asset creation.

## Decision

RAP starts from a **Research Question**, not from Zotero. The canonical intake path is:

```text
Research Question
→ Search
→ Research Inbox
→ Researcher PROMOTE
→ Canonical Identity Resolution
→ Deduplication Gate
→ Zotero CREATE or REUSE
→ Verified PDF
→ Drive Canonical PDF
→ Library_ID
→ Paper Review
→ Researcher Review
→ ResearcherConfirmed
```

### One search pipeline

Quick Search and Systematic Search are modes of one Research Search Pipeline. Quick Search supports natural-language discovery. Systematic mode extends the same `Project_ID` and lineage with PICO/PICOS, inclusion and exclusion criteria, study design, date range, databases, and a reproducible search strategy. A Quick project may be promoted without losing its discovery history.

### Research Inbox boundary

`SEARCH RESULT != ZOTERO ITEM != LIBRARY ITEM != PAPER REVIEW`. Search results are non-canonical candidates. Before an explicit researcher PROMOTE decision, Zotero creation, Drive canonical writes, canonical `Library_ID` allocation, and Paper Review creation are prohibited.

### Canonical identity and deduplication

Identity evidence is evaluated in this order: normalized DOI; strong external identifier such as PMID/PMCID; publisher/source identity; normalized title + author + year; fuzzy candidate. Fuzzy similarity is not merge authority. Ambiguity fails closed to human review. `Project_ID` is not inferred.

Deduplication occurs before Zotero creation:

```text
Identity Resolution
→ Existing Canonical Paper Lookup
→ Existing Zotero Lookup
→ CREATE or REUSE
```

The invariant is one paper → one canonical identity → one Zotero parent item.

### Stateful PDF acquisition and verification

PDF acquisition is a stateful workflow across approved routes and fallbacks, ending in `MANUAL_REQUIRED` when automation cannot safely finish. Download success is not verification. The states include `PDF_VERIFIED`, `PDF_PROBABLE`, `PDF_AMBIGUOUS`, `PDF_MISMATCH`, and `PDF_MISSING`; ambiguous or mismatched files cannot become canonical automatically.

### Library and review ownership

The invariant is one canonical paper → one `Library_ID` → one Paper Review. Candidate results do not receive Paper Reviews. `HUMAN_OWNED` and `ResearcherConfirmed` data remain behind the ownership firewall and cannot be overwritten by automation.

## Golden path

SPR-015 is the **ONE-PAPER ZERO-DUPLICATE RESEARCH INTAKE PILOT**. It proves exactly one promoted paper reaches one canonical identity, one Zotero CREATE/REUSE result, one verified canonical PDF, one `Library_ID`, one Paper Review, and researcher confirmation without duplicates or protected-field mutation.

## Consequences

- Candidate storage and canonical storage remain separate.
- Search, screening, promotion, identity, deduplication, acquisition, verification, and review lineage must be auditable.
- Ambiguous identity and PDF states require human review.
- Production targets, permissions, acquisition routes, identity thresholds, and recovery procedures require separate approval.
- This ADR authorizes no connector, schema, migration, external mutation, or SPR-015 code.

<요약>

1. Research Question에서 시작해 PROMOTE 이후에만 canonicalization을 진행한다.
2. 단일 검색 파이프라인, 사전 중복 제거, 상태형 PDF 검증, 1논문-1Library_ID-1Review를 채택한다.
3. 모호성은 사람에게 넘기며 ResearcherConfirmed를 자동화가 변경하지 않는다.

기록 시각: 2026-09-26 (Asia/Seoul)
