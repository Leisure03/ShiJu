import 'package:flutter/material.dart';

/// 中国传统色主题枚举
enum PaletteType {
  /// 宣纸白（默认浅色底）：#F7F4ED，配墨黑字 #2C2B29
  xuanPaper,

  /// 天水碧：#D4E5E3，主题深色 #3A6965
  tianShuiBi,

  /// 松花黄：#F4F0D6，主题深色 #6E683B
  songHuaHuang,

  /// 暮山紫：#E4DFEC，主题深色 #56476D
  muShanZi,

  /// 胭脂粉：#F2DFE1，主题深色 #8B4249
  yanZhiFen,

  /// 玄青色（夜间模式）：#1A1C1E，配月白字 #E2E1DC
  xuanQingDark,
}

/// 东方美学视觉色板定义
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

  /// 主正文墨色
  final Color inkText;

  /// 次级正文颜色
  final Color secondaryText;

  /// 辅助题跋/时间浅墨色
  final Color mutedText;

  /// 传统色主题深色（点缀、高亮、标签）
  final Color themeAccent;

  /// 朱砂印章红（固定 #C03F3C）
  final Color cinnabarRed;

  /// 细微边框线条（模拟 border-stone-800/10）
  final Color borderLine;

  /// 是否为玄青夜间模式
  final bool isDark;

  /// 朱砂红常量 (#C03F3C)
  static const Color kCinnabarRed = Color(0xFFC03F3C);

  /// 宣纸白常量 (#F7F4ED)
  static const Color kXuanPaperWhite = Color(0xFFF7F4ED);

  /// 墨黑常量 (#2C2B29)
  static const Color kInkBlack = Color(0xFF2C2B29);

  /// 玄青常量 (#1A1C1E)
  static const Color kXuanQing = Color(0xFF1A1C1E);

  /// 月白常量 (#E2E1DC)
  static const Color kMoonWhite = Color(0xFFE2E1DC);

  /// 1. 宣纸白（默认浅色底）：#F7F4ED，配墨黑字 #2C2B29
  static const TraditionalPalette xuanPaper = TraditionalPalette(
    type: PaletteType.xuanPaper,
    name: '宣纸白',
    poeticDescription: '轻似蝉翼白如雪，抖似细绸不闻声',
    background: Color(0xFFF7F4ED),
    cardSurface: Color(0xFFFCFBF7),
    elevatedSurface: Color(0xFFF1EDE2),
    inkText: Color(0xFF2C2B29),
    secondaryText: Color(0xFF524F4A),
    mutedText: Color(0xFF7D7870),
    themeAccent: Color(0xFF5C5446),
    cinnabarRed: kCinnabarRed,
    borderLine: Color(0x1A2C2B29),
    isDark: false,
  );

  /// 2. 天水碧：#D4E5E3，主题深色 #3A6965
  static const TraditionalPalette tianShuiBi = TraditionalPalette(
    type: PaletteType.tianShuiBi,
    name: '天水碧',
    poeticDescription: '雨过天青云破处，秋水共长天一色',
    background: Color(0xFFD4E5E3),
    cardSurface: Color(0xFFEFF6F5),
    elevatedSurface: Color(0xFFC6DCDA),
    inkText: Color(0xFF2C2B29),
    secondaryText: Color(0xFF35524F),
    mutedText: Color(0xFF587673),
    themeAccent: Color(0xFF3A6965),
    cinnabarRed: kCinnabarRed,
    borderLine: Color(0x1F3A6965),
    isDark: false,
  );

  /// 3. 松花黄：#F4F0D6，主题深色 #6E683B
  static const TraditionalPalette songHuaHuang = TraditionalPalette(
    type: PaletteType.songHuaHuang,
    name: '松花黄',
    poeticDescription: '轻如松花落金粉，新绿微黄春意融',
    background: Color(0xFFF4F0D6),
    cardSurface: Color(0xFFFAF8EB),
    elevatedSurface: Color(0xFFEBE5C3),
    inkText: Color(0xFF2C2B29),
    secondaryText: Color(0xFF524E36),
    mutedText: Color(0xFF787354),
    themeAccent: Color(0xFF6E683B),
    cinnabarRed: kCinnabarRed,
    borderLine: Color(0x1F6E683B),
    isDark: false,
  );

  /// 4. 暮山紫：#E4DFEC，主题深色 #56476D
  static const TraditionalPalette muShanZi = TraditionalPalette(
    type: PaletteType.muShanZi,
    name: '暮山紫',
    poeticDescription: '潦水尽而寒潭清，烟光凝而暮山紫',
    background: Color(0xFFE4DFEC),
    cardSurface: Color(0xFFF4F1F8),
    elevatedSurface: Color(0xFFD8D0E3),
    inkText: Color(0xFF2C2B29),
    secondaryText: Color(0xFF473E57),
    mutedText: Color(0xFF6E6380),
    themeAccent: Color(0xFF56476D),
    cinnabarRed: kCinnabarRed,
    borderLine: Color(0x1F56476D),
    isDark: false,
  );

  /// 5. 胭脂粉：#F2DFE1，主题深色 #8B4249
  static const TraditionalPalette yanZhiFen = TraditionalPalette(
    type: PaletteType.yanZhiFen,
    name: '胭脂粉',
    poeticDescription: '林花谢了春红，胭脂泪，相留醉',
    background: Color(0xFFF2DFE1),
    cardSurface: Color(0xFFFAF1F2),
    elevatedSurface: Color(0xFFE8CFD2),
    inkText: Color(0xFF2C2B29),
    secondaryText: Color(0xFF5E393D),
    mutedText: Color(0xFF825B5F),
    themeAccent: Color(0xFF8B4249),
    cinnabarRed: kCinnabarRed,
    borderLine: Color(0x1F8B4249),
    isDark: false,
  );

  /// 6. 玄青色（夜间模式）：#1A1C1E，配月白字 #E2E1DC
  static const TraditionalPalette xuanQingDark = TraditionalPalette(
    type: PaletteType.xuanQingDark,
    name: '玄青色',
    poeticDescription: '天地玄黄，月白风清，万籁俱寂',
    background: Color(0xFF1A1C1E),
    cardSurface: Color(0xFF232629),
    elevatedSurface: Color(0xFF2C3034),
    inkText: Color(0xFFE2E1DC),
    secondaryText: Color(0xFFB8B6AF),
    mutedText: Color(0xFF85837C),
    themeAccent: Color(0xFF8FA8A5),
    cinnabarRed: kCinnabarRed,
    borderLine: Color(0x1FE2E1DC),
    isDark: true,
  );

  /// 根据枚举与夜间模式获取对应色板
  static TraditionalPalette resolve(PaletteType type, {bool isDarkMode = false}) {
    if (isDarkMode) {
      return xuanQingDark;
    }
    return switch (type) {
      PaletteType.xuanPaper => xuanPaper,
      PaletteType.tianShuiBi => tianShuiBi,
      PaletteType.songHuaHuang => songHuaHuang,
      PaletteType.muShanZi => muShanZi,
      PaletteType.yanZhiFen => yanZhiFen,
      PaletteType.xuanQingDark => xuanQingDark,
    };
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
