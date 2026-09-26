import 'package:flutter/foundation.dart';
import '../../ui/core/theme/traditional_palette.dart';

/// 诗词重点字词/典故注释条目
@immutable
class PoemAnnotation {
  const PoemAnnotation({
    required this.term,
    required this.explanation,
  });

  /// 注释词条（如「青草湖」「星河」）
  final String term;

  /// 释义说明
  final String explanation;
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
  });

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

  /// 格式化题跋出处：〔朝代〕作者 ·《诗名》
  String get formattedAttribution => '〔$dynasty〕$authorName ·《$title》';

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
