import 'package:flutter/material.dart';
import '../theme/traditional_palette.dart';

/// 宣纸信笺与古籍书页质感容器组件
class XuanPaperCard extends StatelessWidget {
  const XuanPaperCard({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(28),
    this.borderRadius = 8.0,
    this.showCornerOrnaments = true,
    this.showInnerFrame = true,
    this.onTap,
  });

  final TraditionalPalette palette;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showCornerOrnaments;
  final bool showInnerFrame;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: palette.borderLine,
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (palette.isDark ? Colors.black : palette.themeAccent)
                .withValues(alpha: palette.isDark ? 0.35 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: (palette.isDark ? Colors.black : palette.inkText)
                .withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: palette.themeAccent.withValues(alpha: 0.06),
          highlightColor: palette.themeAccent.withValues(alpha: 0.03),
          child: CustomPaint(
            painter: _ClassicalBookFramePainter(
              lineColor: palette.borderLine,
              accentColor: palette.themeAccent.withValues(alpha: 0.28),
              showCornerOrnaments: showCornerOrnaments,
              showInnerFrame: showInnerFrame,
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassicalBookFramePainter extends CustomPainter {
  const _ClassicalBookFramePainter({
    required this.lineColor,
    required this.accentColor,
    required this.showCornerOrnaments,
    required this.showInnerFrame,
  });

  final Color lineColor;
  final Color accentColor;
  final bool showCornerOrnaments;
  final bool showInnerFrame;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 48 || size.height < 48) return;

    const double inset = 10.0;
    final Rect innerRect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );

    if (showInnerFrame) {
      final Paint framePaint = Paint()
        ..color = lineColor.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75;
      canvas.drawRRect(
        RRect.fromRectAndRadius(innerRect, const Radius.circular(4)),
        framePaint,
      );
    }

    if (showCornerOrnaments) {
      final Paint cornerPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.square;

      const double len = 12.0;

      // 左上角中式折角纹
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top + len),
        Offset(innerRect.left, innerRect.top),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.left + len, innerRect.top),
        cornerPaint,
      );

      // 右上角中式折角纹
      canvas.drawLine(
        Offset(innerRect.right - len, innerRect.top),
        Offset(innerRect.right, innerRect.top),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(innerRect.right, innerRect.top),
        Offset(innerRect.right, innerRect.top + len),
        cornerPaint,
      );

      // 左下角中式折角纹
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom - len),
        Offset(innerRect.left, innerRect.bottom),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.left + len, innerRect.bottom),
        cornerPaint,
      );

      // 右下角中式折角纹
      canvas.drawLine(
        Offset(innerRect.right - len, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(innerRect.right, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom - len),
        cornerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClassicalBookFramePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.showCornerOrnaments != showCornerOrnaments ||
        oldDelegate.showInnerFrame != showInnerFrame;
  }
}
