import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:synapse_onboarding/pages/home_page.dart';
import 'package:synapse_onboarding/pages/doc_page.dart';
import 'package:synapse_onboarding/pages/search_page.dart';
import 'package:synapse_onboarding/widgets/sidebar.dart';

final _router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
        GoRoute(
          path: '/docs/:category/:slug',
          builder: (context, state) => DocPage(
            category: state.pathParameters['category']!,
            slug: state.pathParameters['slug']!,
          ),
        ),
      ],
    ),
  ],
);

class SynapseOnboardingApp extends StatelessWidget {
  const SynapseOnboardingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Synapse 신입 온보딩',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFD97706),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansKrTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFFAFAF9),
      ),
      routerConfig: _router,
    );
  }
}

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => context.go('/'),
          child: const Text('Synapse 신입 온보딩'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
        ],
      ),
      drawer: isWide ? null : const Drawer(child: Sidebar()),
      body: Row(
        children: [
          if (isWide) const SizedBox(width: 280, child: Sidebar()),
          Expanded(child: child),
        ],
      ),
    );
  }
}
