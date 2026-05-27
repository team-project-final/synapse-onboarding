---
title: learning-svc 샘플 코드
---

# learning-svc 샘플 코드

폴리글랏 서비스라 두 언어 샘플을 모두 싣습니다. **A. learning-card(Java/Spring)** · **B. learning-ai(Python/FastAPI)**.

## 기능 정의 → 구현 매핑

| 기능 | 컨테이너 | 구현 포인트 |
|---|---|---|
| SRS 복습 스케줄링 | learning-card | SM-2 알고리즘(도메인 정책) |
| 카드 자동 생성 | learning-ai | LangChain LCEL + 구조화 출력(Pydantic) |
| RAG 질의응답 | learning-ai | pgvector + BM25 하이브리드(RRF) |

---

## A. learning-card (Java) — SM-2 알고리즘

`AGAIN/HARD/GOOD/EASY` 평가로 다음 복습일을 계산합니다.

```java
public record SrsState(int interval, double easeFactor, int repetitions, Instant dueDate) {}

@Component
public class Sm2Algorithm {                // srs 모듈 — 순수 도메인 정책(외부 의존 없음)

    public SrsState next(SrsState cur, ReviewRating rating) {
        if (rating == ReviewRating.AGAIN) {                 // 실패 → 10분 뒤 재시도
            return new SrsState(0, Math.max(1.3, cur.easeFactor() - 0.2), 0,
                                Instant.now().plus(Duration.ofMinutes(10)));
        }
        int reps = cur.repetitions() + 1;
        double ef = cur.easeFactor()
            + (0.1 - (4 - rating.value()) * (0.08 + (4 - rating.value()) * 0.02));
        ef = Math.max(1.3, ef);                             // ease factor 하한
        int interval = switch (reps) {
            case 1 -> 1;                                    // 1일
            case 2 -> 6;                                    // 6일
            default -> (int) Math.round(cur.interval() * ef);
        };
        return new SrsState(interval, ef, reps, Instant.now().plus(Duration.ofDays(interval)));
    }
}
```

복습 제출 → 이벤트 발행:

```java
@Service
@RequiredArgsConstructor
public class ReviewService {
    private final CardRepository cards;
    private final Sm2Algorithm sm2;
    private final CardEventPublisher events;   // Outbox → Kafka

    @Transactional
    public void submit(UUID userId, UUID cardId, ReviewRating rating) {
        Card card = cards.findById(cardId).orElseThrow();
        card.applySrs(sm2.next(card.srsState(), rating));        // 다음 due_date 갱신
        events.publish(new CardReviewed(cardId, userId, card.tenantId(),
                                        rating.value() >= 3));   // engagement가 소비 → XP
    }
}
```

---

## B. learning-ai (Python) — 카드 자동 생성 (LangChain LCEL)

```python
# app/services/card_generator.py
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from pydantic import BaseModel, Field

class FlashCard(BaseModel):
    front: str = Field(description="질문")
    back: str = Field(description="답변")
    difficulty: int = Field(ge=1, le=5)

class FlashCardList(BaseModel):
    cards: list[FlashCard]

class CardGenerator:
    def __init__(self) -> None:
        llm = ChatOpenAI(model="gpt-4o-mini", temperature=0.3)
        # 구조화 출력: 모델이 FlashCardList JSON 스키마를 강제로 따르게 함
        self.chain = (
            ChatPromptTemplate.from_messages([
                ("system", "교육 전문가로서 한국어 플래시카드를 생성하세요."),
                ("human", "다음 내용으로 {count}개의 카드를 생성하세요:\n\n{content}"),
            ])
            | llm.with_structured_output(FlashCardList)
        )

    async def generate(self, content: str, count: int = 5) -> list[FlashCard]:
        result: FlashCardList = await self.chain.ainvoke({"content": content, "count": count})
        return result.cards
```

## B. learning-ai (Python) — RAG 하이브리드 검색 (pgvector + BM25 + RRF)

> ⚠️ doc 18은 구버전 `langchain_community ... PGVector`를 보여주지만, 현행 권장은 **`langchain_postgres`** 입니다(아래는 최신 API 반영).

```python
# app/services/rag_service.py
from langchain_postgres import PGVector            # 현행 패키지 (community 버전 deprecated)
from langchain_openai import OpenAIEmbeddings

embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
vectorstore = PGVector(
    embeddings=embeddings,                          # (구) embedding_function → (신) embeddings
    collection_name="note_embeddings",
    connection=settings.PG_ASYNC_URL,               # (구) connection_string → (신) connection
    use_jsonb=True,
)

RRF_K, TOP_K = 60, 20
async def hybrid_search(query: str, tenant_id: str, user_id: str) -> list[Chunk]:
    # 1) 두 검색을 병렬 실행: 시맨틱(pgvector) + 키워드(Elasticsearch BM25, nori)
    pg, es = await asyncio.gather(
        pgvector_search(query, tenant_id, user_id, TOP_K),
        elasticsearch_search(query, tenant_id, user_id, TOP_K),
    )
    # 2) RRF로 순위 융합:  score(d) = Σ 1 / (k + rank_i(d))
    scores: dict[str, float] = {}
    chunks: dict[str, Chunk] = {}
    for ranked in (pg, es):
        for rank, c in enumerate(ranked):
            scores[c.id] = scores.get(c.id, 0) + 1 / (RRF_K + rank + 1)
            chunks[c.id] = c
    top = sorted(scores, key=scores.get, reverse=True)[:5]
    return [chunks[cid] for cid in top]
```

## B. learning-ai (Python) — FastAPI 엔드포인트 (SSE 스트리밍)

```python
# app/routers/qa.py
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse

router = APIRouter(prefix="/ai")

@router.post("/qa")
async def ask(req: QaRequest, ctx: TenantContext = Depends(get_tenant_context)):
    chunks = await hybrid_search(req.question, ctx.tenant_id, ctx.user_id)
    async def stream():
        async for token in qa_chain.astream({"context": chunks, "question": req.question}):
            yield f"data: {token}\n\n"          # Server-Sent Events
    return StreamingResponse(stream(), media_type="text/event-stream")
```

```toml
# pyproject.toml (핵심)
[tool.poetry.dependencies]
python = "^3.12"
fastapi = "^0.115"
uvicorn = {extras = ["standard"], version = "^0.34"}
langchain = "^0.3"
langchain-openai = "^0.3"
langchain-postgres = "^0.0.13"
```

---
*근거: doc 18 §4.2 FastAPI/LangChain · §6.3 RAG · synapse-learning-svc ARCHITECTURE. PGVector API는 context7(langchain-postgres)로 현행 검증. 서비스 기능 전체는 [13. learning-svc 상세].*
