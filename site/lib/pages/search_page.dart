import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_onboarding/models/doc.dart';
import 'package:synapse_onboarding/models/search_index.dart';
import 'package:synapse_onboarding/widgets/search_bar_widget.dart';
import 'package:synapse_onboarding/widgets/tag_chip.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _engine = SearchEngine();
  List<DocIndex> _allDocs = [];
  List<SearchResult> _results = [];
  String? _selectedCategory;
  bool _loading = true;

  // 눌러서 바로 검색되는 추천 키워드 (모두 실제 결과가 나오는 것만 선별).
  static const Map<String, List<String>> _suggestions = {
    '구조·흐름': ['멀티테넌시', 'Kafka', 'gRPC', '테넌트', '라우팅'],
    '핵심 기능': ['위키링크', '복습', '리더보드', '그래프', 'RAG', '임베딩', '배지'],
    '기술 스택': ['JWT', 'pgvector', 'Redis', 'Elasticsearch', 'Riverpod', 'Gateway', 'FastAPI', 'LangChain'],
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _engine.load();
    final jsonStr = await rootBundle.loadString('assets/docs/index.json');
    final list = json.decode(jsonStr) as List;
    setState(() {
      _allDocs = list
          .map((e) => DocIndex.fromJson(e as Map<String, dynamic>))
          .toList();
      _loading = false;
    });
  }

  void _onSearch(String query) {
    setState(() {
      _results =
          _engine.search(query, categoryFilter: _selectedCategory);
    });
  }

  // 추천 키워드 칩 탭 → 검색창에 채우고 즉시 검색
  void _runSuggested(String keyword) {
    _controller.text = keyword;
    _onSearch(keyword);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SearchBarWidget(
            controller: _controller,
            onChanged: _onSearch,
            hintText: '키워드로 문서 검색...',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: _selectedCategory == null,
                onSelected: (_) {
                  setState(() => _selectedCategory = null);
                  _onSearch(_controller.text);
                },
              ),
              for (final cat in DocCategory.values)
                ChoiceChip(
                  label: Text(cat.displayName),
                  selected: _selectedCategory == cat.id,
                  onSelected: (_) {
                    setState(() => _selectedCategory =
                        _selectedCategory == cat.id ? null : cat.id);
                    _onSearch(_controller.text);
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _controller.text.isEmpty
                ? _buildGuidance(context)
                : _results.isEmpty
                    ? _buildNoResults(context)
                    : _buildResults(context),
          ),
        ],
      ),
    );
  }

  // 검색 전 안내: 무엇을 검색할 수 있고, 무엇을 입력하면 무엇이 나오는지
  Widget _buildGuidance(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_allDocs.length}개 문서의 제목과 본문에서 검색합니다. '
                  '아래 키워드를 누르면 바로 검색돼요.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (final entry in _suggestions.entries) ...[
            Text(entry.key, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kw in entry.value)
                  ActionChip(
                    avatar: const Icon(Icons.search, size: 16),
                    label: Text(kw),
                    onPressed: () => _runSuggested(kw),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          const Divider(),
          const SizedBox(height: 8),
          Text(
            '💡 전체 단어가 아니어도 일부만 입력하면 됩니다. 예: "pgvector", "리더보드", "JWT". '
            '위의 카테고리 칩으로 검색 범위를 좁힐 수도 있어요.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 40, color: muted),
          const SizedBox(height: 12),
          Text('"${_controller.text}" 에 대한 결과가 없습니다',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text('다른 키워드를 시도해 보세요 (예: Kafka, JWT, 리더보드)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final r = _results[index];
        final doc = _allDocs.where((d) => d.slug == r.slug).firstOrNull;
        final title = doc?.title ?? r.slug;
        final cat = DocCategory.fromString(r.category);
        return ListTile(
          leading: Text(cat.icon, style: const TextStyle(fontSize: 20)),
          title: Text(title),
          subtitle: doc != null && doc.summary.isNotEmpty
              ? Text(doc.summary, maxLines: 2, overflow: TextOverflow.ellipsis)
              : Text(cat.displayName),
          trailing: doc != null
              ? Wrap(
                  spacing: 4,
                  children: [for (final t in doc.tags) TagChip(tag: t)],
                )
              : null,
          onTap: () => context.go('/docs/${r.category}/${r.slug}'),
        );
      },
    );
  }
}
