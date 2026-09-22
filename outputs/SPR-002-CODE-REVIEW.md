# SPR-002 코드 검증 리뷰

경로: `C:\Users\USER\Documents\Codex\2026-09-21\project-research-automation-platform-rap-role\outputs\SPR-002-CODE-REVIEW.md`

대상: `v1.0.0-alpha.2` / 빌드 `20260921.002` / Zotero Read-Only Connector
검증 방식: 정적 코드 리뷰 (ZoteroConnector / SQLiteReader / WebApiReader / Normalizer / Models / tests) + 보고서·문서 대조
검증자: Claude (Opus 5)

---

## 1. 총평

보고서의 **안전성(read-only) 주장은 코드와 일치**합니다. 그러나 보고서의 **기능 커버리지 주장은 코드와 일치하지 않습니다.**

테스트 픽스처가 실제 Zotero 스키마와 다르게 단순화되어 있어, 실제 라이브러리에서만 드러나는 결함 4건이 테스트를 통과했습니다. 즉 **PASS는 픽스처에 대한 PASS이지 Zotero에 대한 PASS가 아닙니다.**

| 구분 | 판정 |
|---|---|
| Read-only 강제 (SQLite/Web API) | 일치 — 검증 통과 |
| 정규화 계약 대칭성 | **불일치** — SQLite와 Web API 결과가 다름 |
| 읽기 범위 완전성 | **불일치** — 페이지네이션 없음, 주석 누락 |
| 실 라이브러리 스키마 정합성 | **불일치** — 결함 2건 |
| 테스트 커버리지 | 과대 표기 — 7종 표기, 실제 스크립트 2개 |

---

## 2. 보고서 주장 vs 코드 대조

| # | 보고서 주장 | 코드 확인 | 판정 |
|---|---|---|---|
| 1 | `SQLITE_OPEN_READONLY`로만 연다 | `sqlite3_open_v2(..., flags=1, ...)` — 1 = SQLITE_OPEN_READONLY | ✅ 일치 |
| 2 | SELECT와 승인된 read-only PRAGMA만 허용 | 허용 정규식 + 쓰기 키워드 차단 정규식 2중, `prepare_v2` tail=NULL이라 다중문 무시 | ✅ 일치 |
| 3 | Web API reader는 GET만 생성 | 전 소스에서 `Method='GET'` 1건만 존재 | ✅ 일치 |
| 4 | 원격 endpoint에 HTTPS 강제 | `$uri.Scheme -ne 'https' -and -not $uri.IsLoopback` → throw | ✅ 일치 |
| 5 | Zotero write 미구현 | 쓰기 cmdlet·HTTP 메서드 없음 (테스트 정리용 `Remove-Item` 제외) | ✅ 일치 |
| 6 | 실 사용자 라이브러리 미사용 | 합성 픽스처 + mock transport만 사용 | ✅ 일치 |
| 7 | **두 결과는 동일한 모델로 정규화된다** | Web API 경로는 Annotations가 **항상 빈 배열** (§3-A3) | ❌ 불일치 |
| 8 | **annotation metadata 지원** | SQLite만 지원. Web API 미지원 | ❌ 불일치 |
| 9 | **Collections, items, item metadata 지원** | `limit=100` 고정, 페이지네이션 미구현 → 100건 초과 시 **무음 절단** (§3-A4) | ❌ 불일치 |
| 10 | **Library statistics 지원** | 위 절단으로 실 라이브러리 통계는 부정확 | ❌ 불일치 |
| 11 | `Library_ID` 미구현 | `$LibraryId`는 읽기 파라미터로 **구현되어 있음**. "쓰기 미구현"의 오기로 보임 | ⚠️ 문구 오류 |
| 12 | (docs) API 키는 환경변수명에서 조달 | 환경변수 읽는 코드 없음. 평문 `[string]` 파라미터뿐 | ❌ 문서-코드 괴리 |

---

## 3. 결함 목록

### A. 치명 (실 라이브러리에서 즉시 오작동)

| ID | 위치 | 내용 |
|---|---|---|
| **A1** | `ZoteroConnector.psm1:14` | **LibraryType 오판정.** `CASE WHEN i.libraryID IS NULL OR i.libraryID=0 THEN 'user' ELSE 'group'`. 실제 Zotero에서 개인 라이브러리는 `libraryID=1`이므로 **모든 개인 항목이 `group`으로 라벨링**됩니다. 픽스처는 `libraryID=NULL`이라 검출 불가. → `libraries` 테이블을 조인해 `type` 컬럼을 읽어야 합니다. |
| **A2** | `ZoteroConnector.psm1:20` | **첨부파일 행 중복.** `LEFT JOIN itemData d ON d.itemID=i.itemID` 가 첨부의 *모든* 필드 행과 조인되고, title 필터는 `fields` 쪽 ON 절에만 걸려 행을 걸러내지 못합니다. 실제 첨부는 `title`·`url`·`accessDate` 등 여러 itemData 행을 가지므로 **첨부 1개가 N개로 복제**되고 Title이 공백이 될 수 있습니다. 픽스처는 첨부당 itemData 1행이라 검출 불가. → `d.fieldID = (SELECT fieldID FROM fields WHERE fieldName='title')` 로 조인 조건을 옮겨야 합니다. |
| **A3** | `Normalizer.psm1:50` ↔ `ZoteroConnector.psm1:60` | **Web API 주석 항상 누락.** Normalizer는 첨부 객체의 `children`에서 annotation을 찾지만, 커넥터는 *최상위 아이템*의 children만 GET하고 첨부의 children은 GET하지 않습니다. → Web API 경로의 `Annotations`는 언제나 `@()`, `AnnotationSummary.Count`는 언제나 0. 보고서 §"두 결과는 동일한 모델" 주장이 깨집니다. `ConnectorTests.ps1`에 해당 단언이 없어 검출 불가. |
| **A4** | `ZoteroConnector.psm1:57,60,88` | **페이지네이션 미구현.** `limit=100` 고정, `start` 파라미터·`Link: next` 추적 없음. 100건 초과 라이브러리는 **오류 없이 조용히 잘립니다.** 통계값도 함께 틀립니다. |

