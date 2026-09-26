import 'package:flutter/material.dart';
import '../../../../domain/models/auth_user_model.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/traditional_palette.dart';
import '../../../core/widgets/cinnabar_seal.dart';
import '../../../core/widgets/xuan_paper_card.dart';
import '../../shiju_view_model.dart';
import '../widgets/wechat_qr_code_widget.dart';
import 'wechat_qr_login_dialog.dart';

/// 雅士名刺与微信账号管理弹窗
class UserProfileDialog extends StatefulWidget {
  const UserProfileDialog({
    super.key,
    required this.viewModel,
  });

  final ShiJuViewModel viewModel;

  /// 打开雅士名刺弹窗
  static Future<void> show(
    BuildContext context, {
    required ShiJuViewModel viewModel,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭雅士名刺',
      barrierColor: Colors.black.withValues(alpha: 0.60),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return UserProfileDialog(viewModel: viewModel);
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
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  bool _isEditing = false;
  late final TextEditingController _nicknameController;
  late final TextEditingController _titleController;
  late final TextEditingController _sealController;

  @override
  void initState() {
    super.initState();
    final WeChatUser? user = widget.viewModel.currentUser;
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _titleController = TextEditingController(text: user?.poeticTitle ?? '');
    _sealController = TextEditingController(text: user?.sealText ?? '');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _titleController.dispose();
    _sealController.dispose();
    super.dispose();
  }

  String _formatSyncTime(DateTime? dt) {
    if (dt == null) return '尚未同步';
    final String hh = dt.hour.toString().padLeft(2, '0');
    final String mm = dt.minute.toString().padLeft(2, '0');
    final String ss = dt.second.toString().padLeft(2, '0');
    return '今日 $hh:$mm:$ss';
  }

  Future<void> _handleSaveProfile(TraditionalPalette palette) async {
    await widget.viewModel.updateUserProfile(
      nickname: _nicknameController.text,
      poeticTitle: _titleController.text,
      sealText: _sealController.text,
    );
    if (!mounted) return;
    setState(() {
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已修撰雅士名刺与专属闲章',
          style: AppTypography.label(TraditionalPalette.kXuanPaperWhite),
        ),
        backgroundColor: palette.themeAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleLogout(TraditionalPalette palette) async {
    final String oldName = widget.viewModel.currentUser?.nickname ?? '雅士';
    await widget.viewModel.logout();
    if (!mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '「$oldName」已退出微信登录，本地藏书阁诗笺仍妥善保留',
          style: AppTypography.label(TraditionalPalette.kXuanPaperWhite),
        ),
        backgroundColor: palette.inkText,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSwitchAccount() async {
    final NavigatorState nav = Navigator.of(context);
    nav.pop();
    await WeChatQrLoginDialog.show(
      nav.context,
      viewModel: widget.viewModel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (BuildContext context, _) {
        final TraditionalPalette palette = widget.viewModel.activePalette;
        final WeChatUser? user = widget.viewModel.currentUser;
        if (user == null) {
          return const SizedBox.shrink();
        }

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // 弹窗顶部栏
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const CinnabarSeal(
                              text: '雅士名刺',
                              style: SealStyle.yin,
                              fontSize: 11,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '微信授权档案 · 云端藏书同步',
                              style: AppTypography.label(
                                TraditionalPalette.kXuanPaperWhite,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: '关闭雅士名刺',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: TraditionalPalette.kXuanPaperWhite,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 名刺主体卡片
                    XuanPaperCard(
                      palette: palette,
                      padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
                      borderRadius: 10,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // 1. 头像 + 雅号 + 专属闲章
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              OrientalScholarAvatar(
                                user: user,
                                size: 54,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Flexible(
                                          child: Text(
                                            user.nickname,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.sectionHeading(
                                              palette.inkText,
                                              fontSize: 19,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: kWeChatGreen
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                              color: kWeChatGreen
                                                  .withValues(alpha: 0.35),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              const WeChatBrandIcon(
                                                size: 11,
                                                color: kWeChatBambooGreen,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '微信已绑定',
                                                style: AppTypography.label(
                                                  kWeChatBambooGreen,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '斋号：${user.poeticTitle} · 凭证 ${user.openId.substring(0, user.openId.length.clamp(0, 14))}...',
                                      style: AppTypography.attribution(
                                        palette.secondaryText,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              CinnabarSeal(
                                text: user.sealText,
                                style: SealStyle.yin,
                                fontSize: 12.5,
                                isVertical: user.sealText.length <= 2,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 5,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          Divider(color: palette.borderLine, height: 1),
                          const SizedBox(height: 16),

                          // 2. 数据统计与云端同步状态
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: palette.background.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: palette.borderLine),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 8,
                              children: <Widget>[
                                _buildStatColumn(
                                  palette: palette,
                                  value:
                                      '${widget.viewModel.favoriteIds.length} 笺',
                                  label: '雅藏诗笺',
                                ),
                                _buildStatColumn(
                                  palette: palette,
                                  value:
                                      '${widget.viewModel.historyIds.length} 篇',
                                  label: '漫游足迹',
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    InkWell(
                                      key: const Key('profile_sync_cloud_button'),
                                      onTap: widget.viewModel.syncCloudCollection,
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Icon(
                                              widget.viewModel.isSyncingCloud
                                                  ? Icons.sync_rounded
                                                  : Icons.cloud_done_rounded,
                                              size: 14,
                                              color: kWeChatBambooGreen,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              widget.viewModel.isSyncingCloud
                                                  ? '同步中...'
                                                  : '立即云端同步',
                                              style: AppTypography.label(
                                                kWeChatBambooGreen,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '上次同步：${_formatSyncTime(user.lastSyncTime)}',
                                      style: AppTypography.label(
                                        palette.mutedText,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 3. 修撰名刺与专属闲章折叠区
                          if (_isEditing)
                            _buildEditProfileForm(palette)
                          else
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                key: const Key('toggle_edit_profile_button'),
                                onPressed: () {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: palette.themeAccent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.edit_note_rounded,
                                  size: 17,
                                ),
                                label: Text(
                                  '修撰雅号与专属朱砂闲章（海报落款印记）',
                                  style: AppTypography.label(
                                    palette.themeAccent,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 14),
                          Divider(color: palette.borderLine, height: 1),
                          const SizedBox(height: 16),

                          // 4. 底部操作按钮：切换账号 & 退出登录
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: const Key('switch_wechat_account_button'),
                                  onPressed: _handleSwitchAccount,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: palette.inkText,
                                    side: BorderSide(color: palette.borderLine),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.qr_code_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    '切换微信扫码',
                                    style: AppTypography.label(
                                      palette.inkText,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: const Key('logout_wechat_button'),
                                  onPressed: () => _handleLogout(palette),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: palette.cinnabarRed,
                                    side: BorderSide(
                                      color: palette.cinnabarRed
                                          .withValues(alpha: 0.45),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 15,
                                  ),
                                  label: Text(
                                    '退出微信登录',
                                    style: AppTypography.label(
                                      palette.cinnabarRed,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn({
    required TraditionalPalette palette,
    required String value,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: AppTypography.sectionHeading(
            palette.inkText,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.label(
            palette.mutedText,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildEditProfileForm(TraditionalPalette palette) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '修撰名刺与闲章',
            style: AppTypography.label(
              palette.inkText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: _buildCompactTextField(
                  key: const Key('edit_nickname_input'),
                  controller: _nicknameController,
                  label: '雅号（昵称）',
                  palette: palette,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildCompactTextField(
                  key: const Key('edit_seal_input'),
                  controller: _sealController,
                  label: '朱砂闲章（2-4字）',
                  palette: palette,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildCompactTextField(
            key: const Key('edit_title_input'),
            controller: _titleController,
            label: '斋号 / 雅士头衔',
            palette: palette,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                  });
                },
                child: Text(
                  '取消',
                  style: AppTypography.label(
                    palette.mutedText,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('save_profile_button'),
                onPressed: () => _handleSaveProfile(palette),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.themeAccent,
                  foregroundColor: TraditionalPalette.kXuanPaperWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  '保存名刺',
                  style: AppTypography.label(
                    TraditionalPalette.kXuanPaperWhite,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
                          ),
        ],
      ),
    );
  }

  Widget _buildCompactTextField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required TraditionalPalette palette,
  }) {
    return TextField(
      key: key,
      controller: controller,
      style: AppTypography.label(palette.inkText, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.label(palette.mutedText, fontSize: 11.5),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 9,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: palette.borderLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: palette.themeAccent, width: 1.2),
        ),
      ),
    );
  }
}
