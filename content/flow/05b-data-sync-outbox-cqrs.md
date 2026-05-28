---
title: 데이터가 정확히 흐르는 길 (Outbox · 복제 · 순서)
---

# 데이터가 정확히 흐르는 길 (Outbox · 복제 · 순서)

앞 장(`05-async-event-flow`)에서 Kafka로 이벤트를 흘려 보냈습니다. 그런데 "흘려 보낸다"는 말은 생각보다 까다롭습니다. **DB는 커밋됐는데 Kafka 발행은 실패**하거나, **같은 편지가 두 번 도착**하거나, **나중 편지가 먼저 도착**하면 어떻게 될까요? 이 장은 그 안전망 — Outbox 패턴·읽기모델 복제·순서 보장 — 을 비유 한 줄과 그림으로 잡아 줍니다.

> 💡 **개념: CQRS / Outbox / 결과적 일관성**
> - **CQRS** = 쓸 때 쓰는 표(주방)와 읽을 때 쓰는 표(메뉴판)를 분리. *Kafka와는 별개 개념입니다.*
> - **Transactional Outbox** = DB 커밋과 Kafka 발행이 따로 노는 문제(dual-write)를 막는 패턴.
> - **결과적 일관성** = 잠깐 어긋났다가 곧 맞춰지는 상태. 분산 시스템의 기본 모드.

## 1. "Kafka로 다 하면 안 돼요?" — 동기화 4단계 사다리

직관과 달리, **모든 데이터 맞춤을 Kafka로 할 필요는 없습니다.** 가장 싼 수단부터 골라 쓰고, Kafka는 사다리 맨 위에만.

| 단계 | 방법 | 언제 | Kafka? |
|---|---|---|---|
| L0 | DB **VIEW** (조회 시 조합) | 단순 조합으로 충분 | ❌ |
| L1 | **같은 트랜잭션 프로젝션 UPSERT** | 강한 일관성, 같은 서비스 (예: `total_xp`) | ❌ |
| L2 | **Spring Modulith 사내 이벤트** | 같은 서비스 안 모듈 간 비동기 | ❌ |
| L3 | **Outbox → Kafka → consumer** | **서비스 경계를 넘을 때만** | ✅ |

> **한 줄 규칙**: Kafka는 *서비스 사이*의 우편이다. *서비스 안*의 표 맞추기엔 쓰지 마라.

## 2. dual-write 문제와 Outbox 패턴

"DB 저장 + Kafka 발행"을 따로 호출하면 둘 중 하나만 성공하는 순간이 반드시 생깁니다(→ 이벤트 유실 또는 유령 이벤트). 해결은 발상의 전환입니다: **같은 트랜잭션으로 `outbox_event` 테이블에만 적재 → 별도 Relay가 발송**.

```mermaid
flowchart LR
    A[도메인 서비스<br/>한 트랜잭션] -->|UPDATE +<br/>outbox INSERT| DB[(outbox_event)]
    DB -->|@Scheduled +<br/>ShedLock 단일 폴링| R[Polling Relay]
    R -->|Avro body +<br/>CloudEvents 헤더| K[Kafka]
    R -->|성공| ST[status=PUBLISHED]
    R -->|실패| RT[retry+backoff<br/>한도 초과 → DEAD]
```

- 발행 서비스는 **Kafka를 직접 호출하지 않는다.** 같은 `@Transactional` 안에서 `outbox_event`만 적재.
- **Polling Relay**가 `FOR UPDATE SKIP LOCKED`로 PENDING 행을 꺼내 Kafka로 발송. 단일 활성(ShedLock)이 기본값.
- 발송 후 `PUBLISHED` 표시. 실패는 지수 백오프 → 한도 초과 시 `DEAD`(알람).

## 3. 서비스 간 복제: A의 데이터를 B가 사본으로 갖기

B 서비스가 A의 데이터를 자주 조인/필터해야 하면 **읽기 전용 복제본**(예: `engagement-svc`의 `user_ref`)을 둡니다. 원칙은 셋:

- **주인은 하나**(Source of Truth). 복제본은 절대 직접 수정 금지.
- 이벤트엔 **상태 전체 + version**을 실어 보낸다(얇은 ID-only 후 콜백 ❌ — 결합도·부하·경쟁상태).
- 소비측은 **멱등(processed_events) + version 가드 upsert**:

```sql
INSERT INTO user_ref (user_id, display_name, version, synced_at)
VALUES (:id, :name, :ver, now())
ON CONFLICT (user_id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    version      = EXCLUDED.version,
    synced_at    = now()
WHERE EXCLUDED.version > user_ref.version   -- ★ 더 최신 도장만 반영
```

이 한 줄이 **순서 역전·중복 모두를 방어**합니다.

## 4. 파티션 키 표준 = `테넌트ID : 대상ID`

Kafka는 같은 파티션 안에서만 순서를 보장합니다. **순서를 지킬 단위 = 파티션 키**입니다. SYNAPSE는 모든 토픽에서 **`{tenant_id}:{aggregate_id}`** 를 표준 키로 씁니다.

- 테넌트 단독 키 → 핫 파티션·병렬성 제약. 폐기.
- 대상까지 붙임 → 같은 대상의 이벤트는 늘 같은 파티션 → 순서 유지 + 파티션 분산.
- 다중 Relay 병렬 처리에서도 같은 키 → 같은 파티션 → 순서 보존.

## 5. 와이어 포맷: 처음부터 Avro로

운영 사고를 막기 위해 **처음부터 Avro + Schema Registry**입니다. "JSON으로 시작했다가 Avro로 전환"은 안티패턴(18 §5.5)입니다. 헷갈리지 마세요:

- `outbox_event.payload` **(JSONB)** — 사람이 읽기 쉽게 저장. 장애 시 바로 조사 가능.
- **Kafka 와이어** — 항상 Avro 도메인 레코드(body) + CloudEvents binary 헤더(`ce_*`).
- 변환은 `OutboxMessageFactory`가 발송 시점에 수행 (03-A §A.10.3).

## 6. 최종 안전망: "더 최신만 반영"

브로커/Relay의 순서 보장은 *최적화*이고, **정합성은 소비측 version 가드에서 옵니다.** 위 §3의 `WHERE EXCLUDED.version > 현재` 한 줄이 진짜 보험입니다. 순서가 어긋나도 결과는 항상 최신으로 수렴.

## 다음 읽을거리

**정식 데이터·운영 문서**
- [02_ERD §2.3.A 이벤트 발행·복제 인프라 테이블](https://github.com/team-project-final/documents/wiki/02_ERD_문서) — `outbox_event`/`user_ref` DDL · 인덱스 · 데이터 흐름
- [03-A §A.10~A.11 Outbox · Relay · 복제 · 순서보장](https://github.com/team-project-final/documents/wiki/03-A_통신_운영_상세서) — 운영 코드와 규칙(`OutboxMessageFactory`/멱등 처리/Kafka 설정 포함)
- [18 §5.4~5.6 Kafka · Avro · Schema Registry](https://github.com/team-project-final/documents/wiki/18_기술_스택_정의서) — 표준 설정(직렬화·파티션 키·ShedLock)

**결정 배경 (ADR)**
- ADR-0002 — 왜 Kafka + Avro + Outbox 인가
- ADR-0003 — 왜 schema-per-service 인가

**비유 기반 풀버전 가이드**
- 워크스페이스 루트의 `Outbox-데이터동기화-신입가이드.html` — 우편함(편지함)·집배원·규격상자·도장 비유로 같은 내용을 더 풍부하게 풀어 둔 단독 HTML 가이드.
