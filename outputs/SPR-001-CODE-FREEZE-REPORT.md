# SPR-001/SPR-001.1 코드 프리즈 보고서

- 프로젝트: Research Automation Platform (RAP)
- 범위: `ResearchAutomation.Local` Platform Bootstrap
- 기준일: 2026-09-21
- 플랫폼 버전: 1.0.0-alpha.1
- 빌드: 20260921.001
- 판정: **조건부 승인(Conditional Go)**
- 회귀 테스트: **PASS** (`tools/Invoke-Tests.ps1`, 종료 코드 0)
- PowerShell 구문 검사: **PASS** (오류 0)

SPR-001.1 승인 후 semantic version, build number, capability registry와 대시보드 표시를 추가했다. 공개 함수 9개의 정식 comment-based help는 유지된다.

## 1. 저장소 트리

아래 트리는 소스 관리 대상과 코드 프리즈 보고서를 포함한다. 실행 과정에서 생성되는 `logs/rap-YYYY-MM-DD.*`와 `queue/queue.db*`는 `.gitignore` 대상이므로 별도로 표시했다.

```text
rap-platform/
├── .gitignore
├── CHANGELOG.md
├── LICENSE
├── README.md
├── ROADMAP.md
├── docs/
│   ├── ARCHITECTURE.md
│   ├── INSTALLATION.md
│   ├── SPR-001.md
│   └── SPR-001.1.md
├── outputs/
│   └── SPR-001-CODE-FREEZE-REPORT.md
├── src/
│   └── Local/
│       └── ResearchAutomation.Local/
│           ├── Install.ps1
│           ├── ResearchAutomation.Local.psd1
│           ├── ResearchAutomation.Local.psm1
│           ├── Run-Agent.ps1
│           ├── config/
│           │   └── config.json
│           ├── logs/
│           │   └── .gitkeep
│           ├── modules/
│           │   ├── Config.psm1
│           │   ├── Logger.psm1
│           │   ├── Queue.psm1
│           │   └── SelfTest.psm1
│           ├── queue/
│           │   └── .gitkeep
│           ├── temp/
│           │   └── .gitkeep
│           └── tests/
│               └── Bootstrap.Tests.ps1
├── tests/
│   └── Bootstrap.Tests.ps1
└── tools/
    └── Invoke-Tests.ps1
```

런타임 생성물:

```text
src/Local/ResearchAutomation.Local/logs/rap-YYYY-MM-DD.log
src/Local/ResearchAutomation.Local/logs/rap-YYYY-MM-DD.jsonl
src/Local/ResearchAutomation.Local/queue/queue.db
src/Local/ResearchAutomation.Local/queue/queue.db-wal   # WAL 활성 시
src/Local/ResearchAutomation.Local/queue/queue.db-shm   # WAL 활성 시
```

## 2. 파일 목록과 책임

| 파일 | 책임 |
|---|---|
| `.gitignore` | 로그, SQLite 런타임 파일, 임시 파일 제외 |
| `README.md` | 요구사항, 빠른 시작, 문서 진입점 |
| `CHANGELOG.md` | 0.1.0 및 1.0.0-alpha.1 변경 이력 |
| `ROADMAP.md` | SPR-001 완료 범위와 후속 범위 경계 |
| `LICENSE` | MIT 라이선스 |
| `docs/ARCHITECTURE.md` | 로컬 모듈 구성과 의존 방향 |
| `docs/INSTALLATION.md` | 설치, 실행, 설정 안내 |
| `docs/SPR-001.md` | 스프린트 목표, 산출물, 제외 범위, 인수 기준 |
| `docs/SPR-001.1.md` | 버전, 빌드 번호, capability registry 기준 |
| `src/Local/ResearchAutomation.Local/Install.ps1` | 폴더·설정·로거·SQLite 초기화 및 설치 검증 |
| `src/Local/ResearchAutomation.Local/Run-Agent.ps1` | 구성 루트, 초기화, 셀프 테스트, 대시보드 출력 |
| `src/Local/ResearchAutomation.Local/ResearchAutomation.Local.psd1` | 모듈 메타데이터와 공개 API 선언 |
| `src/Local/ResearchAutomation.Local/ResearchAutomation.Local.psm1` | 구성 모듈 로드와 공개 API 재노출 |
| `src/Local/ResearchAutomation.Local/config/config.json` | 로컬 경로, 로깅, SQLite timeout 설정 |
| `src/Local/ResearchAutomation.Local/modules/Config.psm1` | 설정 생성·검증·안전한 경로 해석 |
| `src/Local/ResearchAutomation.Local/modules/Logger.psm1` | 일 단위 plain/JSONL 로그 기록 |
| `src/Local/ResearchAutomation.Local/modules/Queue.psm1` | Windows SQLite 바인딩, 스키마 초기화·검증 |
| `src/Local/ResearchAutomation.Local/modules/SelfTest.psm1` | 7개 상태 검사와 버전·빌드·capability 대시보드 렌더링 |
| `src/Local/ResearchAutomation.Local/tests/Bootstrap.Tests.ps1` | 독립 프로세스 기반 설치·에이전트 인수 테스트 |
| `tests/Bootstrap.Tests.ps1` | 저장소 루트 테스트 진입점 |
| `tools/Invoke-Tests.ps1` | 운영자용 전체 테스트 실행기 |
| `logs/.gitkeep`, `queue/.gitkeep`, `temp/.gitkeep` | 빈 런타임 디렉터리 구조 유지 |

