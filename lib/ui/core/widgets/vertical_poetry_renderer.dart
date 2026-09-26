import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../theme/traditional_palette.dart';

/// 古籍竖排（writing-mode: vertical-rl）渲染组件
/// 支持单句名句分列竖排、全诗多列竖排、乌丝栏分栏线以及朱砂红名句高亮
class VerticalPoetryRenderer extends StatelessWidget {
  const VerticalPoetryRenderer({
    super.key,
    required this.lines,
    required this.palette,
    this.fontSize = 26,
    this.columnSpacing = 22,
    this.charSpacing = 4,
    this.showRulingLines = true,
    this.highlightedLinePredicate,
    this.attributionText,
  });

  /// 诗句列表（将自动按子句拆分为自右向左排布的竖列）
  final List<String> lines;
  final TraditionalPalette palette;
  final double fontSize;
  final double columnSpacing;
  final double charSpacing;

  /// 是否显示古籍乌丝栏细微竖向分割线
  final bool showRulingLines;

  /// 判断某列是否需要朱砂红高亮（用于详情页全诗竖排）
  final bool Function(String clause)? highlightedLinePredicate;

  /// 左侧落款题跋（如：〔元〕唐温如 · 题龙阳县青草湖）
  final String? attributionText;

  /// 将输入诗句拆分为适合竖排展示的单列子句
  static List<String> splitIntoVerticalColumns(List<String> rawLines) {
    final List<String> result = <String>[];
    for (final String raw in rawLines) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      // 若单行较长且包含逗号/分号/句号/问号/感叹号，按标点切分为独立竖排分列，还原宋刻本句读美感
      final RegExp exp = RegExp(r'[^，。！？；]+[，。！？；]?');
      final Iterable<RegExpMatch> matches = exp.allMatches(trimmed);
      if (matches.isEmpty) {
        result.add(trimmed);
      } else {
        for (final RegExpMatch m in matches) {
          final String clause = m.group(0)!.trim();
          if (clause.isNotEmpty) {
            result.add(clause);
          }
        }
      }
    }
    return result;
  }

  /// 将横排标点转换为古籍竖排视觉友好的符号
  static String toVerticalGlyph(String ch) {
    return switch (ch) {
      '《' => '︽',
      '》' => '︾',
      '〔' => '︹',
      '〕' => '︺',
      '（' => '︵',
      '）' => '︶',
      '“' => '﹁',
      '”' => '﹂',
      '‘' => '﹃',
      '’' => '﹄',
      '—' => '︱',
      _ => ch,
    };
  }

  static bool _isPunctuation(String ch) {
    return '，。！？；：、︽︾︹︺︵︶﹁﹂﹃﹄'.contains(ch);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> columns = splitIntoVerticalColumns(lines);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // 默认视角聚焦右侧起首列
      physics: const BouncingScrollPhysics(),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl, // 从右至左排布各列 (vertical-rl)
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < columns.length; i++) ...<Widget>[
              _buildColumn(columns[i]),
              if (i < columns.length - 1)
                _buildColumnDivider(
                  height: columns[i].length * (fontSize + charSpacing) + 12,
                ),
            ],
            if (attributionText != null &&
                attributionText!.trim().isNotEmpty) ...<Widget>[
              SizedBox(width: columnSpacing * 0.9),
              _buildAttributionColumn(attributionText!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColumn(String clause) {
    final bool isHighlighted = highlightedLinePredicate?.call(clause) ?? false;
    final List<String> chars = clause.split('');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isHighlighted ? 8.0 : 4.0,
        vertical: 8.0,
      ),
      decoration: isHighlighted
          ? BoxDecoration(
              color: palette.cinnabarRed.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(4),
              border: Border(
                right: BorderSide(
                  color: palette.cinnabarRed.withValues(alpha: 0.80),
                  width: 2.0,
                ),
              ),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: chars.map((String rawChar) {
          final String ch = toVerticalGlyph(rawChar);
          final bool isPunct = _isPunctuation(ch);

          if (isPunct && ('，。！？；、'.contains(ch))) {
            // 古籍句读符号置于字的右下侧或略微偏右，视觉更透气
            return Padding(
              padding: const EdgeInsets.only(top: 1, bottom: 3),
              child: SizedBox(
                width: fontSize,
                height: fontSize * 0.68,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    ch,
                    style: AppTypography.quoteVerticalChar(
                      isHighlighted
                          ? palette.cinnabarRed
                          : palette.themeAccent.withValues(alpha: 0.75),
                      fontSize: fontSize * 0.68,
                    ),
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.symmetric(vertical: charSpacing / 2),
            child: Text(
              ch,
              style: AppTypography.quoteVerticalChar(
                isHighlighted ? palette.inkText : palette.inkText,
                fontSize: fontSize,
              ).copyWith(
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildColumnDivider({required double height}) {
    if (!showRulingLines) {
      return SizedBox(width: columnSpacing);
    }
    return SizedBox(
      width: columnSpacing,
      child: Center(
        child: Container(
          width: 0.8,
          constraints: BoxConstraints(minHeight: height.clamp(120.0, 420.0)),
          color: palette.borderLine,
        ),
      ),
    );
  }

  Widget _buildAttributionColumn(String text) {
    final List<String> chars = text.replaceAll(' ', '').split('');
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8, left: 4, right: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: chars.map((String rawCh) {
          final String ch = toVerticalGlyph(rawCh);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Text(
              ch,
              style: AppTypography.attribution(
                palette.secondaryText,
                fontSize: 13.5,
              ).copyWith(height: 1.15, letterSpacing: 0),
            ),
          );
        }).toList(),
      ),
    );
  }
}