### B. 중요

| ID | 위치 | 내용 |
|---|---|---|
| **B1** | `Normalizer.psm1:61` | Zotero API는 부모 없는 컬렉션에 `parentCollection: false`를 반환. `[string]$false` = `"False"` 가 되어 `ParentCollectionKey`에 문자열 `"False"`가 들어갑니다. 테스트가 `CollectionKey`만 단언해 통과. |
| **B2** | `Normalizer.psm1:53` | `-StorageRoot` 미지정 시 Path가 `storage:paper.pdf`로 남고, `Test-Path -LiteralPath 'storage:paper.pdf'` 가 호출됩니다. Windows에서 잘못된 드라이브 지정자로 해석되어 `$ErrorActionPreference='Stop'` 하에 **예외로 승격될 수 있습니다.** `Get-RapZoteroLibraryStatistics`는 StorageRoot 파라미터 자체가 없어 이 경로에 항상 진입합니다. → `-ErrorAction SilentlyContinue` 필요. |
| **B3** | `ZoteroConnector.psm1:22–26` | **O(N×M) 성능.** 아이템 루프마다 fields·creators·tags·collections·notes·attachments 전체 배열을 `Where-Object`로 선형 스캔합니다. 5,000 아이템 × 50,000 필드 행 ≈ **2.5억 회 비교**. → ItemId 기준 해시테이블을 1회 구축해야 합니다. |
| **B4** | `ZoteroConnector.psm1:13–21` | `-ItemKey` 필터가 `items` 쿼리에만 적용되고 나머지 7개 쿼리는 **라이브러리 전체를 읽습니다.** 단건 조회가 전체 스캔이 됩니다. |
| **B5** | `SQLiteReader.psm1:27` | `sqlite3_open_v2` 실패 시 `try/finally` 진입 *전에* throw하므로 **DB 핸들이 누수**됩니다. SQLite 규약상 open 실패 시에도 핸들은 반드시 `close_v2` 해야 합니다. |
| **B6** | `ZoteroConnector.psm1:14,84` | items·collections 쿼리에 `libraryID` 필터가 없어, 그룹 라이브러리가 있으면 **개인 라이브러리 결과에 섞입니다.** |

### C. 경미

| ID | 위치 | 내용 |
|---|---|---|
| C1 | `Normalizer.psm1:29,31,32` | `Get-RapZoteroValue`가 "속성 존재 + 값 null" 시 Default를 반환하지 않습니다. `$null \| ForEach-Object`는 1회 실행되므로 **전 필드가 null인 유령 creator/tag**가 생성됩니다. |
| C2 | `ZoteroConnector.psm1:8` | `-match '^[A-Z0-9]{8}$'` — .NET `$`는 말미 개행 앞에서도 매칭되고, PowerShell `-match`는 기본 대소문자 무시입니다. 인용부호가 차단되므로 현재 주입은 불가하나, `\z` 앵커 + `-cmatch` 권장. 근본적으로는 **문자열 보간 대신 `sqlite3_bind_*` 파라미터 바인딩**이 맞습니다. |
| C3 | `ZoteroConnector.psm1:109` | `$items`가 비면 `Annotations`가 `0`이 아니라 `$null`이 됩니다. |
| C4 | `ZoteroConnector.psm1:108` | `$collectionParameters.Remove('StorageRoot')` — 해당 함수에 `StorageRoot` 파라미터가 없어 **사문(dead code)** 입니다. |
| C5 | `ZoteroConnector.psm1:82,107,127` | `BusyTimeoutMilliseconds`에 `ValidateRange(0,60000)`가 `Get-RapZoteroItems`에만 있습니다. 나머지 3곳은 음수 허용. |
| C6 | `ZoteroConnector.psm1:83` | SQLite 분기에서 `DatabasePath` 공백 검사가 없습니다 (items 분기에는 있음). |
| C7 | `SQLiteReader.psm1:64` / `WebApiReader.psm1:36` | `catch { return $false }` — 전 예외를 삼켜 진단 정보가 소실됩니다. |
| C8 | `temp/` | `spr002-sample.db`, `spr002-sample-2175…db(+shm/wal)` 잔존. 정리 루프가 `finally` 밖이라 **테스트 실패 시 픽스처가 남습니다.** |
| C9 | `ZoteroConnector.psm1:49` 외 | `$ApiKey`가 평문 `[string]`이며 `$PSBoundParameters`를 통해 전파됩니다. `[securestring]` 또는 환경변수 직접 조달 권장. |

