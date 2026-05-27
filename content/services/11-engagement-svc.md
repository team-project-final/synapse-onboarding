---
title: engagement-svc 상세
---

# engagement-svc 상세

> 실제 레포 구조 기반 상세. 빠른 소개는 [03. 4개 서비스 소개], 연결 구조는 [14. 서비스 간 상호작용 지도].

사용자 **참여(engagement)** 도메인 — 커뮤니티 + 게임화. 두드러진 특성은 **이벤트 소비 중심**(다른 서비스의 활동을 보상으로 변환)과 **Redis Sorted Set 적극 활용**(리더보드·카운터)입니다.

## 모듈 구성

| 모듈 | 책임 |
|---|---|
| `community` | 스터디 그룹 CRUD·멤버 역할(OWNER/ADMIN/MEMBER)·초대·가입 승인, 덱/노트 공유(PUBLIC/GROUP/LINK + `share_token`), 신고(중복 1회·일 10건 제한) |
| `gamification` | XP 적립→레벨 판정, 배지 평가/수여, 리더보드 집계, 스트릭 관리 |
| `shared` | TenantContext, Outbox, Redis Sorted Set 헬퍼 |

## 게임화가 동작하는 방식

`gamification`은 거의 전적으로 **Kafka 이벤트를 소비**해 XP를 적립합니다. 클라이언트가 XP를 직접 올리는 API는 **없습니다**(조작 방지).

| 소비 이벤트 | 보상 |
|---|---|
| `note.created` | +10 XP |
| `card.reviewed` | +5 XP (+정답률 보너스) |
| `card.review.session.completed` | +20 XP |
| `community.group.joined` | +15 XP |
| `community.deck.shared` | +30 XP |
| `graph.notes.linked` | +2 XP |

- **XP Cap (어뷰징 방지)**: 행위별 일일 한도(`xp:counter:{userId}:{type}:{date}`). 봇·중복은 `processed_events` 멱등성으로 차단.
- **배지**: `criteria_json`(예: `notes_created >= 10 AND consecutive_days >= 7`)을 평가 엔진이 판정. 단순 조건은 즉시, 복잡 조건은 일 1회 Cron.
- **리더보드**: Redis Sorted Set(`lb:weekly_xp:{period}`)에 `incrementScore`로 적립, 매일 자정 `leaderboard_entries`로 스냅샷 백업(장애 시 복구).

> 💡 **개념: append-only / Event Sourcing 부분 적용**
> `xp_events`는 추가만 하고 수정하지 않는(append-only) 로그입니다. 현재 상태(`user_xp.total_xp`)는 이 이벤트들에서 파생됩니다. "무슨 일이 있었는지"의 사실을 보존해 재계산·감사가 가능합니다.

## 외부로 노출/의존하는 것

- **REST**: `/api/v1/community/**`, `/api/v1/gamification/**`(me·badges·leaderboards·streak·xp/history)
- **gRPC 제공**: `BadgeService.InitForUser` (platform `auth`가 신규 가입 시 호출 → 환영 배지)
- **gRPC 호출(의존)**: learning-card `DeckService.Copy`(공유 덱 복사), learning-card `ProgressService.GetStats`, knowledge `NoteService.GetForLearning`(공유 참조), platform `UserService.BatchGetByIds`(리더보드 이름 표시)
- **Kafka Producer**: `community.*`, `gamification.xp.earned/badge.earned/level.up`
- **K8s CronJob 2개**: `streak-reset`(매일 00:05 KST), `leaderboard-rollover`(매주 월 00:00)

## 데이터

PostgreSQL: `study_groups`·`group_memberships`·`deck_shares`·`reports`·`xp_events`·`user_xp`·`badge_definitions`·`user_badges`·`user_streaks` 등. Redis: 리더보드 Sorted Set, 스트릭 Hash, XP·신고 카운터.

## 다음 읽을거리

- [synapse-engagement-svc ARCHITECTURE](https://github.com/team-project-final/documents/wiki/synapse-engagement-svc_ARCHITECTURE) — 배지 평가 엔진, XpCapPolicy, 리더보드 코드
- [02 ERD 문서](https://github.com/team-project-final/documents/wiki/02_ERD_문서) · [04 API 명세서](https://github.com/team-project-final/documents/wiki/04_API_명세서)
