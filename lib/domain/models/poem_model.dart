import 'package:flutter/foundation.dart';
import '../../ui/core/theme/traditional_palette.dart';

/// 诗词重点字词/典故注释条目
@immutable
class PoemAnnotation {
  const PoemAnnotation({
    required this.term,
    required this.explanation,
  });

  factory PoemAnnotation.fromJson(Map<String, dynamic> json) {
    return PoemAnnotation(
      term: (json['term'] as String?) ?? '',
      explanation: (json['explanation'] as String?) ?? '',
    );
  }

  /// 注释词条（如「青草湖」「星河」）
  final String term;

  /// 释义说明
  final String explanation;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'term': term,
        'explanation': explanation,
      };
}

/// 「诗泉 (poetry.palemoky.com)」云端数据库统计信息模型
@immutable
class ShiquanStats {
  const ShiquanStats({
    this.poems = 371313,
    this.authors = 13577,
    this.dynasties = 11,
    this.types = 17,
  });

  factory ShiquanStats.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data =
        (json['data'] is Map<String, dynamic>)
            ? json['data'] as Map<String, dynamic>
            : json;
    return ShiquanStats(
      poems: (data['poems'] as num?)?.toInt() ?? 371313,
      authors: (data['authors'] as num?)?.toInt() ?? 13577,
      dynasties: (data['dynasties'] as num?)?.toInt() ?? 11,
      types: (data['types'] as num?)?.toInt() ?? 17,
    );
  }

  final int poems;
  final int authors;
  final int dynasties;
  final int types;
}

/// 诗人生平小传模型
@immutable
class Author {
  const Author({
    required this.id,
    required this.name,
    required this.dynasty,
    required this.courtesyName,
    required this.lifeSpan,
    required this.biography,
  });

  final String id;
  final String name;
  final String dynasty;

  /// 字号（如：字子瞻，号东坡居士）
  final String courtesyName;

  /// 生卒年（如：1037年—1101年）
  final String lifeSpan;

  /// 详实生平简介
  final String biography;
}

/// 诗词与深度赏析完整领域模型
@immutable
class Poem {
  const Poem({
    required this.id,
    required this.featuredQuote,
    required this.title,
    required this.dynasty,
    required this.authorId,
    required this.authorName,
    required this.paragraphs,
    required this.tags,
    required this.paletteType,
    required this.translation,
    required this.annotations,
    required this.background,
    required this.appreciation,
    this.isRemote = false,
    this.genre,
  });

  factory Poem.fromJson(Map<String, dynamic> json) {
    final String paletteName =
        (json['paletteType'] as String?) ?? PaletteType.xuanPaper.name;
    final PaletteType resolvedPalette = PaletteType.values.firstWhere(
      (PaletteType e) => e.name == paletteName,
      orElse: () => PaletteType.xuanPaper,
    );
    final List<dynamic> rawParagraphs =
        (json['paragraphs'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> rawTags =
        (json['tags'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> rawAnnotations =
        (json['annotations'] as List<dynamic>?) ?? const <dynamic>[];

    return Poem(
      id: (json['id'] as String?) ?? '',
      featuredQuote: (json['featuredQuote'] as String?) ?? '',
      title: (json['title'] as String?) ?? '无题',
      dynasty: (json['dynasty'] as String?) ?? '唐',
      authorId: (json['authorId'] as String?) ?? 'unknown',
      authorName: (json['authorName'] as String?) ?? '佚名',
      paragraphs: rawParagraphs.whereType<String>().toList(),
      tags: rawTags.whereType<String>().toList(),
      paletteType: resolvedPalette,
      translation: (json['translation'] as String?) ?? '',
      annotations: rawAnnotations
          .whereType<Map<String, dynamic>>()
          .map(PoemAnnotation.fromJson)
          .toList(),
      background: (json['background'] as String?) ?? '',
      appreciation: (json['appreciation'] as String?) ?? '',
      isRemote: (json['isRemote'] as bool?) ?? true,
      genre: json['genre'] as String?,
    );
  }

  final String id;

  /// 首页诗笺卡片展示的精选名句
  final String featuredQuote;

  /// 诗名（不含书名号）
  final String title;

  /// 朝代（如：唐、宋、元、清）
  final String dynasty;

  /// 关联诗人 ID
  final String authorId;

  /// 诗人姓名
  final String authorName;

  /// 按句分行的完整诗词全文
  final List<String> paragraphs;

  /// 意境分类标签（不含 # 前缀，渲染时展示 #）
  final List<String> tags;

  /// 绑定的中国传统色主题
  final PaletteType paletteType;

  /// 白话文诗意翻译
  final String translation;

  /// 重点字词/典故逐条注释
  final List<PoemAnnotation> annotations;

  /// 创作背景与生平境遇
  final String background;

  /// 文学审美鉴赏
  final String appreciation;

  /// 是否来自「诗泉 API」云端诗库
  final bool isRemote;

  /// 诗词体裁分类（如：五言律诗、七言绝句、宋词）
  final String? genre;

  /// 格式化题跋出处：〔朝代〕作者 ·《诗名》
  String get formattedAttribution => '〔$dynasty〕$authorName ·《$title》';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'featuredQuote': featuredQuote,
        'title': title,
        'dynasty': dynasty,
        'authorId': authorId,
        'authorName': authorName,
        'paragraphs': paragraphs,
        'tags': tags,
        'paletteType': paletteType.name,
        'translation': translation,
        'annotations':
            annotations.map((PoemAnnotation a) => a.toJson()).toList(),
        'background': background,
        'appreciation': appreciation,
        'isRemote': isRemote,
        'genre': genre,
      };

  /// 判断完整诗词中的某一行是否属于首页推荐名句，用于详情页朱砂红底纹与下划线高亮
  bool isLineHighlighted(String line) {
    final String normalizedLine = _normalizePunctuation(line);
    final String normalizedQuote = _normalizePunctuation(featuredQuote);
    if (normalizedLine.isEmpty || normalizedQuote.isEmpty) {
      return false;
    }
    return normalizedQuote.contains(normalizedLine) ||
        normalizedLine.contains(normalizedQuote);
  }

  static String _normalizePunctuation(String input) {
    return input
        .replaceAll(RegExp(r'[，。！？；：、“”‘’《》\s,.!?;:]'), '')
        .trim();
  }
}
