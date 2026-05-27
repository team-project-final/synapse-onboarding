---
title: engagement-svc 샘플 코드
---

# engagement-svc 샘플 코드

> 스택(doc 18 기준): Java 21 · Spring Boot 4 · Spring Kafka · **Spring Data Redis(Sorted Set)** · JPA. 이 서비스는 이벤트 소비 + Redis가 핵심입니다.

## 기능 정의 → 구현 매핑

| 기능 | 구현 포인트 |
|---|---|
| XP 적립(이벤트 기반) | `@KafkaListener` + 멱등성(`processed_events`) + XpCapPolicy |
| 리더보드 | Redis Sorted Set `incrementScore` / `reverseRangeWithScores` |
| 배지 자동 수여 | `criteria_json` 평가 후 `UserBadge` 저장 |
| 스트릭 리셋 | K8s CronJob → 배치 작업 |

## 1. XP 적립 — Kafka 컨슈머 + 멱등성 + Cap

`card.reviewed` / `note.created` 등을 소비해 XP를 적립합니다. **클라이언트가 직접 XP를 올리는 경로는 없습니다.**

```java
@Component
@RequiredArgsConstructor
public class XpEventConsumer {

    private final XpService xpService;
    private final ProcessedEventRepository processedEvents;   // 멱등성

    @KafkaListener(topics = "card.reviewed", groupId = "engagement-gamification")
    @Transactional
    public void onCardReviewed(CloudEvent<CardReviewed> event) {
        // 1) 멱등성 — 같은 이벤트 두 번 처리 방지
        if (!processedEvents.tryMarkProcessed(event.id())) return;

        CardReviewed data = event.data();
        int base = 5 + (data.correct() ? 2 : 0);   // 정답 보너스
        xpService.award(data.userId(), data.tenantId(),
                        XpEventType.CARD_REVIEWED, base, data.cardId());
    }
}

@Service
@RequiredArgsConstructor
public class XpService {
    private final XpCounterRepository counters;     // Redis 일별 카운터
    private final XpEventRepository xpEvents;        // append-only
    private final LeaderboardStore leaderboard;     // Redis ZSet (Port)

    public void award(UUID userId, UUID tenantId, XpEventType type, int baseXp, UUID sourceId) {
        int xp = applyCap(userId, type, baseXp);    // 일일 한도 적용
        if (xp == 0) return;
        xpEvents.save(XpEvent.of(userId, tenantId, type, xp, sourceId));   // 사실 기록
        leaderboard.add(tenantId, userId, xp);      // 리더보드 반영
    }

    // 어뷰징 방지: 행위별 일일 한도
    private static final Map<XpEventType, int[]> CAPS = Map.of(
        XpEventType.NOTE_CREATED,  new int[]{10, 100},   // {일 최대 횟수, 일 최대 XP}
        XpEventType.CARD_REVIEWED, new int[]{200, 500}
    );

    private int applyCap(UUID userId, XpEventType type, int baseXp) {
        int[] cap = CAPS.getOrDefault(type, new int[]{Integer.MAX_VALUE, Integer.MAX_VALUE});
        if (counters.todayCount(userId, type) >= cap[0]) return 0;
        int remaining = cap[1] - counters.todayXp(userId, type);
        return Math.max(0, Math.min(baseXp, remaining));
    }
}
```

## 2. 리더보드 — Redis Sorted Set 어댑터

```java
@Component
@RequiredArgsConstructor
public class RedisLeaderboardAdapter implements LeaderboardStore {

    private final StringRedisTemplate redis;

    private String key(UUID tenantId) {
        String period = ISOWeek.now();                 // 예: 2026-W20
        return "lb:weekly_xp:" + tenantId + ":" + period;
    }

    @Override
    public void add(UUID tenantId, UUID userId, int xp) {
        redis.opsForZSet().incrementScore(key(tenantId), userId.toString(), xp);
    }

    @Override
    public List<RankEntry> top(UUID tenantId, int n) {
        Set<ZSetOperations.TypedTuple<String>> rows =
            redis.opsForZSet().reverseRangeWithScores(key(tenantId), 0, n - 1);
        List<RankEntry> out = new ArrayList<>();
        int rank = 1;
        for (var row : rows) {
            out.add(new RankEntry(rank++, UUID.fromString(row.getValue()), row.getScore().longValue()));
        }
        return out;
    }

    @Override
    public long myRank(UUID tenantId, UUID userId) {
        Long rank = redis.opsForZSet().reverseRank(key(tenantId), userId.toString());
        return rank == null ? -1 : rank + 1;
    }
}
```

> 💡 매일 자정 `leaderboard_entries` 테이블로 스냅샷을 백업해 Redis 장애 시 복구합니다(AOF+RDB와 이중 안전장치).

## 3. 스트릭 리셋 — CronJob 진입점

```java
@Component
@RequiredArgsConstructor
public class StreakResetJob {     // K8s CronJob "5 0 * * *" 가 --job=streak-reset 로 호출
    private final UserStreakRepository streaks;

    public void run() {
        LocalDate yesterday = LocalDate.now(ZoneId.of("Asia/Seoul")).minusDays(1);
        int reset = streaks.resetInactiveSince(yesterday);   // 전날 활동 없으면 current_streak=0
        log.info("streak-reset: {} users reset", reset);
    }
}
```

---
*근거: doc 18 §4.1 Spring · §5.2 Redis · synapse-engagement-svc ARCHITECTURE. 서비스 기능 전체는 [11. engagement-svc 상세].*
