# SPR-015 Research Intake Golden Path Requirements

> 문서 경로: `docs/SPR-015-REQUIREMENTS.md`
> 기록일: 2026-09-26 (Asia/Seoul)
> 상태: **REQUIREMENTS APPROVED / IMPLEMENTATION NOT STARTED**
> 제품 목표: **ONE-PAPER ZERO-DUPLICATE RESEARCH INTAKE PILOT**

## 1. 범위와 권한

이 문서는 SPR-015 및 후속 SPR-015R의 제품 요구사항 인계서다. 구현, 외부 시스템 쓰기, 스키마 마이그레이션, Production Write 활성화를 승인하지 않는다.

- SPR-014 Turn D Final Gate는 PASS했으며, 별도 명령 전에는 SPR-015 구현을 시작하지 않는다.
- SPR-015와 SPR-015R은 아직 시작하지 않았다.
- 기존 Safety, Ownership, Reconciliation, HUMAN_OWNED, ResearcherConfirmed 보호 정책을 모두 상속한다.
- AMBIGUOUS, PDF_AMBIGUOUS, PDF_MISMATCH는 자동 확정·병합·승격할 수 없다.

## 2. 제품 시작점과 목표 흐름

RAP의 시작점은 Zotero가 아니라 **Research Question**이다.

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

검색 결과, Zotero item, Library item, Paper Review는 서로 다른 객체다. 검색 결과는 연구자가 명시적으로 PROMOTE하기 전까지 canonical research asset이 아니다.

## 3. 단일 Research Search Pipeline

하나의 파이프라인이 두 검색 모드를 지원해야 한다.

| 모드 | 목적 | 최소 방향 |
|---|---|---|
| Quick Search | 중요한 관련 논문을 빠르게 탐색 | 자연어 연구 질문, 후보 결과, Research Inbox |
| Systematic Search | 재현 가능한 체계적 검색 | PICO/PICOS, 포함·배제 기준, 연구설계, 기간, 데이터베이스, 재현 가능한 query |

Quick Search 프로젝트는 동일한 `Project_ID`와 discovery history를 유지한 채 Systematic Search로 승격할 수 있어야 한다. 별도 검색 시스템을 만들거나 기존 이력을 버리면 안 된다.

## 4. Research Inbox와 PROMOTE 경계

- 검색 결과는 먼저 Research Inbox candidate로 저장한다.
- candidate 단계에서 Zotero item, Library item, Drive canonical PDF, Paper Review를 자동 생성하지 않는다.
- canonicalization 진입은 연구자의 명시적 PROMOTE 결정이 있어야 한다.
- 연구자 결정, 결정 시각, 후보와 프로젝트의 연결을 감사 가능한 provenance로 남겨야 한다.
- PROMOTE 전 candidate는 production mutation capability를 받을 수 없다.

## 5. Canonical paper identity

Identity resolution 우선순위는 다음 방향을 따른다.

1. normalized DOI
2. PMID, PMCID 등 strong external identifier
3. publisher/source identity
4. normalized title + author + year
5. fuzzy candidate
6. AMBIGUOUS → HUMAN REVIEW

Title 문자열 단독 또는 fuzzy match는 자동 merge, 자동 REUSE, 자동 canonicalization 권한이 아니다. 증거가 불충분하거나 충돌하면 fail closed한다.

## 6. Pre-Zotero deduplication

기본 순서는 다음과 같다.

```text
Identity Resolution
→ Existing canonical paper lookup
→ Existing Zotero lookup
→ CREATE or REUSE
```

Zotero parent item을 먼저 생성한 뒤 중복을 정리하는 흐름을 기본값으로 삼지 않는다. 목표 불변식은 `one paper → one canonical identity → one Zotero parent item`이다.

## 7. Stateful PDF acquisition

PDF 획득은 단일 다운로드 시도가 아니라 상태를 가진 workflow여야 한다.

```text
PDF_REQUIRED
→ approved acquisition route
→ success or failure
→ approved fallback route
→ MANUAL_REQUIRED
```

- 다운로드 성공은 identity verification 성공을 뜻하지 않는다.
- 허용된 획득 경로, 시도 결과, 오류, fallback, 수동 조치 필요 상태를 기록한다.
- 자동 우회나 출처가 불명확한 PDF 채택은 금지한다.

## 8. PDF identity verification

Canonical PDF 승격 전에 가능한 범위에서 DOI, title, authors, year, journal/source, strong external identifier를 대조한다.

| 상태 | 의미 | 자동 canonicalization |
|---|---|---:|
| `PDF_VERIFIED` | 대상 논문과 충분히 일치 | 후속 gate 조건 충족 시 가능 |
| `PDF_PROBABLE` | 상당한 근거가 있으나 완전 검증 아님 | 정책 명세 전 금지 |
| `PDF_AMBIGUOUS` | 둘 이상의 후보 또는 불충분한 증거 | 금지 |
| `PDF_MISMATCH` | 대상 논문과 불일치 | 금지 |
| `PDF_MISSING` | PDF 없음 | 금지 |

PDF hash는 파일 동일성 증거로 보존하되, 서지 identity를 단독으로 증명하지 않는다.

## 9. Library_ID와 Paper Review

