import 'package:flutter/material.dart';
import '../../../../domain/models/auth_user_model.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/traditional_palette.dart';
import '../../../core/widgets/cinnabar_seal.dart';

/// 微信品牌竹青绿常量（融合微信标准绿 #07C160 与东方竹青色韵味）
const Color kWeChatGreen = Color(0xFF07C160);
const Color kWeChatBambooGreen = Color(0xFF1E8E5A);

/// 微信双气泡矢量图标组件（纯 CustomPaint 绘制，任意分辨率清晰锐利）
class WeChatBrandIcon extends StatelessWidget {
  const WeChatBrandIcon({
    super.key,
    this.size = 18,
    this.color = kWeChatGreen,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WeChatBubbleLogoPainter(color: color),
      ),
    );
  }
}

class _WeChatBubbleLogoPainter extends CustomPainter {
  const _WeChatBubbleLogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 后方左大椭圆气泡
    final Rect bigBubble = Rect.fromLTWH(
      w * 0.04,
      h * 0.10,
      w * 0.68,
      h * 0.56,
    );
    canvas.drawOval(bigBubble, fillPaint);

    // 左气泡左下角小尖角
    final Path leftTail = Path()
      ..moveTo(w * 0.16, h * 0.58)
      ..lineTo(w * 0.08, h * 0.74)
      ..lineTo(w * 0.28, h * 0.62)
      ..close();
    canvas.drawPath(leftTail, fillPaint);

    // 前方右下小椭圆气泡（先用微透背景描边区分层次，再填充）
    final Rect smallBubble = Rect.fromLTWH(
      w * 0.36,
      h * 0.34,
      w * 0.60,
      h * 0.50,
    );
    canvas.drawOval(smallBubble, fillPaint);

    // 右气泡右下角小尖角
    final Path rightTail = Path()
      ..moveTo(w * 0.84, h * 0.76)
      ..lineTo(w * 0.92, h * 0.90)
      ..lineTo(w * 0.72, h * 0.80)
      ..close();
    canvas.drawPath(rightTail, fillPaint);

    // 气泡上的灵动双目（留白圆点）
    final Paint eyePaint = Paint()
      ..color = TraditionalPalette.kXuanPaperWhite
      ..style = PaintingStyle.fill;

    final double bigEyeRadius = w * 0.045;
    canvas.drawCircle(
      Offset(w * 0.26, h * 0.34),
      bigEyeRadius,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(w * 0.48, h * 0.34),
      bigEyeRadius,
      eyePaint,
    );

