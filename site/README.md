# site — Flutter Web 앱

Synapse 신입 온보딩 포털의 Flutter Web 앱입니다. 빌드·실행·배포 방법은 레포 루트의 [README.md](../README.md)를 참고하세요.

## 구조

- `lib/pages/` — home · doc · search
- `lib/widgets/` — markdown viewer · sidebar · TOC · mermaid view 등
- `lib/models/` — doc · search index 모델
- `scripts/build_docs.mjs` — `../content/` 마크다운 → `assets/docs/*.json` 빌드 (Node)

콘텐츠는 이 앱이 아니라 레포 루트의 `content/`에 있습니다.
