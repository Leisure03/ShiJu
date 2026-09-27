import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/services/classical_knowledge_service.dart';
import '../../../../data/services/shiquan_api_service.dart';
import '../../../../domain/models/poem_model.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/traditional_palette.dart';
import '../../../core/theme/window_theme_sync.dart';
import '../../../core/widgets/cinnabar_seal.dart';
import '../../../core/widgets/vertical_poetry_renderer.dart';
import '../../../core/widgets/xuan_paper_card.dart';
import '../../poster/views/poster_preview_dialog.dart';
import '../../shiju_view_model.dart';

/// 模块二：诗词详情页 · 全诗与作者深度赏析
class PoemDetailView extends StatefulWidget {
  const PoemDetailView({
    super.key,
    required this.viewModel,
    required this.initialPoem,
  });

  final ShiJuViewModel viewModel;
  final Poem initialPoem;

  /// 使用平滑展开过渡动画打开诗词详情页
  static Future<void> open(
    BuildContext context, {
    required ShiJuViewModel viewModel,
    required Poem poem,
  }) {
    viewModel.selectPoem(poem);
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return PoemDetailView(
            viewModel: viewModel,
            initialPoem: poem,
          );
        },
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final CurvedAnimation curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<PoemDetailView> createState() => _PoemDetailViewState();
}

class _PoemDetailViewState extends State<PoemDetailView> {
  late Poem _activePoem;

  /// 0: 【译文与注释】, 1: 【创作背景与赏析】
  int _selectedAppreciationTab = 0;

  /// 是否展开作者名下全部诗词列表
  bool _authorWorksExpanded = true;

