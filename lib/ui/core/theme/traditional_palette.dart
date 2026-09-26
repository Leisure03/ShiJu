import 'package:flutter/material.dart';

/// 东方美学与莫兰迪撞色主题枚举（全局统一为「奶雾蔷薇 × 雾灰藕紫」双生配色）
enum PaletteType {
  /// 宣纸白（映射至奶雾蔷薇主色板）
  xuanPaper,

  /// 天水碧（映射至奶雾蔷薇主色板）
  tianShuiBi,

  /// 松花黄（映射至奶雾蔷薇主色板）
  songHuaHuang,

  /// 暮山紫（映射至奶雾蔷薇主色板）
  muShanZi,

  /// 胭脂粉（映射至奶雾蔷薇主色板）
  yanZhiFen,

  /// 雾灰藕紫（反转/夜间模式）：#A198A8 底配 #F8CDED 字
  xuanQingDark,
}

/// 「奶雾蔷薇 × 雾灰藕紫」视觉色板定义
@immutable
class TraditionalPalette {
  const TraditionalPalette({
    required this.type,
    required this.name,
    required this.poeticDescription,
    required this.background,
    required this.cardSurface,
    required this.elevatedSurface,
    required this.inkText,
    required this.secondaryText,
    required this.mutedText,
    required this.themeAccent,
    required this.cinnabarRed,
    required this.borderLine,
    required this.isDark,
  });

  final PaletteType type;
  final String name;
  final String poeticDescription;

  /// 页面背景主色
  final Color background;

  /// 诗笺卡片底色
  final Color cardSurface;

  /// 浮层/次级容器底色
  final Color elevatedSurface;

  /// 主正文颜色
  final Color inkText;

  /// 次级正文颜色
  final Color secondaryText;

  /// 辅助题跋/时间浅色
  final Color mutedText;

  /// 主题点缀色（雾灰藕紫 #A198A8 / 奶雾蔷薇 #F8CDED）
  final Color themeAccent;

  /// 印章与高亮重点色（融入藕紫蔷薇色系）
  final Color cinnabarRed;

  /// 细微边框线条
  final Color borderLine;

  /// 是否为「雾灰藕紫」反转（夜间）模式
  final bool isDark;

  /// 主题强调色按钮/标签上的反白或深色文字
  Color get onThemeAccent =>
      isDark ? const Color(0xFF4A4152) : const Color(0xFFFDF4FA);

  /// 印章/高亮实底上的文字颜色
  Color get onCinnabar =>
      isDark ? const Color(0xFF4A4152) : const Color(0xFFFDF4FA);

  /// 核心色值常量：奶雾蔷薇 (#F8CDED, RGB: 248, 205, 237)
  static const Color kNaiWuQiangWei = Color(0xFFF8CDED);

  /// 核心色值常量：雾灰藕紫 (#A198A8, RGB: 161, 152, 168)
  static const Color kWuHuiOuZi = Color(0xFFA198A8);

  /// 蔷薇藕紫印章色常量（替代原朱砂红，融入整体藕紫蔷薇色系）
  static const Color kCinnabarRed = Color(0xFF8E6B86);

  /// 奶雾粉白常量（用于深色按钮/印章上的浅色文字）
  static const Color kXuanPaperWhite = Color(0xFFFDF4FA);

  /// 深雾灰藕紫墨色常量 (#4A4152)
  static const Color kInkBlack = Color(0xFF4A4152);

  /// 雾灰藕紫常量 (#A198A8)
  static const Color kXuanQing = kWuHuiOuZi;

  /// 奶雾蔷薇亮色常量 (#F8CDED)
  static const Color kMoonWhite = kNaiWuQiangWei;

