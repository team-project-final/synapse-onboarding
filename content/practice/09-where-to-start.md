---
title: 그래서 어디서 시작하죠?
---

# 그래서 어디서 시작하죠?

여기까지 읽었다면 SYNAPSE의 큰 그림 — 제품, 4개 서비스, 동기/비동기 흐름, 핵심 기능, 프론트엔드, 배포 — 이 머릿속에 그려졌을 겁니다. 이제 **내 트랙으로 들어가** 실제 작업을 시작할 차례입니다.

## 이 포털의 역할 한 번 더

이 포털은 **"이해"** 를 끝내는 곳입니다. 작업할 때 필요한 **정밀 스펙**(API 필드, ERD 컬럼, env 값, 설치 절차)은 아래의 위키·가이드 원본에 있습니다. 이해는 여기서, 정밀 정보는 원본에서.

## 트랙별 진입점

| 합류자 | 담당 레포 | 트랙 가이드 |
|---|---|---|
| 트랙 A (1명) | `synapse-platform-svc` | `documents/docs/onboarding/01-platform-track.md` |
| 트랙 B (1명) | `synapse-engagement-svc` | `documents/docs/onboarding/02-engagement-track.md` |
| 트랙 C (2명) | `synapse-knowledge-svc` | `documents/docs/onboarding/03-knowledge-track.md` |
| 트랙 D (2명) | `synapse-learning-svc` (Java+Python) | `documents/docs/onboarding/04-learning-track.md` |
| 협업 (전체) | `synapse-frontend` | `documents/docs/onboarding/05-frontend.md` |

## Day 0 → Day 1 흐름

먼저 **모든 합류자 공통**인 `documents/docs/onboarding/00-common-day1.md`를 따릅니다.

- **Day 0 (합류 전날)** — GitHub 가입 + 2FA, org 합류, gh CLI 인증, Java 21 / Python 3.11 / Flutter / Docker 설치, `documents` 클론 + 위키 정독, 09a Git 워크플로우·DESIGN.md 정독
- **Day 1 (첫 출근)** — 자기 레포 클론, 자기 영역 위키 정독, SECRETS 발급, 첫 비즈니스 PR, W1~W5 자기 트랙 일정 확인

## "다음 읽을거리" 지도 — 18개 위키

| 묶음 | 문서 |
|---|---|
| **기획/설계** | 01 프로젝트 계획서 · 02 ERD · 03 아키텍처 정의서 · 04 API 명세 · 05 화면 흐름 · 06 화면 기능 · 07 요구사항 · 08 스토리보드 |
| **개발 규칙** | 09 Git 규칙 · 09a Git 워크플로우 · 10 환경 설정 · 11 테스트 전략 · 12 코드 리뷰 규칙 |
| **운영/배포** | 13 테스트 보고서 · 14 배포 가이드 · 15 사용자 메뉴얼 · 16 운영 메뉴얼 · 17 스케줄 · 18 기술 스택 |

→ [위키 홈에서 전체 목차 보기](https://github.com/team-project-final/documents/wiki)

## 막혔을 때

| 상황 | 채널 |
|---|---|
| 일반 개발 질문 | `#synapse-dev` |
| 아키텍처 결정 | `#architecture` (ADR 토론) |
| 빌드/배포 문제 | `#devops` (@team-lead) |
| 보안 | `#security` |
| 🚨 운영 장애 | `#incident` + on-call |

> 부끄러운 질문은 없습니다. 잘못된 가정으로 시작하는 게 훨씬 더 큰 비용입니다.

---

**이 포털을 다 읽었다면 → 위 표에서 자기 트랙 가이드를 열고 Day 0 준비부터 시작하세요. 환영합니다! 🚀**
