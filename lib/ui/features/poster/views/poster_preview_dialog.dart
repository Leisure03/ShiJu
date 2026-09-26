import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../domain/models/poem_model.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/traditional_palette.dart';
import '../../../core/widgets/cinnabar_seal.dart';
import '../../../core/widgets/shichen_greeting_bar.dart';
import '../../../core/widgets/vertical_poetry_renderer.dart';
import '../../../core/widgets/xuan_paper_card.dart';

/// 诗笺海报预览弹窗
class PosterPreviewDialog extends StatefulWidget {
  const PosterPreviewDialog({
    super.key,
    required this.poem,
    required this.palette,
    required this.initialVertical,
  });

  final Poem poem;
  final TraditionalPalette palette;
  final bool initialVertical;

  /// 打开诗笺海报预览弹窗的便捷方法
  static Future<void> show(
    BuildContext context, {
    required Poem poem,
    required TraditionalPalette palette,
    required bool isVertical,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭诗笺海报预览',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return PosterPreviewDialog(
          poem: poem,
          palette: palette,
          initialVertical: isVertical,
        );
      },
      transitionBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        final CurvedAnimation curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<PosterPreviewDialog> createState() => _PosterPreviewDialogState();
}

class _PosterPreviewDialogState extends State<PosterPreviewDialog> {
  late bool _useVertical;
  bool _savedFeedback = false;

  @override
  void initState() {
    super.initState();
    _useVertical = widget.initialVertical;
  }

  String _formatClassicalDate(DateTime dt) {
    const List<String> lunarMonths = <String>[
      '正月',
      '杏月',
      '桃月',
      '槐月',
      '榴月',
      '荷月',
      '巧月',
      '桂月',
      '菊月',
      '阳月',
      '葭月',
      '腊月',
    ];
    final String monthName = lunarMonths[(dt.month - 1) % 12];
    final ShichenInfo shichen = ShichenInfo.fromDateTime(dt);
    return '丙午年 · $monthName廿六 · ${shichen.name}';
  }

