enum DocCategory {
  overview,
  flow,
  services,
  code,
  practice;

  static DocCategory fromString(String value) {
    switch (value) {
      case 'overview':
        return DocCategory.overview;
      case 'flow':
        return DocCategory.flow;
      case 'services':
        return DocCategory.services;
      case 'code':
        return DocCategory.code;
      case 'practice':
        return DocCategory.practice;
      default:
        return DocCategory.overview;
    }
  }

  String get id => name;

  String get displayName {
    switch (this) {
      case DocCategory.overview:
        return '개요';
      case DocCategory.flow:
        return '흐름';
      case DocCategory.services:
        return '서비스 상세';
      case DocCategory.code:
        return '샘플 코드';
      case DocCategory.practice:
        return '실전';
    }
  }

  String get icon {
    switch (this) {
      case DocCategory.overview:
        return '\u{1F4D6}'; // 📖
      case DocCategory.flow:
        return '\u{1F500}'; // 🔀
      case DocCategory.services:
        return '\u{2699}\u{FE0F}'; // ⚙️
      case DocCategory.code:
        return '\u{1F9EA}'; // 🧪
      case DocCategory.practice:
        return '\u{1F680}'; // 🚀
    }
  }
}

class TocEntry {
  final int level;
  final String text;
  final String anchor;

  const TocEntry(
      {required this.level, required this.text, required this.anchor});

  factory TocEntry.fromJson(Map<String, dynamic> json) {
    return TocEntry(
      level: json['level'] as int,
      text: json['text'] as String,
      anchor: json['anchor'] as String,
    );
  }
}

class DocMetadata {
  final String? lastUpdated;
  final String status;
  final int? completionRate;

  const DocMetadata(
      {this.lastUpdated, this.status = 'active', this.completionRate});

  factory DocMetadata.fromJson(Map<String, dynamic> json) {
    return DocMetadata(
      lastUpdated: json['lastUpdated'] as String?,
      status: json['status'] as String? ?? 'active',
      completionRate: json['completionRate'] as int?,
    );
  }
}

class DocIndex {
  final String slug;
  final String title;
  final DocCategory category;
  final String source;
  final List<String> tags;
  final String summary;
  final DocMetadata metadata;

  const DocIndex({
    required this.slug,
    required this.title,
    required this.category,
    required this.source,
    required this.tags,
    required this.summary,
    required this.metadata,
  });

  factory DocIndex.fromJson(Map<String, dynamic> json) {
    return DocIndex(
      slug: json['slug'] as String,
      title: json['title'] as String,
      category: DocCategory.fromString(json['category'] as String),
      source: json['source'] as String,
      tags: List<String>.from(json['tags'] as List),
      summary: json['summary'] as String? ?? '',
      metadata:
          DocMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );
  }
}

class Doc extends DocIndex {
  final List<TocEntry> toc;
  final String body;

  const Doc({
    required super.slug,
    required super.title,
    required super.category,
    required super.source,
    required super.tags,
    required super.summary,
    required super.metadata,
    required this.toc,
    required this.body,
  });

  factory Doc.fromJson(Map<String, dynamic> json) {
    return Doc(
      slug: json['slug'] as String,
      title: json['title'] as String,
      category: DocCategory.fromString(json['category'] as String),
      source: json['source'] as String,
      tags: List<String>.from(json['tags'] as List),
      summary: json['summary'] as String? ?? '',
      metadata:
          DocMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      toc: (json['toc'] as List)
          .map((e) => TocEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      body: json['body'] as String,
    );
  }
}
