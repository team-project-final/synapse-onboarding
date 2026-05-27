import 'package:flutter/material.dart';

/// 비웹/테스트 환경 폴백: 다이어그램 소스를 코드 텍스트로 표시한다.
class MermaidView extends StatelessWidget {
  final String code;
  const MermaidView({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText('[mermaid]\n$code',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
    );
  }
}