---

## 4. 테스트 커버리지 실사

보고서는 테스트 7종을 나열하나, 실제 파일은 2개(`ConnectorTests.ps1`, `SampleLibraryTests.ps1`)이며 Pester가 아닌 `throw` 기반 스크립트입니다. 커버리지 측정 없음.

| 보고서 테스트명 | 실제 검증 내용 | 공백 |
|---|---|---|
| SQLite read-only test | **정규식 가드**가 `DELETE`를 거부함을 확인 | READONLY **플래그 자체**가 쓰기를 막는지는 미검증. 가드를 우회해 `[Rap.ZoteroReadOnlySqlite]::Query`에 INSERT를 직접 넣어 `SQLITE_READONLY` 오류를 단언해야 합니다 |
| Web API GET-only test | `Method -ne 'GET'` 요청 0건 확인 | 유효 |
| Normalization contract test | 속성 15개 존재 여부만 확인 | **값**의 정확성, SQLite↔WebApi **동등성** 미검증 → A3·B1 통과 원인 |
| Synthetic sample-library test | 5행짜리 축약 스키마 | `libraries` 테이블 없음, 첨부당 itemData 1행 → **A1·A2 통과 원인** |
| End-to-end acceptance test | 상동 | 100건 초과 케이스 없음 → **A4 통과 원인** |

**추가 필요 테스트 5건**

1. `libraries` 테이블 포함 + `libraryID=1` 픽스처 → LibraryType `user` 단언
2. 첨부에 itemData 3행(title/url/accessDate) 부여 → 첨부 개수 정확히 2 단언
3. Web API mock에 첨부 children(annotation) 추가 → `AnnotationSummary.Count -eq 1` 단언
4. Mock transport 101건 반환 → 전건 수집 단언 (현재 실패해야 정상)
5. READONLY 플래그 직접 검증 (가드 우회 경로)

---

## 5. 권고 조치 순서

| 우선순위 | 항목 | 예상 규모 |
|---|---|---|
| P0 | A1 LibraryType, A2 첨부 중복 — 쿼리 수정 + 픽스처 보강 | 소 |
| P0 | A4 페이지네이션 (`start` 루프 + 429/Backoff 처리) | 중 |
| P1 | A3 Web API annotation 수집 + 계약 동등성 테스트 | 중 |
| P1 | B1 parentCollection, B2 Test-Path, B5 핸들 누수 | 소 |
| P2 | B3 해시테이블 인덱싱, B4 ItemKey 필터 전파 | 중 |
| P2 | C1 null coalescing, C5~C9 일관성·위생 | 소 |
| P3 | C2 파라미터 바인딩(`sqlite3_bind_*`) 도입 | 중 |

**보고서 수정 권고**: §"지원 읽기 범위"에서 annotation metadata를 *SQLite 한정*으로 명시하고, Web API 경로에 100건 제한을 명기해야 합니다. §"구현"의 "두 결과는 동일한 모델로 정규화된다"는 A3 수정 전까지 사실이 아닙니다.

**추가 운영 리스크(미검증)**: Zotero 실행 중에는 `zotero.sqlite`가 WAL 모드로 잠겨 있어, 읽기 전용 open이 `-wal`/`-shm` 쓰기 권한을 요구해 실패할 수 있습니다. SPR-003 전에 "Zotero 구동 중 읽기" 시나리오를 실측해야 합니다.

---

<요약>

**단계별 절차**

1. SPR-002-REPORT.md 및 프로젝트 트리 확보 → 폴더 접근 승인
2. 커넥터 소스 5종·모델 3종·테스트 2종·문서 2종 스테이징 후 정독
3. 보고서 주장 12개 항목을 코드와 1:1 대조
4. 실 Zotero 스키마 기준으로 SQL 쿼리 정합성 검사
5. 테스트 픽스처가 은폐한 결함 역추적
6. 결함 19건을 치명/중요/경미로 분류, 조치 순서 산출

**핵심 결론**

- Read-only 안전성 주장 6건: **전부 사실**. 쓰기 경로 없음 확인.
- 기능 커버리지 주장 4건: **사실과 다름**. 치명 결함 4건(A1 LibraryType 오판, A2 첨부 중복, A3 Web API 주석 누락, A4 100건 절단)이 실제 라이브러리에서 오작동합니다.
- 원인은 공통: **테스트 픽스처가 실제 Zotero 스키마보다 단순**해 결함을 은폐했습니다. PASS의 신뢰도가 낮습니다.
- 총 결함 19건 (치명 4 / 중요 6 / 경미 9). P0 3건 선처리 권고.

기록일: 2026-09-21
