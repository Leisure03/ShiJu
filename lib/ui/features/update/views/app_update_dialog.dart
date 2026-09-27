import 'package:flutter/material.dart';
import '../../../../domain/models/app_update_model.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/traditional_palette.dart';
import '../../../core/widgets/cinnabar_seal.dart';
import '../../../core/widgets/xuan_paper_card.dart';
import '../../pipeline/utils/artifact_downloader.dart';
import '../../shiju_view_model.dart';

/// 「拾句（ShiJu）」Jenkins 新版本构建自动弹窗提示与一键热更新对话框
class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.viewModel,
  });

  final ShiJuViewModel viewModel;

  /// 弹出新版本更新提示窗
  static Future<void> show(
    BuildContext context, {
    required ShiJuViewModel viewModel,
  }) {
    final AppReleaseManifest? manifest = viewModel.latestManifest;
    final bool barrierDismissible = !(manifest?.forceUpdate ?? false);

    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext dialogContext) {
        return AppUpdateDialog(viewModel: viewModel);
      },
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  late final String _previousDisplayVersion;

  @override
  void initState() {
    super.initState();
    _previousDisplayVersion = widget.viewModel.currentDisplayVersion;
  }

  Future<void> _handleStartUpdate() async {
    final AppReleaseManifest? target = widget.viewModel.latestManifest;
    if (target == null) return;

    await widget.viewModel.performAppUpdate();
    if (!mounted) return;

    final TraditionalPalette palette = widget.viewModel.activePalette;
    final ScaffoldMessengerState? messenger =
        ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();

    messenger?.clearSnackBars();
    messenger?.showSnackBar(
      SnackBar(
        key: const Key('app_update_completed_snackbar'),
        content: Text(
          '已通过 Jenkins 热更新升级至最新版本：${target.displayVersion}',
          style: AppTypography.label(palette.onCinnabar, fontSize: 13),
        ),
        backgroundColor: palette.cinnabarRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleLater() async {
    await widget.viewModel.dismissUpdateDialog(ignoreThisBuild: true);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _handleDownloadPackage(AppReleaseManifest manifest) {
    triggerArtifactDownload(manifest.primaryArtifact.path);
    if (!mounted) return;
    final TraditionalPalette palette = widget.viewModel.activePalette;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          '正在下载最新安装包：${manifest.primaryArtifact.path}',
          style: AppTypography.label(palette.onCinnabar, fontSize: 13),
        ),
        backgroundColor: palette.cinnabarRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (BuildContext context, _) {
        final TraditionalPalette palette = widget.viewModel.activePalette;
        final AppReleaseManifest? manifest = widget.viewModel.latestManifest;
        if (manifest == null) {
          return const SizedBox.shrink();
        }

        final bool isDownloading =
            widget.viewModel.updateStatus == AppUpdateStatus.downloading;
        final double progress = widget.viewModel.updateProgress;
        final ReleaseArtifactInfo primaryArtifact = manifest.primaryArtifact;

        return Dialog(
          key: const Key('app_auto_update_dialog'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: XuanPaperCard(
              palette: palette,
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // 1. 顶部印章与标题栏
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        const CinnabarSeal(
                          text: '新镌',
                          style: SealStyle.yin,
                          fontSize: 12,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '发现新版本 · 拾句 (ShiJu)',
                                style: AppTypography.sectionHeading(
                                  palette.inkText,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Jenkins 流水线刚刚完成了新版本打包发布',
                                style: AppTypography.attribution(
                                  palette.secondaryText,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!manifest.forceUpdate && !isDownloading)
                          IconButton(
                            tooltip: '稍后更新',
                            onPressed: _handleLater,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: palette.mutedText,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Container(height: 0.6, color: palette.borderLine),
                    const SizedBox(height: 16),

                    // 2. 版本演进对比横幅
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: palette.cinnabarRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: palette.cinnabarRed.withValues(alpha: 0.32),
                          width: 0.9,
                        ),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: <Widget>[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '当前客户端版本',
                                style: AppTypography.label(
                                  palette.mutedText,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _previousDisplayVersion,
                                style: AppTypography.label(
                                  palette.secondaryText,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.trending_flat_rounded,
                            color: palette.cinnabarRed,
                            size: 22,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                'Jenkins 最新构建版本',
                                style: AppTypography.label(
                                  palette.cinnabarRed,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                manifest.displayVersion,
                                key: const Key('update_dialog_target_version'),
                                style: AppTypography.label(
                                  palette.cinnabarRed,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. 构建指纹元信息（Git 分支/Commit 与 SHA-256 校验）
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: <Widget>[
                        _buildMetaItem(
                          palette: palette,
                          icon: Icons.commit_rounded,
                          text:
                              'Git: ${manifest.gitBranch}@${manifest.gitCommit}',
                        ),
                        _buildMetaItem(
                          palette: palette,
                          icon: Icons.verified_user_outlined,
                          text:
                              'SHA-256: ${primaryArtifact.sha256.length >= 12 ? primaryArtifact.sha256.substring(0, 12) : primaryArtifact.sha256}...',
                        ),
                        _buildMetaItem(
                          palette: palette,
                          icon: Icons.inventory_2_outlined,
                          text: '体积: ${primaryArtifact.formattedSize}',
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 4. 本次更新说明 (Release Notes)
                    Text(
                      '本次构建更新内容 (Release Notes)：',
                      style: AppTypography.label(
                        palette.inkText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            palette.elevatedSurface.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: palette.borderLine, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: manifest.releaseNotes.map((String note) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: palette.cinnabarRed,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: AppTypography.label(
                                      palette.secondaryText,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // 5. 下载与 SHA-256 校验进度条
                    if (isDownloading) ...<Widget>[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              widget.viewModel.updateStepLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label(
                                palette.cinnabarRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(progress * 100).round()}%',
                            style: AppTypography.label(
                              palette.cinnabarRed,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          key: const Key('app_update_progress_bar'),
                          value: progress,
                          minHeight: 6,
                          backgroundColor:
                              palette.cinnabarRed.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            palette.cinnabarRed,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 6. 底部操作按钮区
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: <Widget>[
                        if (!manifest.forceUpdate && !isDownloading)
                          TextButton(
                            key: const Key('update_later_button'),
                            onPressed: _handleLater,
                            child: Text(
                              '稍后提醒',
                              style: AppTypography.label(
                                palette.mutedText,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        if (!isDownloading)
                          OutlinedButton.icon(
                            key: const Key('update_download_pkg_button'),
                            onPressed: () => _handleDownloadPackage(manifest),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: palette.borderLine,
                                width: 0.9,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                            ),
                            icon: Icon(
                              Icons.download_rounded,
                              size: 15,
                              color: palette.secondaryText,
                            ),
                            label: Text(
                              '下载安装包',
                              style: AppTypography.label(
                                palette.secondaryText,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        InkWell(
                          key: const Key('confirm_app_update_button'),
                          onTap: isDownloading ? null : _handleStartUpdate,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDownloading
                                  ? palette.cinnabarRed.withValues(alpha: 0.6)
                                  : palette.cinnabarRed,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  isDownloading
                                      ? Icons.sync_rounded
                                      : Icons.system_update_alt_rounded,
                                  size: 16,
                                  color: palette.onCinnabar,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isDownloading
                                      ? '正在热更新升级...'
                                      : '立即更新 (${manifest.displayVersion})',
                                  style: AppTypography.label(
                                    palette.onCinnabar,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
      },
    );
  }

  Widget _buildMetaItem({
    required TraditionalPalette palette,
    required IconData icon,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13.5, color: palette.mutedText),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.label(palette.mutedText, fontSize: 11.5),
        ),
      ],
    );
  }
}
