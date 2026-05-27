import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_onboarding/widgets/markdown_viewer.dart';
import 'package:synapse_onboarding/widgets/mermaid_view.dart';
import 'package:synapse_onboarding/widgets/code_block.dart';

void main() {
  testWidgets('markdown links are tappable and route the href to onLinkTap',
      (tester) async {
    String? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownViewer(
          data: '- [03 아키텍처 정의서](https://github.com/team/wiki/03_arch)',
          onLinkTap: (href) => tapped = href,
        ),
      ),
    ));

    final md = tester.widget<Markdown>(find.byType(Markdown));
    expect(md.onTapLink, isNotNull,
        reason: 'links do nothing without an onTapLink handler');

    md.onTapLink!('03 아키텍처 정의서', 'https://github.com/team/wiki/03_arch', '');
    expect(tapped, 'https://github.com/team/wiki/03_arch');
  });

  testWidgets('null or empty href is ignored, not routed', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownViewer(
          data: '[broken]()',
          onLinkTap: (_) => calls++,
        ),
      ),
    ));

    final md = tester.widget<Markdown>(find.byType(Markdown));
    md.onTapLink!('broken', null, '');
    md.onTapLink!('broken', '', '');
    expect(calls, 0);
  });

  testWidgets('mermaid fenced block renders MermaidView, not CodeBlock',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MarkdownViewer(data: '```mermaid\ngraph LR; A-->B;\n```'),
      ),
    ));
    expect(find.byType(MermaidView), findsOneWidget);
    expect(find.byType(CodeBlockWidget), findsNothing);
  });

  testWidgets('non-mermaid code block renders CodeBlockWidget', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MarkdownViewer(data: '```dart\nvoid main() {}\n```'),
      ),
    ));
    expect(find.byType(CodeBlockWidget), findsOneWidget);
    expect(find.byType(MermaidView), findsNothing);
  });
}
