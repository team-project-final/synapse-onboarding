import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

@JS('renderMermaid')
external JSPromise<JSString> _renderMermaid(JSString id, JSString code);

int _seq = 0;

/// Flutter Web에서 mermaid 코드블록을 SVG로 렌더한다.
/// index.html의 `window.renderMermaid(id, code)` (svg 문자열 Promise 반환)를 호출하고,
/// 반환된 SVG 마크업을 HtmlElementView 안의 div에 주입한다.
class MermaidView extends StatefulWidget {
  final String code;
  const MermaidView({super.key, required this.code});

  @override
  State<MermaidView> createState() => _MermaidViewState();
}

class _MermaidViewState extends State<MermaidView> {
  late final String _viewType;
  final web.HTMLDivElement _host =
      (web.document.createElement('div') as web.HTMLDivElement)
        ..style.width = '100%'
        ..style.overflowX = 'auto';
  double _height = 80;
  String? _error;

  @override
  void initState() {
    super.initState();
    _viewType = 'mermaid-${_seq++}';
    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int _) => _host);
    _render();
  }

  // index.html의 module 스크립트가 renderMermaid를 비동기로 등록하므로 잠깐 기다린다.
  Future<bool> _waitForRenderer() async {
    for (var i = 0; i < 60; i++) {
      if (globalContext.has('renderMermaid')) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  Future<void> _render() async {
    try {
      final ready = await _waitForRenderer();
      if (!ready) throw StateError('renderMermaid not available');
      final id = 'mmd${DateTime.now().microsecondsSinceEpoch}';
      final svg =
          (await _renderMermaid(id.toJS, widget.code.toJS).toDart).toDart;
      _host.innerHTML = svg.toJS;
      final svgEl = _host.querySelector('svg');
      final measured = svgEl?.getBoundingClientRect().height ?? 0;
      if (mounted) {
        setState(() => _height = measured > 0 ? measured + 16 : 240);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFDEAEA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(
          '다이어그램 렌더 실패: $_error\n\n${widget.code}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      height: _height,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
