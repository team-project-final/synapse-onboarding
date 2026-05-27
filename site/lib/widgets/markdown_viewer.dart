import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:synapse_onboarding/widgets/code_block.dart';
import 'package:synapse_onboarding/widgets/mermaid_view.dart';

class MarkdownViewer extends StatelessWidget {
  final String data;

  /// Invoked when an in-body markdown link is tapped. Defaults to opening the
  /// href in an external browser tab. Injectable so widget tests can assert
  /// the href without hitting the url_launcher platform channel.
  final void Function(String href)? onLinkTap;

  const MarkdownViewer({super.key, required this.data, this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: data,
      selectable: true,
      padding: const EdgeInsets.all(24),
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        h1: Theme.of(context).textTheme.headlineLarge,
        h2: Theme.of(context).textTheme.headlineMedium?.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: Theme.of(context).colorScheme.outlineVariant,
            ),
        h3: Theme.of(context).textTheme.titleLarge,
        blockquotePadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 4,
            ),
          ),
        ),
        tableBorder: TableBorder.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        tableHead: const TextStyle(fontWeight: FontWeight.bold),
        tableCellsPadding: const EdgeInsets.all(8),
      ),
      onTapLink: (text, href, title) {
        if (href == null || href.isEmpty) return;
        (onLinkTap ?? _launchExternal)(href);
      },
      builders: {
        'code': _CodeBlockBuilder(),
      },
    );
  }

  static Future<void> _launchExternal(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(element, preferredStyle) {
    if (element.textContent.isEmpty) return null;

    final language = element.attributes['class']?.replaceFirst('language-', '');

    if (language == 'mermaid') {
      return MermaidView(code: element.textContent.trimRight());
    }

    if (element.textContent.contains('\n') || language != null) {
      return CodeBlockWidget(
        code: element.textContent.trimRight(),
        language: language,
      );
    }

    return null;
  }
}
