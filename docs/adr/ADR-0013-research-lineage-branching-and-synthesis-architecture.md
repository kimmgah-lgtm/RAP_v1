# ADR-0013 — Research Lineage, Branching and Synthesis Architecture

- Status: ACCEPTED
- Date: 2026-09-26
- Scope: RAP research architecture and SPR-016 provisional direction; no SPR-016 implementation

## Context

RAP needs a research model broader than paper intake. Research questions evolve, exploratory work may become systematic, one evidence corpus may support several analyses, and prior analyses may later become evidence for higher-order synthesis. Overwriting a question, corpus, analysis or conclusion would destroy research history and reverse traceability.

## Decision

**Never overwrite research history. Derive, version, branch, link, and preserve provenance.**

Every material research artifact must be reusable, branchable, traceable and extensible. The long-term lineage is:

```text
Research Project
→ Research Problem
→ Research Question
→ Investigation / Search Session
→ Evidence Candidate
→ Evidence Corpus
→ Extraction / Evidence Data
→ Analysis / Synthesis
→ Finding
→ Conclusion
```

Each layer may have its own stable identity, version and provenance. A conclusion must be traceable in reverse through finding, analysis, extracted evidence, corpus, evidence item, search session, research-question version, problem and project.

## Research-question versioning

Research Questions are versioned rather than overwritten. For example, `RQ-001 v0` may represent background exploration, `v1` literature exploration, `v2` a structured question and `v3` a systematic specification. Every Search Session records the exact Research Question version from which it was derived.

## Exploratory-to-systematic continuity

Exploratory, structured and systematic search are increasing levels of rigor within the same `Project_ID` and lineage, not separate research universes. Earlier discovery history remains linked when rigor increases.

## Separation and branching

`Evidence Corpus != Analysis`, `Analysis != Finding`, and `Finding != Conclusion`. Branching is a first-class concept. One corpus may independently support narrative synthesis, thematic synthesis, evidence mapping, systematic review or meta-analysis. Meta-analysis may branch again by outcome, subgroup or sensitivity analysis without mutating the source corpus.

Prior analyses may become input artifacts for umbrella review, cross-domain synthesis, higher-order synthesis or meta-meta analysis. Their original provenance remains intact.

## Evidence generalization

A paper is an important Evidence Item type, but not RAP's top-level research object. Future extension points include datasets, clinical guidelines, reports, registry records and other research sources. This ADR defines the extension boundary only; it implements none of them.

## Position of SPR-015

SPR-015 is **Evidence Intake / Canonicalization Infrastructure**, not the whole research system:

```text
Research Discovery / Question Formation
→ Evidence Candidate
→ explicit PROMOTE
→ [SPR-015: intake, canonical identity, dedup, durable decision authority]
→ Evidence Corpus
```

Raw connector reads may be prefetched, but they do not acquire decision authority by themselves. The authoritative decision chain remains stable and auditable: `CANDIDATE_PROMOTED < IDENTITY_RESOLVED < decision-scoped canonical/Zotero lookup authority < PROMOTION_LINEAGE_REVALIDATED < PRE_ZOTERO_DEDUP_DECIDED`.

## SPR-016 provisional direction

SPR-016 is **Research Discovery & Question Formation**. Its provisional golden path is:

```text
Topic → Problem Space → Background Research → Exploratory Search
→ Research Inbox → Candidate Reading / Annotation → Themes / Concepts
→ Known Findings → Contradictions → Research Gaps → Research Question v0
→ Further Search → Research Question v1+ → Research Direction
```

SPR-016 implementation is not started by this decision. Non-canonical topic/problem exploration, background research, literature search, Research Inbox work and local reasoning may proceed as a research track; production canonical mutation and Zotero/Drive/Notion connector writes remain prohibited.

## Consequences

- Research history is append/version/branch oriented rather than overwrite oriented.
- Reverse traceability is required from conclusions back to their project and problem.
- Corpus, analysis, finding and conclusion retain separate identities.
- SPR-015 safety closure remains a separate Gate from SPR-016 non-canonical exploration.
- This ADR authorizes no connector write, production mutation, schema migration or SPR-016 feature implementation.

<요약>

1. 연구 기록은 덮어쓰지 않고 버전·분기·연결·provenance로 보존한다.
2. 질문부터 결론까지 정방향·역방향 lineage와 corpus/analysis/finding/conclusion 분리를 채택한다.
3. SPR-015는 intake infrastructure이며, SPR-016은 별도 non-canonical discovery track이다.

기록 시각: 2026-09-26 (Asia/Seoul)
