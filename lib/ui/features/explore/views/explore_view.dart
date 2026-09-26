import 'package:flutter/material.dart';
import '../../../../domain/models/poem_model.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/traditional_palette.dart';
import '../../../core/widgets/cinnabar_seal.dart';
import '../../../core/widgets/xuan_paper_card.dart';
import '../../detail/views/poem_detail_view.dart';
import '../../shiju_view_model.dart';

/// 模块三（上）：寻章摘句 · 探索与意境分类搜索
class ExploreView extends StatefulWidget {
  const ExploreView({
    super.key,
    required this.viewModel,
  });

  final ShiJuViewModel viewModel;

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.viewModel.searchQuery,
    );
  }

  @override
  void didUpdateWidget(covariant ExploreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchController.text != widget.viewModel.searchQuery) {
      _searchController.text = widget.viewModel.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TraditionalPalette palette = widget.viewModel.activePalette;
    final List<String> tags = widget.viewModel.allMoodTags;
    final String selectedTag = widget.viewModel.selectedTag;
    final List<Poem> results = widget.viewModel.filteredPoems;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 1. 搜索框与意境分类筛选面板
              XuanPaperCard(
                palette: palette,
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                showCornerOrnaments: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 实时搜索框
                    TextField(
                      key: const Key('explore_search_input'),
                      controller: _searchController,
                      onChanged: widget.viewModel.setSearchQuery,
                      style: AppTypography.prose(
                        palette.inkText,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: '寻章摘句：输入诗句关键词、诗名或作者姓名（如：苏轼、星河、明月）',
                        hintStyle: AppTypography.attribution(
                          palette.mutedText,
                          fontSize: 13.5,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: palette.themeAccent,
                          size: 20,
                        ),
                        suffixIcon: widget.viewModel.searchQuery.isNotEmpty
                            ? IconButton(
                                tooltip: '清空搜索词',
                                onPressed: () {
                                  _searchController.clear();
                                  widget.viewModel.setSearchQuery('');
                                },
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 18,
                                  color: palette.mutedText,
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: palette.background.withValues(alpha: 0.65),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: palette.borderLine),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: palette.borderLine),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: palette.themeAccent,
                            width: 1.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 意境分类筛选标签栏
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          '意境雅集：',
                          style: AppTypography.label(
                            palette.mutedText,
                            fontSize: 12.5,
                          ),
                        ),
                        ...tags.map((String tag) {
                          final bool isSelected = tag == selectedTag;
                          return InkWell(
                            key: Key('explore_tag_$tag'),
                            onTap: () => widget.viewModel.setSelectedTag(tag),
                            borderRadius: BorderRadius.circular(5),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? palette.cinnabarRed
                                    : palette.background
                                        .withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: isSelected
                                      ? palette.cinnabarRed
                                      : palette.borderLine,
                                ),
                              ),
                              child: Text(
                                '#$tag',
                                style: AppTypography.label(
                                  isSelected
                                      ? TraditionalPalette.kXuanPaperWhite
                                      : palette.secondaryText,
                                  fontSize: 12.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. 检索结果计数与重置栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '共寻得 ${results.length} 首佳作',
                      style: AppTypography.label(
                        palette.mutedText,
                        fontSize: 12.5,
                      ),
                    ),
                    if (widget.viewModel.searchQuery.isNotEmpty ||
                        widget.viewModel.selectedTag != '全部')
                      TextButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          widget.viewModel.resetExploreFilters();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: palette.cinnabarRed,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: Text(
                          '重置筛选',
                          style: AppTypography.label(
                            palette.cinnabarRed,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // 3. 检索结果列表/网格
              Expanded(
                child: results.isEmpty
                    ? _buildEmptyState(palette)
                    : LayoutBuilder(
                        builder: (
                          BuildContext context,
                          BoxConstraints constraints,
                        ) {
                          final bool useGrid = constraints.maxWidth >= 620;
                          if (useGrid) {
                            return GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 460,
                                mainAxisExtent: 195,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                              ),
                              itemCount: results.length,
                              itemBuilder: (BuildContext context, int index) {
                                return _buildPoemResultCard(
                                  context,
                                  results[index],
                                  palette,
                                );
                              },
                            );
                          }
                          return ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: results.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              return _buildPoemResultCard(
                                context,
                                results[index],
                                palette,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPoemResultCard(
    BuildContext context,
    Poem poem,
    TraditionalPalette activePalette,
  ) {
    final TraditionalPalette poemPalette =
        TraditionalPalette.resolve(poem.paletteType);
    final bool isFav = widget.viewModel.isFavorite(poem.id);

    return XuanPaperCard(
      key: Key('explore_poem_card_${poem.id}'),
      palette: activePalette,
      padding: const EdgeInsets.all(18),
      showCornerOrnaments: false,
      onTap: () {
        PoemDetailView.open(
          context,
          viewModel: widget.viewModel,
          poem: poem,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 顶部：朝代印章 + 诗名 + 作者 + 传统色圆点
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        CinnabarSeal(
                          text: poem.dynasty,
                          style: SealStyle.yin,
                          fontSize: 10,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${poem.authorName} ·《${poem.title}》',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label(
                              activePalette.inkText,
                              fontSize: 14,
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
                      if (isFav) ...<Widget>[
                        Icon(
                          Icons.favorite_rounded,
                          size: 14,
                          color: activePalette.cinnabarRed,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: poemPalette.themeAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 精选名句
              Text(
                poem.featuredQuote,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.poemBody(
                  activePalette.inkText,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w500,
                ).copyWith(height: 1.55),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 底部：意境标签与阅读箭头
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: poem.tags.map((String tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            activePalette.themeAccent.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '#$tag',
                        style: AppTypography.label(
                          activePalette.themeAccent,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: activePalette.mutedText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TraditionalPalette palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CinnabarSeal(
            text: '未遇知音',
            style: SealStyle.yang,
            fontSize: 13,
          ),
          const SizedBox(height: 14),
          Text(
            '未寻得匹配的诗词佳句，不妨换个关键词或意境标签一试',
            textAlign: TextAlign.center,
            style: AppTypography.attribution(palette.mutedText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
