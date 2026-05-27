import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_onboarding/widgets/markdown_viewer.dart';
import 'package:synapse_onboarding/widgets/mermaid_view.dart';
import 'package:synapse_onboarding/widgets/code_block.dart';

void main() {
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
