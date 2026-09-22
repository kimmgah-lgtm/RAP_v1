# SPR-003 완료 보고서

- 버전: `v1.0.0-alpha.3`
- 빌드: `20260921.003`
- 대상: Transactional Write Layer
- 안전 경계: verified Zotero Sandbox group only

## 구현 범위

Library_ID, Extra, `rap:` system tag, collection membership, allowlisted metadata, linked attachment 명령을 구현했다. 모든 명령은 Validate, Execute, Verify, Rollback 계약을 가지며 transaction engine을 통해서만 실행된다.

파이프라인은 validation, dry-run, snapshot, write, verification, commit, audit 순서다. 검증 실패 시 snapshot 기반 rollback, error queue, human review 상태와 `RollbackExecuted` event를 생성한다.

## 안전성

- Write Layer 기본값은 disabled이다.
- `groups` 유형이며 이름에 `Sandbox`가 포함된 라이브러리만 context 생성이 가능하다.
- 실제 Zotero SQLite에는 쓰지 않는다.
- rollback 제거는 동일 OperationID가 생성한 요소만 허용한다.
- 기존 item, attachment, collection, tag 삭제 API는 없다.
- 실제 Zotero 또는 운영 라이브러리는 테스트에 사용하지 않았다.

## 검증 시나리오

1. Library_ID write → verify → commit
2. 기존 Library_ID → no write → ALREADY_EXISTS
3. verification failure → rollback
4. invalid item → validation failure → error queue
5. dry-run → no changes
6. production library name → context creation refused
7. repeated OperationID → idempotent result

상세 정책은 `docs/SPR-003.md`와 Accepted ADR-002에 기록했다.

