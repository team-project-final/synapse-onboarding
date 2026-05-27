---
title: learning-svc 상세
---

# learning-svc 상세

> 실제 레포 구조 기반 상세. 빠른 소개는 [03. 4개 서비스 소개], 연결 구조는 [14. 서비스 간 상호작용 지도].

가장 큰 서비스이자 유일한 **폴리글랏 레포**입니다. 단일 GitHub 레포 안에 Java와 Python 디렉토리가 분리되어 있고, **Docker 이미지·K8s Deployment가 각각 2개**입니다.

| 서브 프로젝트 | 언어 | 책임 | 이미지 |
|---|---|---|---|
| `learning-card/` | Java/Spring Boot 4 | 카드/덱 CRUD, SRS 스케줄링, 복습 큐·세션·통계 | `synapse-learning-card` |
| `learning-ai/` | Python/FastAPI | 카드 자동 생성, 시맨틱/하이브리드 검색, RAG Q&A, 시맨틱 캐시, 사용량 추적 | `synapse-learning-ai` |

## learning-card (Java)

모듈: `card` · `deck` · `review` · `srs` · `session` · `shared`.

- **SM-2 알고리즘**(`srs` 모듈, 도메인 정책): 복습 평가 `AGAIN/HARD/GOOD/EASY` → `ease_factor`·`interval`·`due_date` 계산. (FSRS로 점진 전환 검토 중)
- **REST**: `/api/v1/cards|decks|reviews|sessions/**`
- **gRPC 제공**: `ProgressService.GetStats`(engagement 호출), `DeckService.Copy`(community 호출)
- **gRPC 호출**: knowledge `NoteService.GetForLearning`, learning-ai `AIService.GenerateCard`, platform `UserService.GetById`
- **Kafka Producer**: `card.created/updated/deleted`, `card.reviewed`, `card.review.due`(일 1회 배치)
- **데이터**: `decks`·`cards`·`srs_states`·`reviews`(append-only)·`review_sessions`. Redis: 오늘 due 카드 리스트(`card:due:{userId}:{date}`).

## learning-ai (Python)

헥사고날 구조(`domain/port` + `infrastructure/adapter`). LLM·검색·캐시를 모두 Port로 추상화.

| Port | Adapter | 대상 |
|---|---|---|
| `LLMPort` | OpenAI / Anthropic(fallback) | 카드 생성·Q&A·임베딩 |
| `VectorStorePort` | pgvector(읽기 전용) | 시맨틱 검색 |
| `SearchIndexPort` | Elasticsearch | BM25 검색 |
| `RerankerPort` | Cohere(선택) | 재정렬 |
| `CachePort` | Redis | 시맨틱 캐시 |
| `UsageRecorderPort` | PostgreSQL | `ai_usage_logs` |

**RAG 파이프라인**: 시맨틱 캐시 확인(유사도 ≥ 0.95) → 쿼리 임베딩 → pgvector(top 20) + BM25(top 20) → **RRF 융합**(top 10) → (선택)Cohere 재정렬(top 5) → LLM 스트리밍 답변(SSE) → 사용량 기록 → 캐시 저장.

- **REST(SSE)**: `/api/v1/ai/cards/generate`, `/ai/search/semantic|hybrid`, `/ai/qa`
- **gRPC 제공**: `AIService.Embed/EmbedBatch`(knowledge chunking 호출), `AIService.GenerateCard`(learning-card 호출)
- **Kafka Producer**: `ai.usage.recorded`(향후 billing 소비)

> 💡 **개념: 폴리글랏 + 왜 컨테이너가 둘인가**
> 학습 도메인(Java)과 AI 도메인(Python)은 강하게 협력하지만 런타임 생태계가 다릅니다. 오너십·레포는 하나로 묶되, 배포 단위는 언어별로 분리했습니다. 둘은 같은 프로세스가 아니라 **gRPC**로 통신합니다.

## learning-card ↔ learning-ai

같은 "서비스"지만 서로 다른 컨테이너이므로, 카드 자동 생성은 learning-card가 learning-ai의 `AIService.GenerateCard`를 **gRPC(서버 스트리밍)** 로 호출합니다. 임베딩은 반대로 knowledge가 learning-ai를 호출합니다.

## 다음 읽을거리

- [synapse-learning-svc ARCHITECTURE](https://github.com/team-project-final/documents/wiki/synapse-learning-svc_ARCHITECTURE) — SM-2 코드, RAG UseCase, LLM 모델 전략
- [06. 핵심 유저 플로우 E2E] — AI 카드 생성·RAG 시나리오
