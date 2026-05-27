---
title: Gateway 샘플 코드
---

# Gateway 샘플 코드

> 스택(doc 18 기준): **Spring Cloud Gateway 5**(WebFlux/Netty 논블로킹) · Resilience4j · Redis Token Bucket. Spring Boot 4에서는 `spring-cloud-starter-gateway-server-webflux` 스타터를 씁니다.

## 기능 정의 → 구현 매핑

| 기능 | 구현 포인트 |
|---|---|
| 단일 진입점 라우팅 | `application.yml` routes (Path 述어) |
| JWT 검증 + 테넌트 주입 | `GlobalFilter`로 `X-Tenant-Id`/`X-User-Id` 헤더 주입 |
| 플랜별 Rate Limit | `RequestRateLimiter` + Redis Token Bucket + `KeyResolver` |
| 장애 격리 | `CircuitBreaker` 필터 + Resilience4j |

## 1. 라우팅 (application.yml)

```yaml
spring:
  cloud:
    gateway:
      default-filters:
        - name: RequestRateLimiter
          args:
            redis-rate-limiter.replenishRate: 100      # 초당 토큰 보충(기본/FREE)
            redis-rate-limiter.burstCapacity: 200
            key-resolver: "#{@userKeyResolver}"
      routes:
        - id: auth-service
          uri: lb://platform-svc
          predicates: [ "Path=/api/v1/auth/**" ]
          filters:
            - name: CircuitBreaker
              args: { name: authCB, fallbackUri: "forward:/fallback/auth" }
        - id: note-service
          uri: lb://knowledge-svc
          predicates: [ "Path=/api/v1/notes/**" ]
          filters:
            - name: CircuitBreaker
              args: { name: noteCB, fallbackUri: "forward:/fallback/note" }
        - id: ai-service
          uri: lb://learning-ai
          predicates: [ "Path=/api/v1/ai/**" ]
          filters:
            - name: RequestRateLimiter            # AI는 더 빡빡한 별도 버킷
              args:
                redis-rate-limiter.replenishRate: 1
                redis-rate-limiter.burstCapacity: 10
                key-resolver: "#{@aiKeyResolver}"
```

## 2. JWT 검증 Global Filter (테넌트 헤더 주입)

게이트웨이가 JWT를 검증하고 `tenantId`를 다운스트림 헤더로 주입합니다. 이것이 멀티테넌시 L1입니다.

```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
@RequiredArgsConstructor
public class JwtAuthenticationFilter implements GlobalFilter {

    private final JwtTokenProvider jwt;

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String token = extractBearer(exchange.getRequest());
        if (token == null) return chain.filter(exchange);   // permitAll 경로

        return Mono.fromCallable(() -> jwt.validateAndParse(token))
            .flatMap(claims -> {
                ServerHttpRequest mutated = exchange.getRequest().mutate()
                    .header("X-User-Id",   claims.getSubject())
                    .header("X-Tenant-Id", claims.get("tenantId", String.class))   // ← L1 테넌트 주입
                    .header("X-User-Role", claims.get("role", String.class))
                    .header("X-User-Plan", claims.get("plan", String.class))       // Rate Limit 키에 사용
                    .build();
                return chain.filter(exchange.mutate().request(mutated).build());
            })
            .onErrorResume(e -> {
                exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
                return exchange.getResponse().setComplete();
            });
    }
}
```

## 3. 플랜별 Rate Limit — KeyResolver + RedisRateLimiter

```java
@Configuration
public class RateLimiterConfig {

    @Bean
    KeyResolver userKeyResolver() {                  // userId + plan 조합으로 버킷 분리
        return exchange -> {
            HttpHeaders h = exchange.getRequest().getHeaders();
            String userId = h.getFirst("X-User-Id");
            String plan   = h.getFirstOrDefault("X-User-Plan", "FREE");
            return Mono.just(userId + ":" + plan);
        };
    }

    @Bean
    KeyResolver aiKeyResolver() {                    // AI 전용 일일 버킷
        return exchange -> {
            String userId = exchange.getRequest().getHeaders().getFirst("X-User-Id");
            return Mono.just("ai:" + userId);
        };
    }

    @Bean
    RedisRateLimiter defaultRateLimiter() {
        return new RedisRateLimiter(100, 200, 1);    // replenishRate, burstCapacity, requestedTokens
    }
}
```

## 4. Resilience4j 서킷 브레이커 (application.yml)

```yaml
resilience4j:
  circuitbreaker:
    instances:
      authCB:
        sliding-window-size: 50
        failure-rate-threshold: 60
        wait-duration-in-open-state: 15s
      aiCB:                                  # 느린 AI → 엄격
        sliding-window-size: 20
        failure-rate-threshold: 50
        slow-call-duration-threshold: 3s
        slow-call-rate-threshold: 70
        wait-duration-in-open-state: 30s
        automatic-transition-from-open-to-half-open-enabled: true
```

```kotlin
// build.gradle.kts
dependencies {
    implementation("org.springframework.cloud:spring-cloud-starter-gateway-server-webflux")
    implementation("org.springframework.cloud:spring-cloud-starter-circuitbreaker-reactor-resilience4j")
    implementation("org.springframework.boot:spring-boot-starter-data-redis-reactive")
}
```

---
*근거: doc 18 §3.1 Gateway · §3.2 Resilience4j · §3.3 Redis Token Bucket. 라우팅/필터 흐름은 [04. 요청 하나가 흐르는 길].*