## 3. 공개 PowerShell API 및 도움말

매니페스트와 루트 모듈이 동일한 9개 함수만 공개한다. `Get-Help <함수명> -Full`로 모든 함수의 Synopsis, Description, 전체 선언 파라미터 및 Outputs가 노출됨을 검증했다.

### `Get-RapConfiguration`

```powershell
Get-RapConfiguration -Path <string> -ApplicationRoot <string>
```

- 요약: RAP 로컬 설정을 로드하고 검증한다.
- `Path`: 설정 JSON 파일 경로.
- `ApplicationRoot`: 상대 데이터 경로 해석의 보안 경계가 되는 절대 경로.
- 출력: 검증된 설정과 해석된 경로를 담은 `PSCustomObject`.

### `Initialize-RapConfiguration`

```powershell
Initialize-RapConfiguration -ApplicationRoot <string>
```

- 요약: 설정이 없을 때 기본 파일을 만들고 기존 파일은 보존한다.
- `ApplicationRoot`: 로컬 애플리케이션 디렉터리의 절대 경로.
- 출력: 검증된 설정 `PSCustomObject`.

### `Initialize-RapLogger`

```powershell
Initialize-RapLogger -Directory <string> [-PlainEnabled <bool>] [-JsonEnabled <bool>]
```

- 요약: 일 단위 RAP 로깅을 초기화한다.
- `Directory`: 로그 출력 디렉터리.
- `PlainEnabled`: plain 로그 활성화 여부.
- `JsonEnabled`: JSONL 로그 활성화 여부.
- 출력: 활성 로거 설정 `PSCustomObject`.

### `Write-RapLog`

```powershell
Write-RapLog -Level <string> -Message <string> [-Data <hashtable>]
```

- 요약: 활성화된 일 단위 로그에 이벤트 한 건을 기록한다.
- `Level`: `Debug`, `Information`, `Warning`, `Error` 중 하나.
- `Message`: 사람이 읽을 수 있는 이벤트 메시지.
- `Data`: JSONL 레코드에 포함할 선택적 구조화 속성.
- 출력: 없음.

### `Initialize-RapQueue`

```powershell
Initialize-RapQueue -DatabasePath <string> [-BusyTimeoutMilliseconds <int>]
```

- 요약: 로컬 SQLite 큐와 필수 스키마를 멱등 초기화한다.
- `DatabasePath`: SQLite DB 파일 경로.
- `BusyTimeoutMilliseconds`: 잠금 대기 시간(0~60000ms).
- 출력: DB 절대 경로 문자열.

### `Invoke-RapQueueScalar`

```powershell
Invoke-RapQueueScalar -DatabasePath <string> -Sql <string> [-BusyTimeoutMilliseconds <int>]
```

- 요약: 신뢰된 스칼라 SQLite 질의를 실행한다.
- `DatabasePath`: SQLite DB 파일 경로.
- `Sql`: 내부 사용을 전제로 한 신뢰된 SQL 문장.
- `BusyTimeoutMilliseconds`: 잠금 대기 시간(0~60000ms).
- 출력: 첫 행 첫 열의 문자열 또는 행이 없을 때 null.

### `Test-RapQueue`

