import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../theme/traditional_palette.dart';

/// 朱砂印章篆刻样式
enum SealStyle {
  /// 阳文印（朱砂红边框、红字、宣纸微透底）
  yang,

  /// 阴文印（朱砂红实底、宣纸白字、内嵌细框）
  yin,
}

/// 朱砂印章组件（#C03F3C）
class CinnabarSeal extends StatelessWidget {
  const CinnabarSeal({
    super.key,
    required this.text,
    this.style = SealStyle.yang,
    this.fontSize = 11.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
    this.borderRadius = 3.0,
    this.isVertical = false,
  });

  final String text;
  final SealStyle style;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool isVertical;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cinnabar = isDark
        ? TraditionalPalette.kNaiWuQiangWei
        : TraditionalPalette.kCinnabarRed;
    final Color onSealText = isDark
        ? TraditionalPalette.kInkBlack
        : TraditionalPalette.kXuanPaperWhite;

    final bool isYin = style == SealStyle.yin;
    final Color bgColor =
        isYin ? cinnabar : cinnabar.withValues(alpha: isDark ? 0.14 : 0.08);
    final Color textColor = isYin ? onSealText : cinnabar;
    final Color borderColor = isYin
        ? cinnabar.withValues(alpha: 0.92)
        : cinnabar.withValues(alpha: 0.78);

    Widget content;
    if (isVertical && text.length > 1) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: text
            .split('')
            .map(
              (String ch) => Text(
                ch,
                style: AppTypography.sealStamp(
                  textColor,
                  fontSize: fontSize,
                ).copyWith(letterSpacing: 0, height: 1.15),
              ),
            )
            .toList(),
      );
    } else {
      content = Text(
        text,
        style: AppTypography.sealStamp(
          textColor,
          fontSize: fontSize,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor,
          width: 1.3,
        ),
        boxShadow: isYin
            ? <BoxShadow>[
                BoxShadow(
                  color: cinnabar.withValues(alpha: 0.22),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            (borderRadius - 1.0).clamp(1.0, 10.0),
          ),
          border: Border.all(
            color: isYin
                ? onSealText.withValues(alpha: 0.32)
                : cinnabar.withValues(alpha: 0.28),
            width: 0.6,
          ),
        ),
        child: content,
      ),
    );
  }
}
