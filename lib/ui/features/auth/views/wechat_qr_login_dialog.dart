import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/services/wechat_auth_service.dart';
import '../../../../domain/models/auth_user_model.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/traditional_palette.dart';
import '../../../core/widgets/cinnabar_seal.dart';
import '../../../core/widgets/xuan_paper_card.dart';
import '../../shiju_view_model.dart';
import '../widgets/wechat_qr_code_widget.dart';

/// 微信扫码登录弹窗（支持标准状态流转：待扫码 -> 已扫码待确认 -> 授权成功 / 二维码过期刷新）
class WeChatQrLoginDialog extends StatefulWidget {
  const WeChatQrLoginDialog({
    super.key,
    required this.viewModel,
  });

  final ShiJuViewModel viewModel;

  /// 打开微信扫码登录弹窗
  static Future<WeChatUser?> show(
    BuildContext context, {
    required ShiJuViewModel viewModel,
  }) {
    return showGeneralDialog<WeChatUser?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭微信扫码登录',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return WeChatQrLoginDialog(viewModel: viewModel);
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
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<WeChatQrLoginDialog> createState() => _WeChatQrLoginDialogState();
}

class _WeChatQrLoginDialogState extends State<WeChatQrLoginDialog> {
  late WeChatQrSession _session;
  WeChatPresetAccount _selectedPreset = WeChatPresetAccount.presets.first;
  Timer? _backendPollTimer;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _session = WeChatQrSession(
      uuid: 'wx_qr_init_${now.millisecondsSinceEpoch.toRadixString(16)}',
      qrCodeUrl:
          'https://open.weixin.qq.com/connect/qrconnect?appid=${widget.viewModel.authService.config.appId}&state=init',
      createdAt: now,
      expiresAt: now.add(const Duration(seconds: 120)),
      status: WeChatQrStatus.waitingForScan,
    );
    _createFreshSession();
  }

  @override
  void dispose() {
    _backendPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createFreshSession() async {
    _backendPollTimer?.cancel();
    final WeChatQrSession fresh =
        await widget.viewModel.authService.createQrSession();
    if (!mounted) return;
    setState(() {
      _session = fresh;
    });

    if (widget.viewModel.authService.config.isRealBackendConfigured) {
      _backendPollTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _pollRealBackend(),
      );
    }
  }

  Future<void> _pollRealBackend() async {
    if (!mounted) return;
    final WeChatPollResult result =
        await widget.viewModel.authService.pollQrStatus(_session);
    if (!mounted) return;
    setState(() {
      _session = result.session;
    });
    if (result.session.status == WeChatQrStatus.authorized &&
        result.authenticatedUser != null) {
      _backendPollTimer?.cancel();
      await _completeLogin(result.authenticatedUser!, const <String>[]);
    }
  }

  /// 模拟手机微信扫一扫识别二维码（进入已扫码待确认状态）
  void _handleSimulateScan() {
    setState(() {
      _session = _session.copyWith(
        status: WeChatQrStatus.scannedWaitingConfirm,
        scannedUserPreview: _selectedPreset.nickname,
      );
    });
  }

  /// 模拟取消手机扫码（退回等待扫码状态）
  void _handleCancelScan() {
    setState(() {
      _session = _session.copyWith(
        status: WeChatQrStatus.waitingForScan,
      );
    });
  }

  /// 模拟二维码超时失效
  void _handleSimulateExpire() {
    setState(() {
      _session = _session.copyWith(
        status: WeChatQrStatus.expired,
      );
    });
  }

  /// 确认微信授权并完成登录
  Future<void> _handleConfirmLogin() async {
    setState(() {
      _session = _session.copyWith(
        status: WeChatQrStatus.authorized,
        scannedUserPreview: _selectedPreset.nickname,
      );
    });

    final WeChatUser user = _selectedPreset.toWeChatUser();
    await _completeLogin(user, _selectedPreset.defaultFavorites);
  }