```powershell
Test-RapQueue -DatabasePath <string> [-BusyTimeoutMilliseconds <int>]
```

- 요약: SQLite 무결성과 필수 테이블 5개를 검사한다.
- `DatabasePath`: SQLite DB 파일 경로.
- `BusyTimeoutMilliseconds`: 잠금 대기 시간(0~60000ms).
- 출력: 모든 검사가 성공했는지를 나타내는 Boolean.

### `Invoke-RapSelfTest`

```powershell
Invoke-RapSelfTest -ApplicationRoot <string> -Configuration <object>
```

- 요약: 로컬 부트스트랩 상태 검사를 모두 실행한다.
- `ApplicationRoot`: 로컬 애플리케이션 디렉터리의 절대 경로.
- `Configuration`: `Get-RapConfiguration`이 반환한 검증된 설정.
- 출력: 전체 상태, 개별 검사, 타임스탬프를 담은 `PSCustomObject`.

### `Show-RapHealthDashboard`

```powershell
Show-RapHealthDashboard -Report <object>
```

- 요약: RAP 로컬 상태 대시보드를 표시한다.
- `Report`: `Invoke-RapSelfTest`가 반환한 상태 보고서.
- 출력: 없음. 호스트 콘솔에 렌더링한다.

비공개 함수는 `Resolve-RapDataPath`, `Initialize-RapSqliteProvider`, `New-RapCheck` 세 개이며 매니페스트에서 노출하지 않는다.

## 4. 코드 리뷰

### 4.1 아키텍처 — 양호

- `Run-Agent.ps1`가 composition root 역할만 수행하고 Config, Logger, Queue, SelfTest 책임이 분리되어 있다.
- 루트 모듈과 매니페스트의 export 목록이 일치하며 내부 helper는 비공개다.
- 설정 생성, 디렉터리 생성, 테이블·인덱스 생성이 모두 재실행 가능하다.
- 클라우드 Controller 및 제외 대상 통합 기능에 대한 변경이나 결합이 없다.
- 외부 PowerShell 패키지 없이 OS SQLite를 사용하여 설치 표면을 줄였다.

### 4.2 보안 — 보통

양호한 점:

- 구성 경로는 절대 경로를 거부하며 정규화 후 application root 이탈을 차단한다.
- 데이터베이스 경로와 로그 경로 처리에 `-LiteralPath` 또는 .NET 경로 API를 사용한다.
- 설정 파일에 비밀정보가 포함되지 않는다.
- SQL 스키마 초기화는 정적 문자열이며 외부 입력을 조합하지 않는다.

발견 사항:

1. **[중간] 공개 API가 임의 SQL 문자열을 실행할 수 있음** — `Invoke-RapQueueScalar`가 매니페스트에서 공개되고 SQL allowlist나 읽기 전용 검사를 하지 않는다. 함수명은 scalar query를 암시하지만 SQLite의 변경 문장도 전달할 수 있다. 현재 내부 호출은 상수 SQL만 사용하므로 SPR-001 실행 경로의 직접 취약점은 아니지만 최소 권한 원칙에는 맞지 않는다.
2. **[낮음] 구조화 로그 데이터에 대한 비밀정보 필터가 없음** — `Write-RapLog -Data`는 호출자가 준 값을 그대로 JSON 직렬화한다. 현재 호출은 DB 경로와 테스트 표식만 기록하지만 후속 스프린트에서 토큰이나 개인정보가 전달되지 않도록 호출 규약 또는 redaction 계층이 필요하다.
3. **[낮음] 런타임 파일 ACL을 별도로 강화하지 않음** — DB와 로그는 상속된 사용자 디렉터리 권한에 의존한다. 현재 데이터가 민감하지 않은 부트스트랩 범위에서는 허용 가능하다.

### 4.3 유지보수성 — 양호, 제한 사항 기록 필요

- 모든 PowerShell 파일이 StrictMode와 명시적 오류 정책을 사용한다.
- 공개 API 9개 모두 정식 comment-based help를 제공한다.
- 설정 스키마 버전과 값 범위 검증이 존재한다.
- 중복된 초기화 로직은 모듈 함수로 통합되어 있다.

발견 사항:

1. **[중간] SQLite 다중 문장 실행기가 세미콜론 문자로 단순 분리** — 현재 고정 DDL에는 안전하지만, 향후 문자열 리터럴·trigger·복잡한 migration SQL에 세미콜론이 들어가면 잘못 분리된다. 현 스프린트에서는 migration이 제외되어 실제 실패 경로가 아니다.
2. **[낮음] SelfTest 일부 예외를 삼켜 원인 정보가 사라짐** — SQLite 및 Logger probe의 `catch { }`는 최종 FAIL은 정확히 만들지만 상세 오류를 대시보드에 전달하지 않는다. 장애 분석 시 로그보다 정보가 부족할 수 있다.
3. **[낮음] Windows 전용 SQLite 결합** — `winsqlite3.dll` 사용은 README의 Windows 요구사항과 일치하지만 PowerShell 7 자체의 크로스플랫폼 이점은 사용하지 못한다.
4. **[정보] 현재 작업 디렉터리는 Git working tree로 초기화되어 있지 않음** — 파일 배치는 Git 친화적이지만 실제 커밋·태그 기반 코드 프리즈 증적은 아직 없다.

### 4.4 테스트 커버리지 — 부트스트랩 인수 기준 충족, 단위/실패 경로 부족

검증된 항목:

- 필수 폴더 존재
- 설정 schema version, SemVer, build number 로드
- capability registry 9개 항목과 Boolean 형식 확인
- 공개 모듈 명령 로드
- native SQLite query 실행
- `PRAGMA integrity_check`와 필수 테이블 5개 확인
- plain 및 JSONL 로그 쓰기
- 설치와 에이전트 실행의 독립 PowerShell 프로세스 검증
- 전체 PowerShell 파일 AST 구문 검사
- 이전 검증에서 테스트를 2회 연속 실행하여 멱등성 확인

미검증 항목:

- 잘못된 JSON, 누락 속성, root 이탈 경로 등 구성 실패 케이스
- 손상된 SQLite 파일, DB lock timeout, 동시 설치·실행
- 테이블별 column/constraint/index 상세 정의
- 로그 레코드 JSON schema, 개행·대용량·직렬화 실패, 날짜 경계 회전
- 파일 및 디렉터리 권한 오류
- native SQLite open/prepare/step 오류별 자원 해제
- PSScriptAnalyzer 정적 분석(PSScriptAnalyzer가 설치되지 않아 미실행)

현재 테스트는 SPR-001의 명시적 health check와 실행 가능성은 보장하지만 분기 또는 라인 커버리지 수치를 산출하지 않는다.

## 5. 기술 부채 등록부

| ID | 우선순위 | 항목 | 영향 | SPR-001 조치 |
|---|---|---|---|---|
| TD-001 | 중간 | 공개 `Invoke-RapQueueScalar`의 임의 SQL 허용 | 오용 시 DB 변경 가능 | 코드 프리즈 후 API 가시성/읽기 전용 정책 검토 |
| TD-002 | 중간 | SQL 문장 세미콜론 단순 분리 | 향후 복잡한 DDL/migration 실패 | migration 스프린트 전에 statement 처리 교체 |
| TD-003 | 낮음 | SelfTest probe 예외 상세 소실 | 장애 진단성 저하 | 검사 결과 Detail에 안전한 오류 요약 추가 검토 |
| TD-004 | 낮음 | 로그 민감정보 redaction 없음 | 후속 통합 시 정보 노출 가능 | 로깅 정책 수립 시 분류·마스킹 추가 |
| TD-005 | 낮음 | 실패·동시성·날짜 경계 테스트 부족 | 회귀 탐지 범위 제한 | 다음 테스트 강화 스프린트로 이관 |
| TD-006 | 정보 | Git 저장소/프리즈 태그 없음 | 변경 추적 증적 부족 | 저장소 소유자가 Git 초기화 및 태그 수행 |

기술 부채는 모두 문서화했으며 SPR-001 요구 기능을 차단하는 Critical/High 결함은 발견되지 않았다.

## 6. 최종 판정

SPR-001의 부트스트랩과 SPR-001.1의 버전·빌드·capability registry는 실행 검증을 통과했다. Cloud 구조와 제외 기능의 동작은 변경하지 않았다.

따라서 **SPR-001/SPR-001.1 코드는 조건부 프리즈 승인 가능**하다. 조건은 본 보고서의 중간 우선순위 기술 부채(TD-001, TD-002)를 후속 변경 전에 설계 검토하는 것이다. 현재 부트스트랩 배포를 막는 결함은 없다.