- Paper Review는 PROMOTE되고 canonical identity와 canonical PDF gate를 통과한 논문에만 생성한다.
- 목표 불변식은 `one canonical paper → one Library_ID → one Paper Review`이다.
- candidate마다 Paper Review를 만들지 않는다.
- ResearcherConfirmed와 HUMAN_OWNED content는 AI 또는 자동화가 덮어쓸 수 없다.
- 기존 canonical paper, Library_ID, Review가 있으면 새로 만들지 않고 안전한 REUSE 여부를 판정한다.

## 10. Discovery lineage 최소 필드

향후 설계는 최소한 다음 provenance를 보존해야 한다.

| 필드 | 목적 |
|---|---|
| `Discovery_ID` | 검색 발견의 안정 식별자 |
| `Project_ID` | 연구 프로젝트 범위 |
| `Search_Mode` | Quick 또는 Systematic |
| `Source` | 검색 출처 |
| `Query` | 실행 검색식 또는 자연어 질문 |
| `Search_Date` | 검색 시각 |
| `Rank` | 결과 순위 |
| `DOI`, `PMID` | 수집 당시 식별자 |
| `Retrieved_Metadata` | 원본 수집 metadata와 provenance |
| `Screening_Status` | screening 상태 |
| `Screening_Reason` | 포함·배제 또는 보류 근거 |
| `Researcher_Decision` | PROMOTE 등 명시적 연구자 결정 |

필수 lineage는 `Search → Discovery → Screening → Inclusion → Canonical Paper → Review`이다. Systematic Search 승격 시 기존 discovery history를 유지한다.

## 11. SPR-015 one-paper golden path

SPR-015는 실제 논문 한 편만 대상으로 다음 E2E 흐름을 검증한다.

```text
Research Question
→ Search
→ Candidate results
→ Research Inbox
→ Researcher selects/promotes ONE paper
→ Canonical Identity
→ Dedup Gate
→ Zotero CREATE or REUSE
→ PDF Acquisition
→ PDF Identity Verification
→ Drive Canonical PDF
→ Library_ID
→ Paper Review
→ Researcher Review
→ ResearcherConfirmed
```

모든 외부 쓰기는 별도 명세와 승인, SPR-014 Final Gate 이후의 통제된 capability, 적용 직전 재검증, read-back verification을 요구한다.

## 12. 성공 KPI와 수동 작업 측정

| 지표 | 목표 |
|---|---:|
| Duplicate Zotero item | 0 |
| Wrong-paper PDF | 0 |
| Duplicate canonical PDF | 0 |
| Duplicate Paper Review | 0 |
| Canonical identity | 1 |
| Library_ID | 1 |
| Canonical PDF | 1 |
| Paper Review | 1 |
| Ambiguous auto-resolution | 0 |
| ResearcherConfirmed change | 0 |

추가 생산성 KPI로 `manual interventions per paper`를 정수로 기록한다. 각 수동 단계의 유형, 원인, 소요 경계와 반복 여부를 남겨 향후 불필요한 반복작업을 줄인다.

## 13. SPR-015R hardening backlog

SPR-015R은 one-paper golden path 이후 별도 명세로 다음을 검증한다: duplicate, restart, retry, PDF missing, PDF mismatch, DOI missing, metadata conflict, Notion duplicate, Drive duplicate, Zotero duplicate, partial failure, lineage break.

이 목록은 SPR-015 Turn A의 구현 범위를 자동으로 확장하지 않는다.

## 14. 구현 전 필수 결정과 외부 구성

- Quick/Systematic 검색 source와 각 source의 사용·저장 권한
- Research Inbox의 authoritative store와 schema
- researcher identity 및 PROMOTE 승인 provenance
- DOI/PMID/publisher normalization 규칙과 identity evidence threshold
- 합법적이고 승인된 PDF acquisition route와 fallback 순서
- Zotero CREATE/REUSE, Drive canonical location, Notion Paper Review의 정확한 production target
- Project_ID 생성·선택 권한과 누락 시 처리
- Production Write의 별도 승인 범위와 rollback/recovery 운영 절차

구성이 없거나 권한을 확인할 수 없으면 `TEST_DEFERRED` 또는 `MANUAL_REQUIRED`로 남기며 PASS로 바꾸지 않는다.

## 15. 비범위

현재 문서화 작업에는 검색 엔진, Research Inbox, canonical identity resolver, PDF acquisition, Zotero/Drive/Notion production adapter, schema migration, SPR-015/SPR-015R test implementation이 포함되지 않는다.

<요약>

1. SPR-015는 Research Question에서 시작하고 검색 후보를 Research Inbox에 보관한다.
2. 연구자의 PROMOTE 이후에만 identity resolution, dedup, Zotero CREATE/REUSE, PDF 검증, Library_ID, Paper Review로 진행한다.
3. 모호한 identity와 PDF는 자동 확정하지 않으며 ResearcherConfirmed를 보호한다.
4. SPR-015는 논문 한 편 golden path, SPR-015R은 장애·중복·재시작 hardening을 별도로 수행한다.
5. 현재 상태는 요구사항 문서화 완료이며 구현은 시작하지 않았다.

기록 시각: 2026-09-26 (Asia/Seoul)