  Future<void> _copyPosterText() async {
    final String shareText =
        '「${widget.poem.featuredQuote}」\n—— ${widget.poem.formattedAttribution}\n【拾句 · ShiJu 东方诗笺】';
    await Clipboard.setData(ClipboardData(text: shareText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已复制诗笺佳句与出处，可粘贴分享予知音',
          style: AppTypography.label(TraditionalPalette.kXuanPaperWhite),
        ),
        backgroundColor: TraditionalPalette.kInkBlack,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _triggerSaveFeedback() {
    setState(() {
      _savedFeedback = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已生成「${widget.poem.title}」诗笺画卷预览',
          style: AppTypography.label(TraditionalPalette.kXuanPaperWhite),
        ),
        backgroundColor: TraditionalPalette.kCinnabarRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TraditionalPalette palette = widget.palette;
    final Poem poem = widget.poem;
    final String dateText = _formatClassicalDate(DateTime.now());

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // 顶部预览控制栏
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const CinnabarSeal(
                          text: '诗笺预览',
                          style: SealStyle.yin,
                          fontSize: 11,
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _useVertical = !_useVertical;
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: TraditionalPalette.kXuanPaperWhite,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.14),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          icon: Icon(
                            _useVertical
                                ? Icons.format_align_center_rounded
                                : Icons.vertical_distribute_rounded,
                            size: 15,
                          ),
                          label: Text(
                            _useVertical ? '切换横排海报' : '切换竖排海报',
                            style: AppTypography.label(
                              TraditionalPalette.kXuanPaperWhite,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: '关闭海报预览',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: TraditionalPalette.kXuanPaperWhite,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 竖版诗笺海报主体
                XuanPaperCard(
                  palette: palette,
                  padding: EdgeInsets.zero,
                  borderRadius: 10,
                  child: CustomPaint(
                    painter: _TraditionalWaveWatermarkPainter(
                      color: palette.themeAccent.withValues(alpha: 0.07),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // 1. 海报眉栏：传统色名 + 日期印章
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: <Widget>[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: palette.themeAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '中国传统色 · ${palette.name}',
                                    style: AppTypography.label(
                                      palette.mutedText,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                              CinnabarSeal(
                                text: dateText,
                                style: SealStyle.yang,
                                fontSize: 10.5,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(color: palette.borderLine, height: 1),
                          const SizedBox(height: 28),

                          // 2. 海报核心：精选名句（支持古籍竖排与现代横排）
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 220),
                            child: Center(
                              child: _useVertical
                                  ? VerticalPoetryRenderer(
                                      lines: <String>[poem.featuredQuote],
                                      palette: palette,
                                      fontSize: 24,
                                      columnSpacing: 20,
                                      attributionText:
                                          '〔${poem.dynasty}〕${poem.authorName}《${poem.title}》',
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 16,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Text(
                                            poem.featuredQuote,
                                            textAlign: TextAlign.center,
                                            style:
                                                AppTypography.quoteHorizontal(
                                              palette.inkText,
                                              fontSize: 23,
                                            ),
                                          ),
                                          const SizedBox(height: 22),
                                          Text(
                                            poem.formattedAttribution,
                                            textAlign: TextAlign.center,
                                            style: AppTypography.attribution(
                                              palette.secondaryText,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 3. 意境标签与朝代印记
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              CinnabarSeal(
                                text: poem.dynasty,
                                style: SealStyle.yang,
                                fontSize: 10.5,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                              ),
                              ...poem.tags.map(
                                (String tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.themeAccent
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: AppTypography.label(
                                      palette.themeAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          Divider(color: palette.borderLine, height: 1),
                          const SizedBox(height: 16),

                          // 4. 海报底栏：拾句品牌印章 + 二维码占位
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        const CinnabarSeal(
                                          text: '拾句珍藏',
                                          style: SealStyle.yin,
                                          fontSize: 10.5,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '拾句 · ShiJu',
                                          style: AppTypography.label(
                                            palette.inkText,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '一叶诗笺，半日清欢 · 扫码共赏全诗译注',
                                      style: AppTypography.attribution(
                                        palette.mutedText,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // 二维码艺术占位框
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Container(
                                    width: 54,
                                    height: 54,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: palette.background,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: palette.borderLine,
                                        width: 1,
                                      ),
                                    ),
                                    child: CustomPaint(
                                      painter: _OrientalQrPlaceholderPainter(
                                        inkColor: palette.inkText,
                                        cinnabarColor: palette.cinnabarRed,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '扫码拾句',
                                    style: AppTypography.label(
                                      palette.mutedText,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 底部操作按钮栏
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyPosterText,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TraditionalPalette.kXuanPaperWhite,
                          side: BorderSide(
                            color: TraditionalPalette.kXuanPaperWhite
                                .withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: Text(
                          '复制诗笺文案',
                          style: AppTypography.label(
                            TraditionalPalette.kXuanPaperWhite,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _triggerSaveFeedback,
                        style: FilledButton.styleFrom(
                          backgroundColor: TraditionalPalette.kCinnabarRed,
                          foregroundColor: TraditionalPalette.kXuanPaperWhite,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: Icon(
                          _savedFeedback
                              ? Icons.check_circle_outline_rounded
                              : Icons.download_rounded,
                          size: 16,
                        ),
                        label: Text(
                          _savedFeedback ? '已珍藏诗笺画卷' : '保存诗笺海报',
                          style: AppTypography.label(
                            TraditionalPalette.kXuanPaperWhite,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 传统远山/水波纹暗纹绘制器
class _TraditionalWaveWatermarkPainter extends CustomPainter {
  const _TraditionalWaveWatermarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 底部远山曲线暗纹
    final Path mountainPath = Path()
      ..moveTo(0, size.height - 70)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height - 115,
        size.width * 0.58,
        size.height - 82,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height - 55,
        size.width,
        size.height - 92,
      );
    canvas.drawPath(mountainPath, paint);

    final Path secondWave = Path()
      ..moveTo(0, size.height - 52)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height - 80,
        size.width,
        size.height - 48,
      );
    canvas.drawPath(secondWave, paint);
  }

  @override
  bool shouldRepaint(covariant _TraditionalWaveWatermarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 新中式微缩二维码占位绘制器
class _OrientalQrPlaceholderPainter extends CustomPainter {
  const _OrientalQrPlaceholderPainter({
    required this.inkColor,
    required this.cinnabarColor,
  });

  final Color inkColor;
  final Color cinnabarColor;

  static const List<List<int>> _matrix = <List<int>>[
    <int>[1, 1, 1, 0, 1, 0, 1, 1, 1],
    <int>[1, 0, 1, 0, 0, 1, 1, 0, 1],
    <int>[1, 1, 1, 0, 1, 0, 1, 1, 1],
    <int>[0, 0, 0, 1, 2, 1, 0, 0, 0],
    <int>[1, 0, 1, 2, 2, 2, 1, 0, 1],
    <int>[0, 1, 0, 1, 2, 1, 0, 1, 0],
    <int>[1, 1, 1, 0, 1, 0, 1, 0, 1],
    <int>[1, 0, 1, 1, 0, 1, 0, 1, 0],
    <int>[1, 1, 1, 0, 1, 1, 1, 0, 1],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final int rows = _matrix.length;
    final double cellSize = size.width / rows;

    final Paint inkPaint = Paint()
      ..color = inkColor.withValues(alpha: 0.82)
      ..style = PaintingStyle.fill;
    final Paint sealPaint = Paint()
      ..color = cinnabarColor
      ..style = PaintingStyle.fill;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < rows; c++) {
        final int val = _matrix[r][c];
        if (val == 0) continue;
        final Rect rect = Rect.fromLTWH(
          c * cellSize + 0.5,
          r * cellSize + 0.5,
          cellSize - 1.0,
          cellSize - 1.0,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1.0)),
          val == 2 ? sealPaint : inkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrientalQrPlaceholderPainter oldDelegate) =>
      oldDelegate.inkColor != inkColor ||
      oldDelegate.cinnabarColor != cinnabarColor;
}