    final double smallEyeRadius = w * 0.038;
    canvas.drawCircle(
      Offset(w * 0.55, h * 0.56),
      smallEyeRadius,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(w * 0.75, h * 0.56),
      smallEyeRadius,
      eyePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WeChatBubbleLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 东方水墨传统色雅士头像组件（右下角带微信认证绿点）
class OrientalScholarAvatar extends StatelessWidget {
  const OrientalScholarAvatar({
    super.key,
    required this.user,
    this.size = 36,
    this.showWeChatBadge = true,
  });

  final WeChatUser user;
  final double size;
  final bool showWeChatBadge;

  @override
  Widget build(BuildContext context) {
    final TraditionalPalette userPalette =
        TraditionalPalette.resolve(user.avatarTheme);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  userPalette.themeAccent,
                  userPalette.inkText,
                ],
              ),
              border: Border.all(
                color: TraditionalPalette.kXuanPaperWhite.withValues(alpha: 0.85),
                width: 1.4,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: userPalette.themeAccent.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              user.avatarMonogram,
              style: AppTypography.sealStamp(
                TraditionalPalette.kXuanPaperWhite,
                fontSize: size * 0.44,
              ).copyWith(letterSpacing: 0),
            ),
          ),
          if (showWeChatBadge)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: (size * 0.34).clamp(10.0, 16.0),
                height: (size * 0.34).clamp(10.0, 16.0),
                decoration: BoxDecoration(
                  color: kWeChatGreen,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: TraditionalPalette.kXuanPaperWhite,
                    width: 1.3,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.check_rounded,
                  size: (size * 0.20).clamp(6.5, 10.0),
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 微信扫码二维码画框组件（含 25x25 动态矩阵绘制、中心微信徽标、扫描光束动效与多状态遮罩）
class WeChatQrCodeBox extends StatefulWidget {
  const WeChatQrCodeBox({
    super.key,
    required this.session,
    required this.palette,
    required this.onRefresh,
    this.size = 208,
  });

  final WeChatQrSession session;
  final TraditionalPalette palette;
  final VoidCallback onRefresh;
  final double size;

  @override
  State<WeChatQrCodeBox> createState() => _WeChatQrCodeBoxState();
}

class _WeChatQrCodeBoxState extends State<WeChatQrCodeBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanSweepController;
  late final Animation<double> _scanSweepAnimation;

  @override
  void initState() {
    super.initState();
    _scanSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scanSweepAnimation = CurvedAnimation(
      parent: _scanSweepController,
      curve: Curves.easeInOutCubic,
    );
    _scanSweepController.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant WeChatQrCodeBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.uuid != widget.session.uuid ||
        oldWidget.session.status != widget.session.status) {
      _scanSweepController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _scanSweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WeChatQrStatus status = widget.session.status;
    final TraditionalPalette palette = widget.palette;

    return Container(
      key: const Key('wechat_qr_code_box'),
      width: widget.size,
      height: widget.size,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TraditionalPalette.kXuanPaperWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: status == WeChatQrStatus.scannedWaitingConfirm
              ? kWeChatGreen.withValues(alpha: 0.65)
              : palette.borderLine,
          width: 1.4,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.32 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // 底层：25x25 确定性微信二维码矩阵
          Positioned.fill(
            child: CustomPaint(
              painter: _DeterministicWeChatQrPainter(
                dataSeed: widget.session.qrCodeUrl,
                inkColor: TraditionalPalette.kInkBlack,
                accentColor: kWeChatBambooGreen,
              ),
            ),
          ),

          // 中央：微信品牌圆角白底徽标
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: TraditionalPalette.kXuanPaperWhite,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: kWeChatGreen.withValues(alpha: 0.32),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const WeChatBrandIcon(
              size: 26,
              color: kWeChatGreen,
            ),
          ),

          // 扫描激光掠过动效（等待扫码时浮现）
          if (status == WeChatQrStatus.waitingForScan)
            AnimatedBuilder(
              animation: _scanSweepAnimation,
              builder: (BuildContext context, _) {
                final double progress = _scanSweepAnimation.value;
                // 扫描完成后停留在顶部微光装饰线，兼顾动效仪式感与测试收敛
                final double yOffset = (widget.size - 36) *
                    (progress < 1.0 ? progress : 0.12);
                final double opacity =
                    progress < 1.0 ? 0.78 : 0.22;
                return Positioned(
                  top: yOffset,
                  left: 4,
                  right: 4,
                  child: IgnorePointer(
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            kWeChatGreen.withValues(alpha: 0.0),
                            kWeChatGreen.withValues(alpha: opacity),
                            kWeChatGreen.withValues(alpha: 0.0),
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: kWeChatGreen.withValues(alpha: opacity * 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          // 状态遮罩：已扫码待手机确认
          if (status == WeChatQrStatus.scannedWaitingConfirm)
            Positioned.fill(
              child: Container(
                key: const Key('qr_mask_scanned'),
                decoration: BoxDecoration(
                  color: TraditionalPalette.kXuanPaperWhite
                      .withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kWeChatGreen.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phonelink_ring_rounded,
                        color: kWeChatGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '扫码成功',
                      style: AppTypography.sectionHeading(
                        TraditionalPalette.kInkBlack,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (widget.session.scannedUserPreview != null)
                      Text(
                        '「${widget.session.scannedUserPreview}」',
                        style: AppTypography.label(
                          kWeChatBambooGreen,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '请在微信中点击确认登录',
                      textAlign: TextAlign.center,
                      style: AppTypography.label(
                        const Color(0xFF524F4A),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 状态遮罩：已确认授权
          if (status == WeChatQrStatus.authorized)
            Positioned.fill(
              child: Container(
                key: const Key('qr_mask_authorized'),
                decoration: BoxDecoration(
                  color: TraditionalPalette.kXuanPaperWhite
                      .withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const CinnabarSeal(
                      text: '雅集准入',
                      style: SealStyle.yin,
                      fontSize: 13,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '微信授权通过 · 正在展卷',
                      style: AppTypography.label(
                        TraditionalPalette.kInkBlack,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 状态遮罩：二维码已过期
          if (status == WeChatQrStatus.expired || status == WeChatQrStatus.error)
            Positioned.fill(
              child: Container(
                key: const Key('qr_mask_expired'),
                decoration: BoxDecoration(
                  color: TraditionalPalette.kXuanPaperWhite
                      .withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 32,
                      color: palette.cinnabarRed,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status == WeChatQrStatus.error ? '获取二维码异常' : '二维码已失效',
                      style: AppTypography.label(
                        TraditionalPalette.kInkBlack,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      key: const Key('qr_refresh_overlay_button'),
                      onPressed: widget.onRefresh,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.cinnabarRed,
                        foregroundColor: TraditionalPalette.kXuanPaperWhite,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: Text(
                        '点击刷新',
                        style: AppTypography.label(
                          TraditionalPalette.kXuanPaperWhite,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 25x25 高精度确定性二维码矩阵绘制器（根据 URL 哈希实时变化编码模块）
class _DeterministicWeChatQrPainter extends CustomPainter {
  const _DeterministicWeChatQrPainter({
    required this.dataSeed,
    required this.inkColor,
    required this.accentColor,
  });

  final String dataSeed;
  final Color inkColor;
  final Color accentColor;

  static const int _gridSize = 25;

  bool _isFinderPattern(int r, int c) {
    final bool topLeft = r < 8 && c < 8;
    final bool topRight = r < 8 && c >= _gridSize - 8;
    final bool bottomLeft = r >= _gridSize - 8 && c < 8;
    return topLeft || topRight || bottomLeft;
  }

  bool _isCenterLogoArea(int r, int c) {
    return r >= 9 && r <= 15 && c >= 9 && c <= 15;
  }

  bool _isAlignmentPattern(int r, int c) {
    return r >= 16 && r <= 20 && c >= 16 && c <= 20;
  }

  void _drawFinder(Canvas canvas, double cellSize, int startR, int startC) {
    final Paint outerPaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.fill;
    final Paint whitePaint = Paint()
      ..color = TraditionalPalette.kXuanPaperWhite
      ..style = PaintingStyle.fill;
    final Paint corePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final Rect outer = Rect.fromLTWH(
      startC * cellSize,
      startR * cellSize,
      7 * cellSize,
      7 * cellSize,
    );
    final Rect middle = Rect.fromLTWH(
      (startC + 1) * cellSize,
      (startR + 1) * cellSize,
      5 * cellSize,
      5 * cellSize,
    );
    final Rect inner = Rect.fromLTWH(
      (startC + 2) * cellSize,
      (startR + 2) * cellSize,
      3 * cellSize,
      3 * cellSize,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, Radius.circular(cellSize * 0.8)),
      outerPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(middle, Radius.circular(cellSize * 0.5)),
      whitePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(cellSize * 0.4)),
      corePaint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double cellSize = size.width / _gridSize;

    final Paint modulePaint = Paint()
      ..color = inkColor.withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;

    // 1. 绘制三个 7x7 回字定位标
    _drawFinder(canvas, cellSize, 0, 0);
    _drawFinder(canvas, cellSize, 0, _gridSize - 7);
    _drawFinder(canvas, cellSize, _gridSize - 7, 0);

    // 2. 绘制右下 5x5 校正图形
    for (int r = 16; r <= 20; r++) {
      for (int c = 16; c <= 20; c++) {
        final bool isBorder = r == 16 || r == 20 || c == 16 || c == 20;
        final bool isCenter = r == 18 && c == 18;
        if (isBorder || isCenter) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                c * cellSize + 0.4,
                r * cellSize + 0.4,
                cellSize - 0.8,
                cellSize - 0.8,
              ),
              const Radius.circular(1.2),
            ),
            modulePaint,
          );
        }
      }
    }

    // 3. 根据 dataSeed 计算哈希并填充数据模块
    final List<int> seedUnits = dataSeed.codeUnits;
    int baseHash = 0x811C9DC5;
    for (final int unit in seedUnits) {
      baseHash ^= unit;
      baseHash = (baseHash * 0x01000193) & 0x7FFFFFFF;
    }

    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_isFinderPattern(r, c) ||
            _isCenterLogoArea(r, c) ||
            _isAlignmentPattern(r, c)) {
          continue;
        }

        // 时序线（第 6 行与第 6 列交替点亮）
        if (r == 6 || c == 6) {
          if ((r + c).isEven) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  c * cellSize + 0.5,
                  r * cellSize + 0.5,
                  cellSize - 1.0,
                  cellSize - 1.0,
                ),
                const Radius.circular(1.2),
              ),
              modulePaint,
            );
          }
          continue;
        }

        final int cellSeed =
            baseHash ^ (r * 131 + c * 977) ^ seedUnits[(r * _gridSize + c) % seedUnits.length];
        final bool isDarkModule = ((cellSeed >> ((r + c) % 7)) & 3) != 0 &&
            ((cellSeed + r * 17 + c * 31) % 11 < 6);

        if (isDarkModule) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                c * cellSize + 0.45,
                r * cellSize + 0.45,
                cellSize - 0.9,
                cellSize - 0.9,
              ),
              const Radius.circular(1.4),
            ),
            modulePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DeterministicWeChatQrPainter oldDelegate) =>
      oldDelegate.dataSeed != dataSeed ||
      oldDelegate.inkColor != inkColor ||
      oldDelegate.accentColor != accentColor;
}