  /// 当前在作者卡片中展开显示的诗作条数上限（避免一次渲染上百首造成滚动卡顿）
  int _visibleAuthorWorksLimit = 12;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _activePoem = ClassicalKnowledgeService.upgradePoemIfNeeded(
      widget.initialPoem,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.viewModel.ensureAuthorPoemsLoaded(_activePoem.authorId);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _switchPoemInDetail(Poem newPoem) {
    if (_activePoem.id == newPoem.id) return;
    final bool sameAuthor = _activePoem.authorId == newPoem.authorId;
    final Poem upgraded = ClassicalKnowledgeService.upgradePoemIfNeeded(newPoem);
    setState(() {
      _activePoem = upgraded;
      if (!sameAuthor) {
        _visibleAuthorWorksLimit = 12;
      }
    });
    widget.viewModel.selectPoem(upgraded);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _copyFullPoem(Poem poem, TraditionalPalette palette) async {
    final String fullText = <String>[
      '《${poem.title}》',
      '〔${poem.dynasty}〕${poem.authorName}',
      '',
      ...poem.paragraphs,
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: fullText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已复制《${poem.title}》全诗至剪贴板',
          style: AppTypography.label(TraditionalPalette.kXuanPaperWhite),
        ),
        backgroundColor: TraditionalPalette.kInkBlack,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _activePoem = ShiquanApiService.upgradeRemotePoemIfNeeded(_activePoem);
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (BuildContext context, _) {
        final Poem latestPoem = widget.viewModel.getPoemById(_activePoem.id) ??
            ClassicalKnowledgeService.upgradePoemIfNeeded(_activePoem);
        _activePoem = latestPoem;
        final TraditionalPalette palette =
            widget.viewModel.paletteForPoem(_activePoem);
        final bool isFavorited = widget.viewModel.isFavorite(_activePoem.id);
        final bool isVertical = widget.viewModel.isVerticalLayout;
        final Author? author = widget.viewModel.getAuthorForPoem(_activePoem);
        final List<Poem> authorWorks = widget.viewModel.getAuthorWorks(
          _activePoem.authorId,
          authorName: _activePoem.authorName,
        );
        final int totalAuthorPoemCount =
            widget.viewModel.getAuthorTotalPoemCount(_activePoem.authorId);
        final bool isLoadingAuthorWorks =
            widget.viewModel.isLoadingAuthorPoems(_activePoem.authorId) ||
                widget.viewModel.isLoadingAuthorWorks;
        final bool canLoadMoreFromCloud =
            widget.viewModel.canLoadMoreAuthorPoems(_activePoem.authorId);

        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: palette.background),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
          builder: (BuildContext context, Color? animatedBg, Widget? child) {
            final Color currentBg = animatedBg ?? palette.background;
            syncWindowThemeColor(currentBg, isDark: palette.isDark);
            return ColoredBox(
              color: currentBg,
              child: child,
            );
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  _buildTopBar(context, palette, isFavorited, isVertical),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 780),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              // 1. 完整诗词正文卡片（含 Hero 过渡与名句朱砂高亮）
                              Hero(
                                tag: 'poem_card_${_activePoem.id}',
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
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      child: toHeroContext.widget,
                                    ),
                                  );
                                },
                                child: _buildFullPoemCard(
                                  palette: palette,
                                  poem: _activePoem,
                                  isVertical: isVertical,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // 2. 多维赏析标签页 (Tabs)：【译文与注释】 / 【创作背景与赏析】
                              _buildAppreciationSection(
                                palette: palette,
                                poem: _activePoem,
                              ),
                              const SizedBox(height: 24),

                              // 3. 作者生平卡片 + 作者作品聚合
                              if (author != null)
                                _buildAuthorProfileCard(
                                  palette: palette,
                                  author: author,
                                  authorWorks: authorWorks,
                                  totalAuthorPoemCount: totalAuthorPoemCount,
                                  isLoadingAuthorWorks: isLoadingAuthorWorks,
                                  canLoadMoreFromCloud: canLoadMoreFromCloud,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 顶部导航操作栏
  Widget _buildTopBar(
    BuildContext context,
    TraditionalPalette palette,
    bool isFavorited,
    bool isVertical,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // 返回首页按钮
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: palette.inkText,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
                label: Text(
                  '返回拾句',
                  style: AppTypography.label(
                    palette.inkText,
                    fontSize: 13.5,
                  ),
                ),
              ),

              // 右侧操作组：横竖排切换、收藏、复制全诗、海报分享
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    // 横排/竖排切换
                    Tooltip(
                      message: isVertical ? '切换为现代横排' : '切换为古籍竖排',
                      child: InkWell(
                        onTap: widget.viewModel.toggleVerticalLayout,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: palette.cardSurface.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: palette.borderLine),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                isVertical
                                    ? Icons.vertical_distribute_rounded
                                    : Icons.format_align_center_rounded,
                                size: 14.5,
                                color: palette.themeAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isVertical ? '古籍竖排' : '现代横排',
                                style: AppTypography.label(
                                  palette.inkText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 收藏按钮（印章点亮）
                    Tooltip(
                      message: isFavorited ? '取消收藏' : '收入藏书阁',
                      child: InkWell(
                        key: const Key('detail_favorite_button'),
                        onTap: () async {
                          final bool added = await widget.viewModel
                              .toggleFavorite(_activePoem.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                added
                                    ? '已将《${_activePoem.title}》收入藏书阁'
                                    : '已从藏书阁移除《${_activePoem.title}》',
                                style: AppTypography.label(
                                  TraditionalPalette.kXuanPaperWhite,
                                ),
                              ),
                              backgroundColor: added
                                  ? TraditionalPalette.kCinnabarRed
                                  : TraditionalPalette.kInkBlack,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isFavorited
                                ? palette.cinnabarRed
                                : palette.cardSurface.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isFavorited
                                  ? palette.cinnabarRed
                                  : palette.borderLine,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                isFavorited
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 14.5,
                                color: isFavorited
                                    ? palette.onCinnabar
                                    : palette.cinnabarRed,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isFavorited ? '已藏' : '珍藏',
                                style: AppTypography.label(
                                  isFavorited
                                      ? palette.onCinnabar
                                      : palette.inkText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 复制全诗
                    IconButton(
                      tooltip: '复制全诗',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copyFullPoem(_activePoem, palette),
                      icon: Icon(
                        Icons.copy_all_rounded,
                        size: 18.5,
                        color: palette.secondaryText,
                      ),
                    ),

                    // 生成诗笺海报
                    IconButton(
                      tooltip: '生成诗笺海报',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        PosterPreviewDialog.show(
                          context,
                          poem: _activePoem,
                          palette: palette,
                          isVertical: isVertical,
                          currentUser: widget.viewModel.currentUser,
                        );
                      },
                      icon: Icon(
                        Icons.qr_code_2_rounded,
                        size: 19.5,
                        color: palette.themeAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. 完整诗词正文卡片（自动高亮推荐名句）
  Widget _buildFullPoemCard({
    required TraditionalPalette palette,
    required Poem poem,
    required bool isVertical,
  }) {
    return XuanPaperCard(
      palette: palette,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // 顶部传统色题签与拾句印章
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: palette.themeAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '传统色 · ${palette.name}',
                    style: AppTypography.label(
                      palette.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const CinnabarSeal(
                text: '全诗展卷',
                style: SealStyle.yang,
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 22),

          // 诗名
          Text(
            poem.title,
            textAlign: TextAlign.center,
            style: AppTypography.poemTitle(
              palette.inkText,
              fontSize: 27,
            ),
          ),
          const SizedBox(height: 12),

          // 朝代印章 + 作者姓名
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CinnabarSeal(
                text: poem.dynasty,
                style: SealStyle.yin,
                fontSize: 11,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
              const SizedBox(width: 8),
              Text(
                poem.authorName,
                style: AppTypography.attribution(
                  palette.secondaryText,
                  fontSize: 15.5,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // 完整诗词正文（支持现代横排与古籍竖排切换，均带推荐名句朱砂红高亮）
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: isVertical
                ? Padding(
                    key: ValueKey<String>('detail_vertical_${poem.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: VerticalPoetryRenderer(
                      lines: poem.paragraphs,
                      palette: palette,
                      fontSize: 22,
                      columnSpacing: 22,
                      highlightedLinePredicate: poem.isLineHighlighted,
                    ),
                  )
                : Column(
                    key: ValueKey<String>('detail_horizontal_${poem.id}'),
                    children: poem.paragraphs.map((String line) {
                      final bool highlighted = poem.isLineHighlighted(line);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _buildHighlightedVerseLine(
                          line: line,
                          highlighted: highlighted,
                          palette: palette,
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 24),

          // 名句高亮图例说明与意境标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.elevatedSurface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: palette.borderLine),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: palette.cinnabarRed.withValues(alpha: 0.22),
                        border: Border(
                          bottom: BorderSide(
                            color: palette.cinnabarRed,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        '朱砂标红处即为首页推荐名句：「${poem.featuredQuote}」',
                        style: AppTypography.label(
                          palette.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: poem.tags
                      .map(
                        (String tag) => InkWell(
                          onTap: () {
                            widget.viewModel.jumpToExploreWithTag(tag);
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  palette.themeAccent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#$tag',
                              style: AppTypography.label(
                                palette.themeAccent,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 横排诗句行渲染（名句自动使用朱砂红底纹与朱砂下划线高亮）
  Widget _buildHighlightedVerseLine({
    required String line,
    required bool highlighted,
    required TraditionalPalette palette,
  }) {
    if (!highlighted) {
      return Text(
        line,
        textAlign: TextAlign.center,
        style: AppTypography.poemBody(
          palette.inkText,
          fontSize: 20.5,
        ),
      );
    }

    return Container(
      key: ValueKey<String>('highlighted_line_$line'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: palette.cinnabarRed.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(5),
        border: Border(
          bottom: BorderSide(
            color: palette.cinnabarRed.withValues(alpha: 0.85),
            width: 2.0,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const CinnabarSeal(
            text: '拾句',
            style: SealStyle.yin,
            fontSize: 10,
            padding: EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: AppTypography.poemBody(
                palette.inkText,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. 多维赏析标签页（【译文与注释】与【创作背景与赏析】）
  Widget _buildAppreciationSection({
    required TraditionalPalette palette,
    required Poem poem,
  }) {
    return XuanPaperCard(
      palette: palette,
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 自定义新中式分段 Tab 切换器
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: palette.elevatedSurface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.borderLine),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _buildTabButton(
                    index: 0,
                    title: '【译文与注释】',
                    icon: Icons.menu_book_rounded,
                    palette: palette,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildTabButton(
                    index: 1,
                    title: '【创作背景与赏析】',
                    icon: Icons.auto_stories_rounded,
                    palette: palette,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tab 内容区
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _selectedAppreciationTab == 0
                ? _buildTranslationAndAnnotationsTab(palette, poem)
                : _buildBackgroundAndAppreciationTab(palette, poem),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String title,
    required IconData icon,
    required TraditionalPalette palette,
  }) {
    final bool isSelected = _selectedAppreciationTab == index;
    return InkWell(
      key: Key('detail_tab_$index'),
      onTap: () {
        setState(() {
          _selectedAppreciationTab = index;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? palette.cardSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(
                  color: palette.themeAccent.withValues(alpha: 0.35),
                )
              : null,
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 16,
              color: isSelected ? palette.cinnabarRed : palette.mutedText,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(
                  isSelected ? palette.inkText : palette.mutedText,
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab 0: 【译文与注释】
  Widget _buildTranslationAndAnnotationsTab(
    TraditionalPalette palette,
    Poem poem,
  ) {
    return Column(
      key: ValueKey<String>('tab_trans_${poem.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSectionTitle(
          title: '诗意今译',
          sealText: '译',
          palette: palette,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.background.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(
                color: palette.themeAccent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            poem.translation,
            style: AppTypography.prose(palette.inkText),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(
          title: '字词典故逐条注释',
          sealText: '注',
          palette: palette,
        ),
        const SizedBox(height: 12),
        ...poem.annotations.map(
          (PoemAnnotation note) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: palette.background.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: palette.borderLine),
              ),
              child: RichText(
                text: TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: '〔${note.term}〕 ',
                      style: AppTypography.prose(
                        palette.themeAccent,
                        fontSize: 15,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: note.explanation,
                      style: AppTypography.prose(
                        palette.secondaryText,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Tab 1: 【创作背景与赏析】
  Widget _buildBackgroundAndAppreciationTab(
    TraditionalPalette palette,
    Poem poem,
  ) {
    return Column(
      key: ValueKey<String>('tab_bg_${poem.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: _buildSectionTitle(
                title: '创作背景与生平境遇',
                sealText: '境',
                palette: palette,
              ),
            ),
            if (poem.isRemote)
              InkWell(
                key: const Key('detail_ai_enrich_button'),
                onTap: widget.viewModel.isEnrichingPoem
                    ? null
                    : () => _showAiEnrichmentDialog(context, palette, poem),
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.themeAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: palette.themeAccent.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        widget.viewModel.isEnrichingPoem
                            ? Icons.hourglass_top_rounded
                            : Icons.auto_awesome_rounded,
                        size: 13,
                        color: palette.themeAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.viewModel.isEnrichingPoem
                            ? '正在考据...'
                            : '百科 / AI 深度考据',
                        style: AppTypography.label(
                          palette.themeAccent,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.background.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: palette.borderLine),
          ),
          child: Text(
            poem.background,
            style: AppTypography.prose(palette.inkText),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(
          title: '东方审美深度鉴赏',
          sealText: '赏',
          palette: palette,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.background.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(
                color: palette.cinnabarRed,
                width: 3,
              ),
            ),
          ),
          child: Text(
            poem.appreciation,
            style: AppTypography.prose(palette.inkText),
          ),
        ),
      ],
    );
  }

  Future<void> _showAiEnrichmentDialog(
    BuildContext context,
    TraditionalPalette palette,
    Poem poem,
  ) async {
    final TextEditingController apiKeyCtrl = TextEditingController();
    final TextEditingController baseUrlCtrl = TextEditingController(
      text: ClassicalKnowledgeService.kDefaultAiBaseUrl,
    );
    final TextEditingController modelCtrl = TextEditingController(
      text: ClassicalKnowledgeService.kDefaultAiModel,
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: palette.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: palette.borderLine),
          ),
          title: Row(
            children: <Widget>[
              const CinnabarSeal(
                text: '考据',
                style: SealStyle.yin,
                fontSize: 11,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '百科与 AI 深度考据增强',
                  style: AppTypography.sectionHeading(palette.inkText),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '当前已启用「内置古典名家/典故知识库 + 逐联起承转合深度解析 + 中文维基百科史料检索」。如需调用大模型进一步定制研读《${poem.title}》，可在此填入可选 API Key（留空则仅执行在线百科史料增补）：',
                    style: AppTypography.prose(
                      palette.secondaryText,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: apiKeyCtrl,
                    obscureText: true,
                    style: AppTypography.label(palette.inkText, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'AI API Key（可选，支持 Gemini / OpenAI 兼容）',
                      labelStyle: AppTypography.label(
                        palette.mutedText,
                        fontSize: 12,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: baseUrlCtrl,
                    style: AppTypography.label(palette.inkText, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'API Base URL',
                      labelStyle: AppTypography.label(
                        palette.mutedText,
                        fontSize: 12,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: modelCtrl,
                    style: AppTypography.label(palette.inkText, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: '模型名称（如 gemini-2.5-flash / deepseek-chat）',
                      labelStyle: AppTypography.label(
                        palette.mutedText,
                        fontSize: 12,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                '取消',
                style: AppTypography.label(palette.mutedText),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: palette.cinnabarRed,
                foregroundColor: palette.onCinnabar,
              ),
              onPressed: () async {
                final String key = apiKeyCtrl.text.trim();
                final String url = baseUrlCtrl.text.trim();
                final String model = modelCtrl.text.trim();
                Navigator.of(dialogContext).pop();
                final Poem? updated = await widget.viewModel.enrichPoemOnline(
                  poem,
                  customApiKey: key.isEmpty ? null : key,
                  customBaseUrl: url.isEmpty ? null : url,
                  customModel: model.isEmpty ? null : model,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      updated != null
                          ? '已更新《${poem.title}》深度考据与作者生平'
                          : '已完成《${poem.title}》古典文献库与百科核验',
                      style: AppTypography.label(
                        TraditionalPalette.kXuanPaperWhite,
                      ),
                    ),
                    backgroundColor: TraditionalPalette.kInkBlack,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 15),
              label: Text(
                '立即深度考据',
                style: AppTypography.label(palette.onCinnabar, fontSize: 13),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String sealText,
    required TraditionalPalette palette,
  }) {
    return Row(
      children: <Widget>[
        CinnabarSeal(
          text: sealText,
          style: SealStyle.yin,
          fontSize: 11,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: AppTypography.sectionHeading(palette.inkText),
        ),
      ],
    );
  }

  /// 3. 作者生平卡片 (Author Profile) + 作者作品聚合
  Widget _buildAuthorProfileCard({
    required TraditionalPalette palette,
    required Author author,
    required List<Poem> authorWorks,
    required int totalAuthorPoemCount,
    required bool isLoadingAuthorWorks,
    required bool canLoadMoreFromCloud,
  }) {
    final int displayTotal = totalAuthorPoemCount >= authorWorks.length
        ? totalAuthorPoemCount
        : authorWorks.length;

    final List<Poem> visibleWorks;
    if (authorWorks.length <= _visibleAuthorWorksLimit) {
      visibleWorks = authorWorks;
    } else {
      final List<Poem> slice =
          authorWorks.take(_visibleAuthorWorksLimit).toList();
      if (!slice.any((Poem p) => p.id == _activePoem.id)) {
        final Poem? activeInList = authorWorks
            .where((Poem p) => p.id == _activePoem.id)
            .firstOrNull;
        if (activeInList != null) {
          slice.insert(0, activeInList);
          if (slice.length > _visibleAuthorWorksLimit) {
            slice.removeLast();
          }
        }
      }
      visibleWorks = slice;
    }

    final bool hasMoreLoadedToExpand =
        authorWorks.length > visibleWorks.length;

    return XuanPaperCard(
      palette: palette,
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 诗人头衔区：姓名、朝代印章、字号、生卒年
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 诗人姓氏大印章头像
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.themeAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: palette.themeAccent.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  author.name.substring(0, 1),
                  style: AppTypography.poemTitle(
                    palette.themeAccent,
                    fontSize: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: <Widget>[
                        Text(
                          author.name,
                          style: AppTypography.poemTitle(
                            palette.inkText,
                            fontSize: 21,
                          ),
                        ),
                        CinnabarSeal(
                          text: '${author.dynasty}代诗人',
                          style: SealStyle.yang,
                          fontSize: 10.5,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${author.courtesyName}  ｜  ${author.lifeSpan}',
                      style: AppTypography.attribution(
                        palette.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: palette.borderLine, height: 1),
          const SizedBox(height: 16),

          // 生平小传正文
          Text(
            author.biography,
            style: AppTypography.prose(
              palette.secondaryText,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 22),

          // 作者作品聚合入口：「查看该作者收录的全部诗词（共 X 首）」
          InkWell(
            key: const Key('author_works_toggle'),
            onTap: () {
              setState(() {
                _authorWorksExpanded = !_authorWorksExpanded;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: palette.themeAccent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: palette.themeAccent.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.library_books_rounded,
                          size: 16,
                          color: palette.themeAccent,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '查看该作者收录的全部诗词（共 $displayTotal 首）',
                            style: AppTypography.label(
                              palette.themeAccent,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (isLoadingAuthorWorks) ...<Widget>[
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: palette.themeAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        _authorWorksExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: palette.themeAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 展开的同作者作品列表（点击可直接平滑切换阅读）
          if (_authorWorksExpanded) ...<Widget>[
            const SizedBox(height: 12),
            ...visibleWorks.map((Poem work) {
              final bool isCurrent = work.id == _activePoem.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  key: Key('author_work_item_${work.id}'),
                  onTap: () => _switchPoemInDetail(work),
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? palette.cinnabarRed.withValues(alpha: 0.09)
                          : palette.background.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCurrent
                            ? palette.cinnabarRed.withValues(alpha: 0.65)
                            : palette.borderLine,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      '《${work.title}》',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.label(
                                        palette.inkText,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (isCurrent) ...<Widget>[
                                    const SizedBox(width: 8),
                                    const CinnabarSeal(
                                      text: '当前品读',
                                      style: SealStyle.yin,
                                      fontSize: 9.5,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                work.featuredQuote,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.attribution(
                                  palette.secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isCurrent
                              ? Icons.visibility_rounded
                              : Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isCurrent
                              ? palette.cinnabarRed
                              : palette.mutedText,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            // 展开更多或从诗泉云端继续加载下一页作者诗作
            if (hasMoreLoadedToExpand || canLoadMoreFromCloud)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InkWell(
                  key: const Key('author_works_load_more_button'),
                  onTap: isLoadingAuthorWorks
                      ? null
                      : () async {
                          setState(() {
                            _visibleAuthorWorksLimit += 20;
                          });
                          if (!hasMoreLoadedToExpand && canLoadMoreFromCloud) {
                            await widget.viewModel
                                .loadMoreAuthorPoems(author.id);
                          }
                        },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: palette.background.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: palette.borderLine),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 16,
                          color: palette.themeAccent,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            hasMoreLoadedToExpand
                                ? '展开更多该作者诗作（当前显示 ${visibleWorks.length} / 已载入 ${authorWorks.length} 首 · 共 $displayTotal 首）'
                                : '从诗泉云库继续加载更多诗作（已载入 ${authorWorks.length} / 共 $displayTotal 首）',
                            textAlign: TextAlign.center,
                            style: AppTypography.label(
                              palette.themeAccent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

