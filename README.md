# Synapse 신입 온보딩 포털

MSA를 처음 접하는 신입 개발자가 SYNAPSE의 **전체 흐름과 기능을 한눈에** 파악하도록 돕는 Flutter Web 포털입니다. `synapse-gitops`의 Docs Portal 패턴을 포크·각색했습니다.

## 구조

- `content/` — 온보딩 서사 마크다운
  - `overview/` (개요) · `flow/` (흐름) · `practice/` (실전) — 총 9개 섹션
- `site/` — Flutter Web 앱 (마크다운 뷰어 + 검색 + Mermaid 다이어그램 렌더)
- `site/scripts/build_docs.mjs` — Markdown → JSON + 검색 인덱스 빌드
- `.github/workflows/deploy-pages.yml` — GitHub Pages 자동 배포

## 로컬 실행

```bash
# 1) 콘텐츠 JSON 빌드
cd site/scripts && npm install && node build_docs.mjs

# 2) 포털 실행
cd .. && flutter pub get && flutter run -d chrome
```

## 콘텐츠 수정

`content/<카테고리>/*.md` 를 고친 뒤 `node build_docs.mjs` 를 다시 실행하세요.
다이어그램은 ` ```mermaid ` 코드블록으로 작성하면 브라우저에서 그래픽으로 렌더됩니다.
세부 스펙(API/ERD/env)은 이 포털에 재작성하지 말고 원본 위키로 링크합니다.

## 배포

`main` 브랜치에 push하면 `.github/workflows/deploy-pages.yml` 이 GitHub Pages로 자동 배포합니다
(base-href `/synapse-onboarding/`). 최초 1회 레포 **Settings → Pages → Source**를 **"GitHub Actions"** 로 설정해야 합니다.
배포 URL: `https://team-project-final.github.io/synapse-onboarding/`
