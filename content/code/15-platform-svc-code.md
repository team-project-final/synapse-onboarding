---
title: platform-svc 샘플 코드
---

# platform-svc 샘플 코드

> 스택(doc 18 기준): Java 21 · Spring Boot 4 · **Spring Security 7** · Spring Data JPA/Hibernate 7 · Spring Modulith · Kafka. 코드는 기술 스택 정의서의 패턴을 따르며 현행 API로 검증했습니다.

## 기능 정의 → 구현 매핑

| 기능 | 구현 포인트 |
|---|---|
| OAuth2 소셜 로그인 | `SecurityFilterChain` + `oauth2Login` + 성공 핸들러 |
| JWT 발급(RS256) | `JwtEncoder` + `JwtClaimsSet`(tenantId·role·plan 클레임) |
| 메서드 인가(RBAC) | `@EnableMethodSecurity` + `@PreAuthorize` |
| 모듈 간 알림(가입 환영) | Spring Modulith `@ApplicationModuleListener` |

## 1. Spring Security 7 — 보안 필터 체인 + JWT 발급

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity   // @PreAuthorize 활성화
public class AuthSecurityConfig {

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http, JwtAuthFilter jwtAuthFilter) throws Exception {
        return http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/login", "/api/v1/auth/oauth2/**",
                                 "/actuator/health").permitAll()
                .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated())
            .oauth2Login(oauth2 -> oauth2
                .authorizationEndpoint(ep -> ep.baseUri("/api/v1/auth/oauth2/authorize"))
                .redirectionEndpoint(ep -> ep.baseUri("/api/v1/auth/oauth2/callback/*"))
                .successHandler(oAuth2SuccessHandler))
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }
}

@Service
public class JwtService {
    private final JwtEncoder jwtEncoder;   // RSA 개인키 기반 (RS256)

    public String generateAccessToken(User user) {
        JwtClaimsSet claims = JwtClaimsSet.builder()
            .issuer("https://api.synapse.app")
            .subject(user.getId().toString())
            .issuedAt(Instant.now())
            .expiresAt(Instant.now().plus(15, ChronoUnit.MINUTES))   // Access 15분
            .claim("role", user.getRole().name())
            .claim("tenantId", user.getTenantId().toString())        // 게이트웨이가 X-Tenant-Id로 전파
            .claim("plan", user.getSubscriptionPlan().name())
            .build();
        return jwtEncoder.encode(JwtEncoderParameters.from(claims)).getTokenValue();
    }
}
```

## 2. 메서드 레벨 인가 (RBAC)

```java
@Service
public class AuditQueryService {
    @PreAuthorize("hasRole('ADMIN')")
    public Page<AuditLog> search(AuditSearchCriteria criteria, Pageable pageable) {
        return auditLogRepository.search(criteria, pageable);
    }
}
```

## 3. 모듈 간 비동기 — 가입 시 환영 알림 (Spring Modulith)

`auth` 모듈이 도메인 이벤트를 발행하면, 같은 JVM의 `notification` 모듈이 받습니다. 모듈 간 직접 호출 대신 이벤트로 느슨하게 결합합니다.

```java
// auth 모듈 — 가입 완료 시 이벤트 발행
@Service
@RequiredArgsConstructor
public class RegistrationService {
    private final ApplicationEventPublisher events;

    @Transactional
    public User register(SignupCommand cmd) {
        User user = userRepository.save(User.createFrom(cmd));
        events.publishEvent(new UserRegistered(user.getId(), user.getTenantId(), user.getEmail()));
        return user;
    }
}

public record UserRegistered(UUID userId, UUID tenantId, String email) {}

// notification 모듈 — 트랜잭션 커밋 후 수신
@Component
@RequiredArgsConstructor
class WelcomeNotificationListener {
    private final EmailGateway emailGateway;   // Port → SesEmailAdapter

    @ApplicationModuleListener   // = @Async + @TransactionalEventListener(AFTER_COMMIT)
    void on(UserRegistered event) {
        emailGateway.send(event.email(), "WELCOME", Map.of("userId", event.userId()));
    }
}
```

> 💡 `@ApplicationModuleListener`는 Spring Modulith가 제공하는 어노테이션으로, **커밋 이후 비동기**로 실행됩니다. 가입 트랜잭션이 롤백되면 환영 메일도 안 나갑니다.

## 4. 의존성 (build.gradle.kts 핵심)

```kotlin
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-oauth2-client")
    implementation("org.springframework.boot:spring-boot-starter-oauth2-resource-server")
    implementation("org.springframework.modulith:spring-modulith-starter-core")
    implementation("org.springframework.kafka:spring-kafka")
}
```

---
*근거: doc 18 §4.1.3 Spring Security 7 · §4.1.8 Spring Modulith · synapse-platform-svc ARCHITECTURE. 서비스 기능 전체는 [10. platform-svc 상세].*
