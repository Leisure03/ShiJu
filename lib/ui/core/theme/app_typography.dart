import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// 东方宋刻本与文楷字体排版系统
class AppTypography {
  AppTypography._();

  static const String primaryFontFamily = 'Noto Serif SC';

  /// 中文字体回退栈：优先使用 CDN 引入的思源宋体与霞鹜文楷，并兼容 iOS / 桌面端各平台系统宋刻/楷书与苹方字体
  static const List<String> chineseSerifFallback = <String>[
    'LXGW WenKai',
    'Noto Serif SC',
    'Source Han Serif SC',
    'Songti SC',
    'STSong',
    'STKaiti',
    'PingFang SC',
    'Hiragino Sans GB',
    'Heiti SC',
    'FZShuSong-Z01S',
    'SimSun',
    'NSimSun',
    'KaiTi',
    'serif',
  ];

  static bool _cdnFontLoaded = false;

  /// 通过 CDN 异步加载开源中文字体（桌面/移动端通过 FontLoader 注入，Web 端由 index.html + FontLoader 双重保障）
  /// 若处于离线或测试环境，静默降级至 chineseSerifFallback 字体栈，不阻塞首屏渲染。
  static Future<void> preloadCdnFonts() async {
    if (_cdnFontLoaded) return;
    _cdnFontLoaded = true;
    try {
      // Google Fonts Noto Serif SC Regular Subset / OTF CDN
      final Uri cdnUri = Uri.parse(
        'https://fonts.gstatic.com/s/notoserifsc/v31/H4cyBXePl9DZ0Xe7gG9cyOj7uK2-n-D2rd4FY7SCqyWv.ttf',
      );
      final http.Response response = await http
          .get(cdnUri)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final FontLoader loader = FontLoader(primaryFontFamily);
        loader.addFont(
          Future<ByteData>.value(ByteData.sublistView(response.bodyBytes)),
        );
        await loader.load();
      }
    } catch (e) {
      debugPrint('CDN font fallback to local Songti/WenKai stack: $e');
    }
  }

  /// 首页精选名句大字（横排）
  static TextStyle quoteHorizontal(Color color, {double fontSize = 28}) {
    return TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: chineseSerifFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      height: 1.75,
      letterSpacing: 2.2,
      color: color,
    );
  }

  /// 首页精选名句大字（古籍竖排单字样式）
  static TextStyle quoteVerticalChar(Color color, {double fontSize = 26}) {
    return TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: chineseSerifFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      height: 1.18,
      color: color,
    );
  }

  /// 诗词详情页标题
  static TextStyle poemTitle(Color color, {double fontSize = 26}) {
    return TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: chineseSerifFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 2.0,
      color: color,
    );
  }

  /// 诗词全文正文（按句分行）
  static TextStyle poemBody(
    Color color, {
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: chineseSerifFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.95,
      letterSpacing: 1.6,
      color: color,
    );
  }

  /// 朝代·作者·诗名 题跋小字
  static TextStyle attribution(Color color, {double fontSize = 14}) {
    return TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: chineseSerifFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 1.4,
      color: color,
    );
  }

  /// 赏析、译文、生平长文阅读样式
  static TextStyle prose(Color color, {double fontSize = 15.5}) {
    return TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: chineseSerifFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      height: 1.85,
      letterSpacing: 0.6,
      color: color,
    );
  }

  /// 章节小标题
  static TextStyle sectionHeading(Color color, {double fontSize = 17}) {
    return TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: chineseSerifFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 1.5,
      color: color,
    );
  }

  /// 朱砂印章篆刻质感文字
  static TextStyle sealStamp(Color color, {double fontSize = 12}) {
    return TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: chineseSerifFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: 1.2,
      color: color,
    );
  }

  /// 辅助标签/按钮文字
  static TextStyle label(
    Color color, {
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: chineseSerifFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.3,
      letterSpacing: 0.8,
      color: color,
    );
  }
}