  /// 日间默认主色板：奶雾蔷薇 (#F8CDED) 为主背景，雾灰藕紫 (#A198A8) 为主题点缀与次级色
  static const TraditionalPalette naiWuQiangWei = TraditionalPalette(
    type: PaletteType.yanZhiFen,
    name: '奶雾蔷薇',
    poeticDescription: '晓雾凝香笼浅粉，藕紫微茫入梦来',
    background: kNaiWuQiangWei, // #F8CDED (RGB 248, 205, 237)
    cardSurface: Color(0xFFFDF3FA), // 清透奶雾粉白诗笺底
    elevatedSurface: Color(0xFFF3BEE4), // 柔雾蔷薇次级浮层
    inkText: Color(0xFF4A4152), // 深雾灰藕紫正文色
    secondaryText: Color(0xFF6E6477), // 中深雾灰藕紫次级文字
    mutedText: Color(0xFF8A8093), // 柔和雾灰藕紫辅助文字
    themeAccent: kWuHuiOuZi, // #A198A8 (RGB 161, 152, 168) 雾灰藕紫
    cinnabarRed: Color(0xFF8E6B86), // 蔷薇藕紫印章与高亮色
    borderLine: Color(0x38A198A8), // 雾灰藕紫细微边框线
    isDark: false,
  );

  /// 夜间/反转模式色板：雾灰藕紫 (#A198A8) 为主背景，奶雾蔷薇 (#F8CDED) 为文字与点缀色
  static const TraditionalPalette wuHuiOuZiDark = TraditionalPalette(
    type: PaletteType.xuanQingDark,
    name: '雾灰藕紫',
    poeticDescription: '雾霭凝灰生藕紫，蔷薇一抹映清欢',
    background: kWuHuiOuZi, // #A198A8 (RGB 161, 152, 168)
    cardSurface: Color(0xFF887E90), // 沉静深雾灰藕紫诗笺底，衬托 #F8CDED 蔷薇字色
    elevatedSurface: Color(0xFF7B7183), // 深藕紫次级容器底色
    inkText: kNaiWuQiangWei, // #F8CDED (RGB 248, 205, 237) 奶雾蔷薇主文字
    secondaryText: Color(0xFFFCE2F5), // 柔亮奶雾蔷薇次级文字
    mutedText: Color(0xFFE6C3DC), // 浅雾蔷薇辅助文字
    themeAccent: kNaiWuQiangWei, // #F8CDED 奶雾蔷薇主题点缀
    cinnabarRed: kNaiWuQiangWei, // #F8CDED 奶雾蔷薇印章与高亮
    borderLine: Color(0x3DF8CDED), // 奶雾蔷薇细微边框线
    isDark: true,
  );

  // 保持原有静态属性引用兼容，全局统一指向「奶雾蔷薇 × 雾灰藕紫」配色
  static const TraditionalPalette xuanPaper = naiWuQiangWei;
  static const TraditionalPalette tianShuiBi = naiWuQiangWei;
  static const TraditionalPalette songHuaHuang = naiWuQiangWei;
  static const TraditionalPalette muShanZi = naiWuQiangWei;
  static const TraditionalPalette yanZhiFen = naiWuQiangWei;
  static const TraditionalPalette xuanQingDark = wuHuiOuZiDark;

  /// 根据枚举与反转/夜间模式获取对应色板（全局统一使用奶雾蔷薇与雾灰藕紫）
  static TraditionalPalette resolve(PaletteType type, {bool isDarkMode = false}) {
    if (isDarkMode || type == PaletteType.xuanQingDark) {
      return wuHuiOuZiDark;
    }
    return naiWuQiangWei;
  }

  /// 支持在 TweenAnimationBuilder 中进行 700ms 颜色线性插值
  static TraditionalPalette lerp(
    TraditionalPalette a,
    TraditionalPalette b,
    double t,
  ) {
    return TraditionalPalette(
      type: t < 0.5 ? a.type : b.type,
      name: t < 0.5 ? a.name : b.name,
      poeticDescription: t < 0.5 ? a.poeticDescription : b.poeticDescription,
      background: Color.lerp(a.background, b.background, t)!,
      cardSurface: Color.lerp(a.cardSurface, b.cardSurface, t)!,
      elevatedSurface: Color.lerp(a.elevatedSurface, b.elevatedSurface, t)!,
      inkText: Color.lerp(a.inkText, b.inkText, t)!,
      secondaryText: Color.lerp(a.secondaryText, b.secondaryText, t)!,
      mutedText: Color.lerp(a.mutedText, b.mutedText, t)!,
      themeAccent: Color.lerp(a.themeAccent, b.themeAccent, t)!,
      cinnabarRed: Color.lerp(a.cinnabarRed, b.cinnabarRed, t)!,
      borderLine: Color.lerp(a.borderLine, b.borderLine, t)!,
      isDark: t < 0.5 ? a.isDark : b.isDark,
    );
  }
}
