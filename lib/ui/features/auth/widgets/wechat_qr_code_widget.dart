import 'package:flutter/material.dart';
import '../../../../domain/models/auth_user_model.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/traditional_palette.dart';
import '../../../core/utils/qr_code_matrix.dart';
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
    final String? networkAvatar = user.avatarUrl?.trim();
    final bool hasNetworkAvatar =
        networkAvatar != null && networkAvatar.isNotEmpty;

    final Widget monogramChild = Center(
      child: Text(
        user.avatarMonogram,
        style: AppTypography.sealStamp(
          TraditionalPalette.kXuanPaperWhite,
          fontSize: size * 0.44,
        ).copyWith(letterSpacing: 0),
      ),
    );

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
            clipBehavior: Clip.antiAlias,
            child: hasNetworkAvatar
                ? Image.network(
                    networkAvatar,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return monogramChild;
                    },
                  )
                : monogramChild,
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
          // 底层：符合 ISO/IEC 18004 标准的真实可扫描微信二维码矩阵
          Positioned.fill(
            child: CustomPaint(
              painter: _DeterministicWeChatQrPainter(
                dataSeed: widget.session.qrCodeUrl,
                inkColor: TraditionalPalette.kInkBlack,
                accentColor: kWeChatBambooGreen,
              ),
            ),
          ),

          // 中央：微信品牌圆角白底徽标（控制在 15% Level M 纠错容差之内，确保真机秒扫识别）
          Container(
            width: 30,
            height: 30,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: TraditionalPalette.kXuanPaperWhite,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: kWeChatGreen.withValues(alpha: 0.35),
                width: 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const WeChatBrandIcon(
              size: 18,
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

/// 符合 ISO/IEC 18004 标准的真实微信二维码矩阵绘制器（支持手机微信「扫一扫」直接识别）
class _DeterministicWeChatQrPainter extends CustomPainter {
  const _DeterministicWeChatQrPainter({
    required this.dataSeed,
    required this.inkColor,
    required this.accentColor,
  });

  final String dataSeed;
  final Color inkColor;
  final Color accentColor;

  bool _isFinderInnerCore(int r, int c, int gridSize) {
    final bool tl = r >= 2 && r <= 4 && c >= 2 && c <= 4;
    final bool tr = r >= 2 && r <= 4 && c >= gridSize - 5 && c <= gridSize - 3;
    final bool bl = r >= gridSize - 5 && r <= gridSize - 3 && c >= 2 && c <= 4;
    return tl || tr || bl;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final StandardQrMatrix qr = StandardQrMatrix.encode(
      dataSeed.isEmpty ? 'https://leisure03.github.io/ShiJu/' : dataSeed,
    );
    final int gridSize = qr.size;
    final double cellSize = size.width / gridSize;

    final Paint modulePaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    final Paint accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (!qr.modules[r][c]) {
          continue;
        }
        final bool isFinderCore = _isFinderInnerCore(r, c, gridSize);
        canvas.drawRect(
          Rect.fromLTWH(
            c * cellSize,
            r * cellSize,
            cellSize + 0.15,
            cellSize + 0.15,
          ),
          isFinderCore ? accentPaint : modulePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DeterministicWeChatQrPainter oldDelegate) =>
      oldDelegate.dataSeed != dataSeed ||
      oldDelegate.inkColor != inkColor ||
      oldDelegate.accentColor != accentColor;
}