  Future<void> _completeLogin(
    WeChatUser user,
    List<String> cloudFavorites,
  ) async {
    final int mergedCount = await widget.viewModel.loginWithWeChat(
      user,
      cloudFavorites: cloudFavorites,
    );
    if (!mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(user);

    final String syncHint = mergedCount > 0
        ? '已同步云端藏书 $mergedCount 笺'
        : '藏书阁云端同步已开启';
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '朱砂落印 · 欢迎雅士「${user.nickname}」入阁（$syncHint）',
          style: AppTypography.label(TraditionalPalette.kXuanPaperWhite),
        ),
        backgroundColor: kWeChatBambooGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _copyQrUrl(TraditionalPalette palette) async {
    await Clipboard.setData(ClipboardData(text: _session.qrCodeUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已复制微信开放平台 OAuth2 扫码链接',
          style: AppTypography.label(TraditionalPalette.kXuanPaperWhite),
        ),
        backgroundColor: palette.inkText,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TraditionalPalette palette = widget.viewModel.activePalette;
    final WeChatQrStatus status = _session.status;
    final String shortTicket = _session.uuid.length > 6
        ? _session.uuid.substring(_session.uuid.length - 6)
        : _session.uuid;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // 弹窗顶部眉栏
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const CinnabarSeal(
                          text: '微信雅集',
                          style: SealStyle.yin,
                          fontSize: 11,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '微信扫一扫 · 雅士入阁',
                          style: AppTypography.label(
                            TraditionalPalette.kXuanPaperWhite,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      key: const Key('close_wechat_login_dialog'),
                      tooltip: '关闭微信登录',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: TraditionalPalette.kXuanPaperWhite,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 宣纸卡片主体
                XuanPaperCard(
                  palette: palette,
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
                  borderRadius: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // 1. 卡片头部：微信扫码登录标题 + 票据号与刷新按钮
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const WeChatBrandIcon(
                                size: 20,
                                color: kWeChatGreen,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '微信扫码登录',
                                style: AppTypography.sectionHeading(
                                  palette.inkText,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '凭证 #$shortTicket',
                                style: AppTypography.label(
                                  palette.mutedText,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: '刷新微信二维码',
                                child: InkWell(
                                  key: const Key('wechat_qr_refresh_button'),
                                  onTap: _createFreshSession,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                      color: palette.themeAccent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '使用微信扫一扫登录「拾句」，云端漫游珍藏诗笺与阅读足迹',
                        style: AppTypography.attribution(
                          palette.secondaryText,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Divider(color: palette.borderLine, height: 1),
                      const SizedBox(height: 20),

                      // 2. 中央二维码画框
                      Center(
                        child: WeChatQrCodeBox(
                          session: _session,
                          palette: palette,
                          onRefresh: _createFreshSession,
                          size: 204,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. 扫码状态实时指示条
                      _buildStatusBanner(palette, status),

                      const SizedBox(height: 16),

                      // 4. 登录专属权益三联标签
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 14,
                        runSpacing: 6,
                        children: <Widget>[
                          _buildBenefitItem(
                            palette,
                            Icons.cloud_done_outlined,
                            '藏书阁云端同步',
                          ),
                          _buildBenefitItem(
                            palette,
                            Icons.verified_outlined,
                            '专属朱砂闲章',
                          ),
                          _buildBenefitItem(
                            palette,
                            Icons.devices_rounded,
                            '多端足迹漫游',
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),
                      Divider(color: palette.borderLine, height: 1),
                      const SizedBox(height: 14),

                      // 5. 扫码交互体验台（支持预设雅士选择与扫码/确认状态流转）
                      _buildInteractiveSimulatorSection(palette, status),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(
    TraditionalPalette palette,
    WeChatQrStatus status,
  ) {
    final (IconData icon, String text, Color accentColor) = switch (status) {
      WeChatQrStatus.generating => (
          Icons.hourglass_top_rounded,
          '正在向微信开放平台请求安全二维码...',
          palette.themeAccent,
        ),
      WeChatQrStatus.waitingForScan => (
          Icons.qr_code_scanner_rounded,
          '请打开手机微信「扫一扫」扫描上方二维码',
          kWeChatBambooGreen,
        ),
      WeChatQrStatus.scannedWaitingConfirm => (
          Icons.phone_iphone_rounded,
          '已由「${_session.scannedUserPreview ?? _selectedPreset.nickname}」扫码，请在手机端确认',
          kWeChatGreen,
        ),
      WeChatQrStatus.authorized => (
          Icons.check_circle_rounded,
          '微信授权成功，正在同步雅士藏书阁...',
          kWeChatBambooGreen,
        ),
      WeChatQrStatus.expired => (
          Icons.timer_off_outlined,
          '二维码已逾时失效，请点击刷新重新生成',
          palette.cinnabarRed,
        ),
      WeChatQrStatus.error => (
          Icons.error_outline_rounded,
          _session.errorMessage ?? '二维码加载异常，请点击刷新重试',
          palette.cinnabarRed,
        ),
    };

    return Container(
      key: const Key('wechat_qr_status_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.28),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 15, color: accentColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: AppTypography.label(
                accentColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(
    TraditionalPalette palette,
    IconData icon,
    String text,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13.5, color: palette.themeAccent),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.label(
            palette.mutedText,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }

  /// 扫码交互体验台：方便在桌面/Web 端直接体验「扫码 -> 确认」全流程或切换预设雅士
  Widget _buildInteractiveSimulatorSection(
    TraditionalPalette palette,
    WeChatQrStatus status,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: palette.background.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CinnabarSeal(
                    text: '体验台',
                    style: SealStyle.yang,
                    fontSize: 10,
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '切换雅士体验扫码',
                    style: AppTypography.label(
                      palette.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  InkWell(
                    key: const Key('simulate_expire_button'),
                    onTap: _handleSimulateExpire,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        '模拟过期',
                        style: AppTypography.label(
                          palette.mutedText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    key: const Key('copy_qr_url_button'),
                    onTap: () => _copyQrUrl(palette),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        '复制链接',
                        style: AppTypography.label(
                          palette.themeAccent,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 预设雅士身份选择栏
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: WeChatPresetAccount.presets.map(
              (WeChatPresetAccount preset) {
                final bool isSelected = _selectedPreset.id == preset.id;
                return InkWell(
                  key: Key('preset_account_${preset.id}'),
                  onTap: () {
                    setState(() {
                      _selectedPreset = preset;
                      if (_session.status ==
                          WeChatQrStatus.scannedWaitingConfirm) {
                        _session = _session.copyWith(
                          scannedUserPreview: preset.nickname,
                        );
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? palette.themeAccent.withValues(alpha: 0.15)
                          : palette.cardSurface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isSelected
                            ? palette.themeAccent
                            : palette.borderLine,
                        width: isSelected ? 1.2 : 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: 13,
                          color: isSelected
                              ? palette.themeAccent
                              : palette.mutedText,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${preset.nickname} · 印「${preset.sealText}」',
                          style: AppTypography.label(
                            isSelected ? palette.inkText : palette.secondaryText,
                            fontSize: 11.5,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ).toList(),
          ),

          const SizedBox(height: 12),

          // 扫码与确认操作按钮
          if (status == WeChatQrStatus.scannedWaitingConfirm)
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('cancel_scan_button'),
                    onPressed: _handleCancelScan,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.secondaryText,
                      side: BorderSide(color: palette.borderLine),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.undo_rounded, size: 15),
                    label: Text(
                      '返回重扫',
                      style: AppTypography.label(
                        palette.secondaryText,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    key: const Key('confirm_wechat_login_button'),
                    onPressed: _handleConfirmLogin,
                    style: FilledButton.styleFrom(
                      backgroundColor: kWeChatBambooGreen,
                      foregroundColor: TraditionalPalette.kXuanPaperWhite,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: Text(
                      '手机端点击「确认登录」',
                      style: AppTypography.label(
                        TraditionalPalette.kXuanPaperWhite,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('simulate_scan_button'),
                    onPressed: _handleSimulateScan,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.inkText,
                      side: BorderSide(color: palette.borderLine),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                    label: Text(
                      '模拟手机扫码',
                      style: AppTypography.label(
                        palette.inkText,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('quick_wechat_login_button'),
                    onPressed: _handleConfirmLogin,
                    style: FilledButton.styleFrom(
                      backgroundColor: kWeChatBambooGreen,
                      foregroundColor: TraditionalPalette.kXuanPaperWhite,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const WeChatBrandIcon(
                      size: 15,
                      color: TraditionalPalette.kXuanPaperWhite,
                    ),
                    label: Text(
                      '一键扫码登录',
                      style: AppTypography.label(
                        TraditionalPalette.kXuanPaperWhite,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
