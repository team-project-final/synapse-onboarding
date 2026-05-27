---
title: platform-svc 상세
---

# platform-svc 상세

> [03. 4개 서비스 소개]에서 간단히 봤다면, 이 장은 **실제 레포 구조 기반의 상세 설명**입니다. 정밀 스펙(엔드포인트·컬럼)은 04 API·02 ERD로 링크합니다.

플랫폼의 **핵심 기반 서비스**. 단일 Spring Boot 애플리케이션 + 단일 Dockerfile로 배포하고, 내부는 Spring Modulith 모듈로 격리합니다. (Java 21, Spring Boot 4.0, Spring Modulith 1.3)

> 💡 **개념: 헥사고날 / Port·Adapter (03-D 표준)**
> 네 서비스 모두 같은 내부 구조를 씁니다. 도메인 로직은 바깥세상(DB·Kafka·외부 API)을 **직접** 부르지 않고, `Port`(도메인이 정의한 인터페이스)를 통해 부릅니다. 실제 구현은 `Adapter`(인프라)가 맡습니다. 덕분에 도메인은 "Kafka·OpenAI·Redis를 몰라도" 되고, 어댑터만 갈아 끼우면 됩니다. 모듈 경계는 `ModuleStructureTest`(Spring Modulith)로 CI에서 검증합니다.

## 모듈 구성

| 모듈 | 책임 |
|---|---|
| `auth` | JWT(RS256) 발급·검증, OAuth2(Google/GitHub), MFA(TOTP), Refresh Token(Redis+DB 이중) |
| `user` | 사용자 프로필·설정. 다른 모듈은 `UserApi` 인터페이스로만 접근 |
| `notification` | FCM/APNs 푸시, AWS SES 이메일, 인앱 미읽음 카운트(Redis) |
| `admin` | **Audit Log** — 전 시스템 도메인 이벤트를 Kafka로 구독해 `audit_logs`에 적재 |
| `shared` | 공통 — `FieldEncryptor`(AES-256-GCM), CloudEvents 빌더, TenantContext, Outbox, 멱등성 |

## 외부로 노출하는 것

- **REST (Gateway 경유)**: `/api/v1/auth/refresh`, `/auth/mfa/setup|verify`, `/oauth2/authorization/{google|github}`, `/api/v1/users/**`, `/api/v1/notifications/**`, `/api/v1/admin/audit/**`
- **gRPC (내부, 서비스 메시)**: `UserService.GetById / BatchGetByIds`(다른 svc가 사용자 정보 조회), `AuthService.Introspect`(모든 서비스가 REST 인증 검증에 사용)
- **Kafka Producer**: `user.registered`, `user.deleted`, `user.profile.updated`, `notification.sent`
- **Kafka Consumer**: `admin`은 **모든** 도메인 이벤트(감사), `notification`은 알림이 필요한 모든 이벤트

## 데이터

| 저장소 | 용도 |
|---|---|
| PostgreSQL 16 | `users`·`tenants`·`oauth_identities`·`mfa_credentials`·`refresh_tokens`·`audit_logs`. RLS 적용. Flyway V1~V23 |
| Redis 7 | `auth:refresh:*`(7d), `auth:oauth:pkce:*`(10m), `notif:unread:*` 등 |
| Kafka(MSK) | CloudEvents 1.0 |

## 보안 하이라이트

- 비밀번호 BCrypt(cost 12), MFA Secret·OAuth access_token은 AES-256-GCM 암호화 저장
- Refresh Token은 SHA-256 해시 저장 + **재사용 탐지 시 전 세션 무효화**
- JWT는 RS256(개인키 서명, 공개키 검증)

> ⚠️ **현재 상태/갭**: 실제 레포에는 **billing 모듈이 아직 없습니다**(Wiki 03 계획엔 있음). OAuth도 계획은 4종(Google/GitHub/Apple/MS)이지만 현재 2종(Google/GitHub)만 구현되어 있습니다. 온보딩 시 "문서=계획, 코드=현재"임을 기억하세요.

## 다음 읽을거리

- [synapse-platform-svc ARCHITECTURE](https://github.com/team-project-final/documents/wiki/synapse-platform-svc_ARCHITECTURE) — 모듈별 Port/Adapter, 메트릭, 트러블슈팅
- [04 API 명세서](https://github.com/team-project-final/documents/wiki/04_API_명세서) · [02 ERD 문서](https://github.com/team-project-final/documents/wiki/02_ERD_문서)
- 서비스 간 연결은 → [14. 서비스 간 상호작용 지도]
