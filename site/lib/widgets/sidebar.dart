import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_onboarding/models/doc.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  List<DocIndex> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final docsJson = await rootBundle.loadString('assets/docs/index.json');
      final docsList = json.decode(docsJson) as List;
      _docs = docsList
          .map((e) => DocIndex.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final grouped = <DocCategory, List<DocIndex>>{};
    for (final d in _docs) {
      grouped.putIfAbsent(d.category, () => []).add(d);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          leading: const Icon(Icons.home),
          title: const Text('홈'),
          onTap: () => context.go('/'),
        ),
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('검색'),
          onTap: () => context.go('/search'),
        ),
        const Divider(),
        for (final cat in DocCategory.values)
          if (grouped.containsKey(cat))
            ExpansionTile(
              initiallyExpanded: true,
              leading: Text(cat.icon, style: const TextStyle(fontSize: 16)),
              title: Text('${cat.displayName} (${grouped[cat]!.length})'),
              children: [
                for (final doc in grouped[cat]!)
                  ListTile(
                    title: Text(doc.title,
                        style: Theme.of(context).textTheme.bodySmall),
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 56),
                    onTap: () =>
                        context.go('/docs/${doc.category.id}/${doc.slug}'),
                  ),
              ],
            ),
      ],
    );
  }
}
