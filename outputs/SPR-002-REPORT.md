# SPR-002 완료 보고서

## 결과

- 상태: PASS
- 플랫폼: `v1.0.0-alpha.2`
- 빌드: `20260921.002`
- 범위: Zotero Read-Only Connector

## 구현

플랫폼은 `ZoteroConnector.psm1` facade만 호출한다. facade 뒤에서 SQLite 또는 Web API reader를 선택하며, 두 결과는 동일한 Item·Attachment·Collection 모델로 정규화된다. SQLite 스키마와 Web API 원본 형상은 플랫폼에 노출되지 않는다.

SQLite 연결은 `SQLITE_OPEN_READONLY`로만 열리며 SELECT와 승인된 read-only PRAGMA만 허용한다. Web API reader는 GET 요청만 생성하고 원격 endpoint에는 HTTPS를 강제한다. Zotero write, `Library_ID`, Google Drive, Notion 기능은 구현하지 않았다.

## 지원 읽기 범위

- Collections, items, item metadata
- Creators, tags, Extra, notes
- Attachments, child items, annotation metadata
- Linked attachment detection and storage path discovery
- Library statistics

## 테스트

- Unit test
- Connector test
- SQLite read-only test
- Web API GET-only test
- Normalization contract test
- Synthetic sample-library test
- End-to-end acceptance test

실제 사용자 Zotero 라이브러리는 테스트에 사용하거나 수정하지 않는다.

## 아키텍처 제안

PowerShell facade를 compiled .NET interface로 바꾸는 개선안은 구현하지 않고 `docs/adr/ADR-001-typed-zotero-connector-interface.md`에 Proposed ADR로만 기록했다.

