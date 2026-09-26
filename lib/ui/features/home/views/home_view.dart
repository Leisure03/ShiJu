import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../domain/models/poem_model.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/traditional_palette.dart';
import '../../../core/widgets/cinnabar_seal.dart';
import '../../../core/widgets/vertical_poetry_renderer.dart';
import '../../../core/widgets/xuan_paper_card.dart';
import '../../detail/views/poem_detail_view.dart';
import '../../poster/views/poster_preview_dialog.dart';
import '../../shiju_view_model.dart';

/// 模块一：首页 · 名句卡片流
class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.viewModel,
  });

  final ShiJuViewModel viewModel;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sealPulseController;
  late final Animation<double> _sealScaleAnimation;

  @override
  void initState() {
    super.initState();
    _sealPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _sealScaleAnimation = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.26)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.26, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_sealPulseController);
  }

  @override
  void dispose() {
    _sealPulseController.dispose();
    super.dispose();
  }

  Future<void> _handleCopyQuote(Poem poem, TraditionalPalette palette) async {
    final String text = '${poem.featuredQuote} —— ${poem.formattedAttribution}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已复制名句：「${poem.featuredQuote}」',
          style: AppTypography.label(TraditionalPalette.kXuanPaperWhite),
        ),
        backgroundColor: palette.inkText,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleToggleFavorite(
    Poem poem,
    TraditionalPalette palette,
  ) async {
    _sealPulseController.forward(from: 0);
    final bool isNowFav = await widget.viewModel.toggleFavorite(poem.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isNowFav
              ? '朱砂落印 · 已将《${poem.title}》收入藏书阁'
              : '已从藏书阁移除《${poem.title}》',
          style: AppTypography.label(TraditionalPalette.kXuanPaperWhite),
        ),
        backgroundColor:
            isNowFav ? TraditionalPalette.kCinnabarRed : palette.inkText,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Poem poem = widget.viewModel.currentPoem;
    final TraditionalPalette palette = widget.viewModel.activePalette;
    final bool isVertical = widget.viewModel.isVerticalLayout;
    final bool isFavorited = widget.viewModel.isFavorite(poem.id);

    return GestureDetector(
      onHorizontalDragEnd: (DragEndDetails details) {
        final double velocity = details.primaryVelocity ?? 0;
        if (velocity < -220) {
          widget.viewModel.nextQuote();
        } else if (velocity > 220) {
          widget.viewModel.previousQuote();
        }
      },
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 24).clamp(420.0, 2000.0),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      // 顶部当前传统色意境微标
                      _buildPaletteSubHeader(palette, poem),
                      const SizedBox(height: 16),

                      // 中央核心「诗笺卡片」：点击卡片任意区域平滑展开至完整诗词详情页
                      Hero(
                        tag: 'poem_card_${poem.id}',
                        flightShuttleBuilder: (
                          BuildContext flightContext,
                          Animation<double> animation,
                          HeroFlightDirection flightDirection,
                          BuildContext fromHeroContext,
                          BuildContext toHeroContext,
                        ) {
                          return Material(
                            color: Colors.transparent,
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: toHeroContext.widget,
                            ),
                          );
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 460),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (
                            Widget child,
                            Animation<double> animation,
                          ) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.03),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _buildQuoteCard(
                            key: ValueKey<String>(
                              'quote_${poem.id}_$isVertical',
                            ),
                            context: context,
                            poem: poem,
                            palette: palette,
                            isVertical: isVertical,
                            isFavorited: isFavorited,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 底部漫游与快捷操作栏
                      _buildBottomActionSection(
                        context: context,
                        poem: poem,
                        palette: palette,
                        isVertical: isVertical,
                        isFavorited: isFavorited,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 顶部传统色美学心境提示条
  Widget _buildPaletteSubHeader(TraditionalPalette palette, Poem poem) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: palette.themeAccent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${palette.name} · ${palette.poeticDescription}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.attribution(
              palette.mutedText,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  /// 中央核心名句诗笺卡片
  Widget _buildQuoteCard({
    required Key key,
    required BuildContext context,
    required Poem poem,
    required TraditionalPalette palette,
    required bool isVertical,
    required bool isFavorited,
  }) {
    return XuanPaperCard(
      key: key,
      palette: palette,
      padding: const EdgeInsets.fromLTRB(30, 28, 30, 26),
      onTap: () {
        PoemDetailView.open(
          context,
          viewModel: widget.viewModel,
          poem: poem,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 卡片眉栏：今日拾句朱砂印章 + 收藏红豆印记 + 篇目序号
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CinnabarSeal(
                    text: '今日拾句',
                    style: SealStyle.yang,
                    fontSize: 11.5,
                  ),
                  const SizedBox(width: 8),
                  CinnabarSeal(
                    text: poem.dynasty,
                    style: SealStyle.yin,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5.5,
                      vertical: 2,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (isFavorited) ...<Widget>[
                    const CinnabarSeal(
                      text: '藏',
                      style: SealStyle.yin,
                      fontSize: 11,
                      padding: EdgeInsets.symmetric(
                        horizontal: 5.5,
                        vertical: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '第 ${widget.viewModel.currentIndex + 1} / ${widget.viewModel.allPoems.length} 笺',
                    style: AppTypography.label(
                      palette.mutedText,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 36),

          // 核心名句展示区（仅展示一句精选名句，适配古籍竖排与现代横排居中）
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 230),
            child: Center(
              child: isVertical
                  ? VerticalPoetryRenderer(
                      lines: <String>[poem.featuredQuote],
                      palette: palette,
                      fontSize: 27,
                      columnSpacing: 26,
                      attributionText:
                          '〔${poem.dynasty}〕${poem.authorName} ·《${poem.title}》',
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 20,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            poem.featuredQuote,
                            textAlign: TextAlign.center,
                            style: AppTypography.quoteHorizontal(
                              palette.inkText,
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            poem.formattedAttribution,
                            textAlign: TextAlign.center,
                            style: AppTypography.attribution(
                              palette.secondaryText,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 28),
          Divider(color: palette.borderLine, height: 1),
          const SizedBox(height: 16),

          // 卡片底栏：意境标签（#星空 #旷达 等）+ 点击展卷提示
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: <Widget>[
              // 意境标签列表
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: poem.tags.map((String tag) {
                  return InkWell(
                    onTap: () => widget.viewModel.jumpToExploreWithTag(tag),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.themeAccent.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: palette.themeAccent.withValues(alpha: 0.22),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '#$tag',
                        style: AppTypography.label(
                          palette.themeAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // 展卷品读全诗提示
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '轻触诗笺 · 展卷品读全诗与译注',
                    style: AppTypography.label(
                      palette.mutedText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_full_rounded,
                    size: 13.5,
                    color: palette.themeAccent,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 底部漫游切换与快捷操作区
  Widget _buildBottomActionSection({
    required BuildContext context,
    required Poem poem,
    required TraditionalPalette palette,
    required bool isVertical,
    required bool isFavorited,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 1. 漫游控制栏：上一句 | 偶遇下一句 | 下一句
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: <Widget>[
            // 上一句
            _buildOutlineControlButton(
              key: const Key('prev_quote_button'),
              palette: palette,
              icon: Icons.chevron_left_rounded,
              label: '上一句',
              onTap: widget.viewModel.previousQuote,
            ),

            // 偶遇下一句（核心主按钮）
            FilledButton.icon(
              key: const Key('roam_random_button'),
              onPressed: widget.viewModel.roamRandomQuote,
              style: FilledButton.styleFrom(
                backgroundColor: palette.themeAccent,
                foregroundColor: TraditionalPalette.kXuanPaperWhite,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 17),
              label: Text(
                '偶遇下一句',
                style: AppTypography.label(
                  TraditionalPalette.kXuanPaperWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // 下一句
            _buildOutlineControlButton(
              key: const Key('next_quote_button'),
              palette: palette,
              icon: Icons.chevron_right_rounded,
              label: '下一句',
              iconOnRight: true,
              onTap: widget.viewModel.nextQuote,
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 2. 快捷操作栏：收藏/取消收藏（红豆/印章动效）、一键复制名句、生成诗笺海报
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: palette.cardSurface.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.borderLine),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 18,
            runSpacing: 8,
            children: <Widget>[
              // 收藏/取消收藏（带红豆/印章缩放点亮动效）
              ScaleTransition(
                scale: _sealScaleAnimation,
                child: InkWell(
                  key: const Key('home_favorite_button'),
                  onTap: () => _handleToggleFavorite(poem, palette),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          isFavorited
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 17,
                          color: isFavorited
                              ? palette.cinnabarRed
                              : palette.secondaryText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isFavorited ? '已收入藏书阁' : '收藏佳句',
                          style: AppTypography.label(
                            isFavorited
                                ? palette.cinnabarRed
                                : palette.secondaryText,
                            fontSize: 13,
                            fontWeight: isFavorited
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              _buildSmallDivider(palette),

              // 一键复制名句
              InkWell(
                key: const Key('home_copy_button'),
                onTap: () => _handleCopyQuote(poem, palette),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.content_copy_rounded,
                        size: 15.5,
                        color: palette.secondaryText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '复制名句',
                        style: AppTypography.label(
                          palette.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _buildSmallDivider(palette),

              // 打开「生成诗笺海报」预览弹窗
              InkWell(
                key: const Key('home_poster_button'),
                onTap: () {
                  PosterPreviewDialog.show(
                    context,
                    poem: poem,
                    palette: palette,
                    isVertical: isVertical,
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.qr_code_2_rounded,
                        size: 17,
                        color: palette.themeAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '生成诗笺海报',
                        style: AppTypography.label(
                          palette.themeAccent,
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
        ),

        const SizedBox(height: 8),
        Text(
          '提示：按「空格键 Space」可随时偶遇下一句 · 左右方向键切换上下句',
          textAlign: TextAlign.center,
          style: AppTypography.label(
            palette.mutedText.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildOutlineControlButton({
    required Key key,
    required TraditionalPalette palette,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool iconOnRight = false,
  }) {
    return OutlinedButton(
      key: key,
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.inkText,
        backgroundColor: palette.cardSurface.withValues(alpha: 0.65),
        side: BorderSide(color: palette.borderLine),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!iconOnRight) ...<Widget>[
            Icon(icon, size: 17, color: palette.secondaryText),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.label(
              palette.inkText,
              fontSize: 13,
            ),
          ),
          if (iconOnRight) ...<Widget>[
            const SizedBox(width: 4),
            Icon(icon, size: 17, color: palette.secondaryText),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallDivider(TraditionalPalette palette) {
    return Container(
      width: 1,
      height: 14,
      color: palette.borderLine,
    );
  }
}
