---
title: 4개 서비스 소개
---

# 4개 서비스 소개

각 서비스를 "담당자 한 명을 소개하듯" 살펴봅니다. 모든 서비스는 단일 git 레포로 운영되고, 내부는 Spring Modulith 모듈로 나뉩니다.

> 📂 이 장은 *개요* 입니다. 각 서비스의 모듈·내부 API·데이터까지 깊게 보려면 **"서비스 상세"** 카테고리(10~13)를, 서비스들이 어떻게 연결되는지는 [14. 서비스 간 상호작용 지도]를 보세요.

## 트랙 ↔ 레포 ↔ Owner 한눈에

| 트랙 | 인원 | 담당 레포 | 통합한 도메인 |
|---|:--:|---|---|
| 팀장 | 1 | 인프라 + 전 영역 cross-review | — |
| A | 1 | `synapse-platform-svc` | Auth + Audit + Billing + Notification |
| B | 1 | `synapse-engagement-svc` | Community + Gamification |
| C | 2 | `synapse-knowledge-svc` | Note + Graph + Chunking |
| D | 2 | `synapse-learning-svc` | Card + SRS (Java) + AI (Python) |
| 협업 | 전체 | `synapse-frontend` (Flutter) | UI |

## platform-svc — "현관과 살림" (트랙 A)

> 비즈니스 로직은 단순하지만 외부 SaaS 통합이 많은, 시스템의 cross-cutting 담당.

| 모듈 | 책임 |
|---|---|
| `auth/` | OAuth 2.0(Google/GitHub/Apple/Microsoft), JWT 발급(RS256, Access 15분 + Refresh 7일 httpOnly Cookie), MFA(TOTP), 가입 시 테넌트 자동 생성 + 초대 가입 |
| `audit/` | Kafka 이벤트 소비 → `audit_logs` 적재, Idempotency, 관리자 감사 로그 검색, 90일 보존 |
| `billing/` | Free/Pro/Team/Enterprise 플랜, Stripe Checkout·Webhook, 사용량 기반 제한(초과 시 403) |
| `notification/` | 이벤트 소비 → 알림 설정 확인 → 푸시(FCM/APNs)·메일(SES)·인앱 알림, 복습 리마인더 |

## engagement-svc — "동기 부여 엔진" (트랙 B)

> 외부 의존이 적고, 다른 서비스가 발행한 이벤트를 소비해 동작하는 비중이 큼.

| 모듈 | 책임 |
|---|---|
| `community/` | 스터디 그룹 CRUD·가입 승인·역할 변경·강퇴/밴, 덱·노트 공유(public/group/link), 신고 접수(중복·일일 한도 제한) |
| `gamification/` | XP 적립 → 레벨 판정, 배지 수여, 주간/월간 리더보드 자동 생성(Cron), 스트릭 리셋 |

`card.reviewed`·`note.created`·`community.*` 이벤트를 소비하고 `gamification.*` 이벤트를 발행합니다.

## knowledge-svc — "Synapse의 심장" (트랙 C, 2명)

> 노트 + 지식 그래프. Synapse 정체성의 Core 도메인.

| 모듈 | 책임 |
|---|---|
| `note/` | Markdown CRUD, `[[위키링크]]` 파싱 → `note_links` 갱신, 저장 시 버전 기록, S3 첨부(Presigned URL), Elasticsearch 동기화 |
| `graph/` | 백링크 조회, 노드(노트)+엣지(링크) → 그래프 시각화 데이터, PageRank로 중요 노트 식별, 관련 노트 클러스터링 |
| `chunking/` | 노트를 청크로 분할, learning-ai 호출로 임베딩 생성, pgvector 적재 |

## learning-svc — "가장 큰 서비스" (트랙 D, 2명 · 두 컨테이너)

> 학습 + AI. Java와 Python 두 컨테이너가 한 서비스를 이룹니다.

| 컨테이너 / 모듈 | 책임 |
|---|---|
| `learning-card` (Java/Spring) — `card/`·`srs/` | 카드/덱 CRUD, SM-2 알고리즘으로 다음 복습일 계산, 오늘의 복습 카드 조회, 복습 세션 통계 |
| `learning-ai` (Python/FastAPI) — `ai/` | 노트→LLM→카드 자동 생성(basic/cloze), 쿼리 임베딩 → pgvector 시맨틱 검색, 시맨틱+BM25 하이브리드(RRF), RAG 질의응답, 시맨틱 캐시(코사인 유사도 > 0.95), 토큰/비용 추적 |

K8s에서는 `learning-card`·`learning-ai` 두 Deployment로 분리되고, 서로는 Kafka 이벤트 + 내부 REST API로 통신합니다.

> 💡 **개념: 왜 한 서비스인데 컨테이너가 둘?**
> 카드 도메인(Java)과 AI 도메인(Python)은 강하게 엮여 있지만 런타임·라이브러리 생태계가 다릅니다. 한 "서비스"(오너십·레포)로 묶되, 배포 단위(컨테이너)는 언어별로 둘로 나눈 실용적 선택입니다.

## 다음 읽을거리

- 서비스별 ARCHITECTURE 문서: [platform](https://github.com/team-project-final/documents/wiki/synapse-platform-svc_ARCHITECTURE) · [engagement](https://github.com/team-project-final/documents/wiki/synapse-engagement-svc_ARCHITECTURE) · [knowledge](https://github.com/team-project-final/documents/wiki/synapse-knowledge-svc_ARCHITECTURE) · [learning](https://github.com/team-project-final/documents/wiki/synapse-learning-svc_ARCHITECTURE)
- 트랙별 합류 가이드: `documents/docs/onboarding/01-platform-track.md` ~ `04-learning-track.md`
