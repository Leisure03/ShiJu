import 'package:flutter/material.dart';

/// 中国传统色动态主题枚举（宋代汝窑与古籍宣纸美学配色）
enum PaletteType {
  /// 宣纸白（澄心堂纸）：#F5F1E8，配徽墨字 #262421
  xuanPaper,

  /// 天水碧（汝窑天青）：#E2EEEB，主题深色 #2F6B66
  tianShuiBi,

  /// 松花黄（茗香竹露）：#F3EFE0，主题深色 #6A6436
  songHuaHuang,

  /// 暮山紫（烟岚远岫）：#ECE9F2，主题深色 #53466E
  muShanZi,

  /// 胭脂粉（绛雪春桃）：#F4E8E9，主题深色 #8C434B
  yanZhiFen,

  /// 玄青色（星河夜读）：#15191D，配月白字 #E8E4DC
  xuanQingDark,
}

/// 东方宋韵美学视觉色板定义
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

  /// 传统色主题点缀色（按钮、高亮、雅集标签）
  final Color themeAccent;

  /// 朱砂印章红（日间 #B83B36 / 夜间 #D4534E）
  final Color cinnabarRed;

  /// 细微乌丝栏边框线条
  final Color borderLine;

  /// 是否为玄青夜间模式
  final bool isDark;

  /// 主题强调色按钮/标签上的文字颜色
  Color get onThemeAccent =>
      isDark ? const Color(0xFF15191D) : kXuanPaperWhite;

  /// 朱砂印章/高亮实底上的文字颜色
  Color get onCinnabar => kXuanPaperWhite;

  /// 八宝印泥朱砂红常量 (#B83B36)
  static const Color kCinnabarRed = Color(0xFFB83B36);

  /// 澄心宣纸白常量 (#FCFBF8)
  static const Color kXuanPaperWhite = Color(0xFFFCFBF8);

  /// 徽墨浓黑常量 (#262421)
  static const Color kInkBlack = Color(0xFF262421);

  /// 玄青夜色常量 (#15191D)
  static const Color kXuanQing = Color(0xFF15191D);

  /// 月白亮色常量 (#E8E4DC)
  static const Color kMoonWhite = Color(0xFFE8E4DC);

  /// 1. 宣纸白（澄心堂纸）：温润米白底配松烟徽墨
  static const TraditionalPalette xuanPaper = TraditionalPalette(
    type: PaletteType.xuanPaper,
    name: '宣纸白',
    poeticDescription: '澄心堂纸如玉润，松烟墨落暗香浮',
    background: Color(0xFFF5F1E8),
    cardSurface: Color(0xFFFCFBF8),
    elevatedSurface: Color(0xFFECE6D9),
    inkText: Color(0xFF262421),
    secondaryText: Color(0xFF544F48),
    mutedText: Color(0xFF827B70),
    themeAccent: Color(0xFF6B5842),
    cinnabarRed: kCinnabarRed,
    borderLine: Color(0x1C262421),
    isDark: false,
  );

  /// 2. 天水碧（汝窑天青）：雨过天青微碧底配深青墨色
  static const TraditionalPalette tianShuiBi = TraditionalPalette(
    type: PaletteType.tianShuiBi,
    name: '天水碧',
    poeticDescription: '雨过天青云破处，秋水共长天一色',
    background: Color(0xFFE2EEEB),
    cardSurface: Color(0xFFF8FCFB),
    elevatedSurface: Color(0xFFD3E5E1),
    inkText: Color(0xFF1E2827),
    secondaryText: Color(0xFF3E5653),
    mutedText: Color(0xFF68827F),
    themeAccent: Color(0xFF2F6B66),
    cinnabarRed: kCinnabarRed,
    borderLine: Color(0x1E2F6B66),
    isDark: false,
  );

  /// 3. 松花黄（茗香竹露）：温润古玉黄绿底配茶褐墨色
  static const TraditionalPalette songHuaHuang = TraditionalPalette(
    type: PaletteType.songHuaHuang,
    name: '松花黄',
    poeticDescription: '轻如松花落金粉，新绿微黄春意融',
    background: Color(0xFFF3EFE0),
    cardSurface: Color(0xFFFCFBF5),
    elevatedSurface: Color(0xFFE8E2CC),
    inkText: Color(0xFF28261E),
    secondaryText: Color(0xFF57523E),
    mutedText: Color(0xFF807A62),
    themeAccent: Color(0xFF6A6436),
    cinnabarRed: kCinnabarRed,
    borderLine: Color(0x1E6A6436),
    isDark: false,
  );

  /// 4. 暮山紫（烟岚远岫）：清透远山云岚紫配紫檀墨色
  static const TraditionalPalette muShanZi = TraditionalPalette(
    type: PaletteType.muShanZi,
    name: '暮山紫',
    poeticDescription: '潦水尽而寒潭清，烟光凝而暮山紫',
    background: Color(0xFFECE9F2),
    cardSurface: Color(0xFFFAF9FC),
    elevatedSurface: Color(0xFFDFDAE9),
    inkText: Color(0xFF25222C),
    secondaryText: Color(0xFF4E475C),
    mutedText: Color(0xFF787088),
    themeAccent: Color(0xFF53466E),
    cinnabarRed: kCinnabarRed,
    borderLine: Color(0x1E53466E),
    isDark: false,
  );

  /// 5. 胭脂粉（绛雪春桃）：低饱和春梅浅绛底配苏芳深色
  static const TraditionalPalette yanZhiFen = TraditionalPalette(
    type: PaletteType.yanZhiFen,
    name: '胭脂粉',
    poeticDescription: '林花谢了春红，海棠初雨凝香露',
    background: Color(0xFFF4E8E9),
    cardSurface: Color(0xFFFCF8F8),
    elevatedSurface: Color(0xFFEAD9DB),
    inkText: Color(0xFF2B2223),
    secondaryText: Color(0xFF5E4346),
    mutedText: Color(0xFF886A6E),
    themeAccent: Color(0xFF8C434B),
    cinnabarRed: kCinnabarRed,
    borderLine: Color(0x1E8C434B),
    isDark: false,
  );

  /// 6. 玄青色（星河夜读）：苍穹玄青底配温润月白字与碧玉点缀
  static const TraditionalPalette xuanQingDark = TraditionalPalette(
    type: PaletteType.xuanQingDark,
    name: '玄青色',
    poeticDescription: '天地玄黄月如水，星河清梦入夜阑',
    background: Color(0xFF15191D),
    cardSurface: Color(0xFF1E242B),
    elevatedSurface: Color(0xFF272F38),
    inkText: Color(0xFFE8E4DC),
    secondaryText: Color(0xFFB4B0A8),
    mutedText: Color(0xFF7D8288),
    themeAccent: Color(0xFF78ABA6),
    cinnabarRed: Color(0xFFD4534E),
    borderLine: Color(0x1FE8E4DC),
    isDark: true,
  );

  /// 根据枚举与夜间模式获取对应色板
  static TraditionalPalette resolve(PaletteType type, {bool isDarkMode = false}) {
    if (isDarkMode || type == PaletteType.xuanQingDark) {
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
