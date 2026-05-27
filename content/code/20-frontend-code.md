---
title: 프론트엔드 샘플 코드
---

# 프론트엔드 샘플 코드

> 스택(doc 18 기준): Flutter 3.x · Dart 3 · **Riverpod 3**(`@riverpod` 코드 생성) · **GoRouter** · Dio(Repository). 4계층(UI→Riverpod→Repository→DataSource)을 코드로 봅니다.

## 기능 정의 → 구현 매핑

| 기능 | 구현 포인트 |
|---|---|
| 상태 관리 | `@riverpod` Notifier + `AsyncValue` |
| 화면 라우팅 + 인증 가드 | `GoRouter` `redirect` |
| API 추상화 | Repository 인터페이스 + Dio DataSource |

## 1. Riverpod — 노트 에디터 Notifier (자동저장)

```dart
// note_editor_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'note_editor_provider.g.dart';

@freezed
class NoteEditorState with _$NoteEditorState {
  const factory NoteEditorState({
    required String noteId,
    @Default('') String content,
    @Default(false) bool isDirty,
    @Default(false) bool isSaving,
  }) = _NoteEditorState;
}

@riverpod
class NoteEditor extends _$NoteEditor {
  Timer? _autoSave;

  @override
  NoteEditorState build(String noteId) {
    ref.onDispose(() => _autoSave?.cancel());     // 자동 dispose 시 타이머 정리
    return NoteEditorState(noteId: noteId);
  }

  void updateContent(String content) {
    state = state.copyWith(content: content, isDirty: true);
    _autoSave?.cancel();
    _autoSave = Timer(const Duration(seconds: 3), save);   // 3초 디바운스 자동저장
  }

  Future<void> save() async {
    if (!state.isDirty) return;
    state = state.copyWith(isSaving: true);
    await ref.read(noteRepositoryProvider).updateNote(state.noteId, state.content);
    state = state.copyWith(isDirty: false, isSaving: false);
  }
}
```

```dart
// UI — build에서는 watch, 콜백에서는 read
class NoteEditorPage extends ConsumerWidget {
  final String noteId;
  const NoteEditorPage({super.key, required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(noteEditorProvider(noteId));
    return Column(children: [
      if (s.isSaving) const LinearProgressIndicator(),
      TextField(
        onChanged: (v) => ref.read(noteEditorProvider(noteId).notifier).updateContent(v),
      ),
    ]);
  }
}
```

```bash
dart run build_runner build --delete-conflicting-outputs   # *.g.dart 생성
```

## 2. GoRouter — 인증 리다이렉트 가드

```dart
@riverpod
GoRouter router(Ref ref) {
  final auth = ref.watch(authProvider);     // 로그인 상태
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      if (!auth.isAuthenticated) return loggingIn ? null : '/login';   // 미로그인 → /login
      if (loggingIn) return '/';                                       // 이미 로그인 → 홈
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      ShellRoute(                                                      // 사이드바 + 콘텐츠 중첩 레이아웃
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomePage()),
          GoRoute(
            path: '/notes/:id',
            builder: (_, s) => NoteEditorPage(noteId: s.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}
```

## 3. Repository + DataSource (Dio)

UI/Riverpod은 HTTP를 모릅니다. Repository 인터페이스에만 의존하고, DataSource가 실제 호출을 합니다.

```dart
abstract interface class NoteRepository {
  Future<Note> getNote(String id);
  Future<void> updateNote(String id, String content);
}

class NoteRepositoryImpl implements NoteRepository {
  final Dio _dio;                            // baseUrl = https://api.synapse.app (Gateway)
  NoteRepositoryImpl(this._dio);

  @override
  Future<Note> getNote(String id) async {
    final res = await _dio.get('/api/v1/notes/$id');   // Authorization 헤더는 인터셉터가 주입
    return Note.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<void> updateNote(String id, String content) =>
      _dio.put('/api/v1/notes/$id', data: {'content': content});
}

@riverpod
NoteRepository noteRepository(Ref ref) =>
    NoteRepositoryImpl(ref.watch(dioProvider));
```

> 💡 Access Token은 Dio 인터셉터에서 메모리의 토큰을 `Authorization: Bearer ...`로 주입하고, 401이면 Refresh Cookie로 재발급 → 재시도합니다.

```yaml
# pubspec.yaml (핵심)
dependencies:
  flutter_riverpod: ^3.0.0
  riverpod_annotation: ^3.0.0
  go_router: ^14.8.1
  dio: ^5.7.0
dev_dependencies:
  riverpod_generator: ^3.0.0
  build_runner: ^2.10.4
```

---
*근거: doc 18 §2.3 Riverpod · §2.4 GoRouter. 프론트엔드 구조는 [07. 프론트엔드 연결].*
