import 'package:flutter/material.dart';
import '../../../../domain/models/poem_model.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/traditional_palette.dart';
import '../../../core/widgets/cinnabar_seal.dart';
import '../../../core/widgets/xuan_paper_card.dart';
import '../../detail/views/poem_detail_view.dart';
import '../../shiju_view_model.dart';

/// 模块三（下）：我的藏书阁 · 收藏夹与阅读历史
class CollectionView extends StatefulWidget {
  const CollectionView({
    super.key,
    required this.viewModel,
  });

  final ShiJuViewModel viewModel;

  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  /// 0: 雅藏·收藏夹, 1: 足迹·阅读历史
  int _selectedSubTab = 0;

  @override
  Widget build(BuildContext context) {
    final TraditionalPalette palette = widget.viewModel.activePalette;
    final List<Poem> favorites = widget.viewModel.favoritePoems;
    final List<Poem> history = widget.viewModel.historyPoems;
    final List<Poem> activeList = _selectedSubTab == 0 ? favorites : history;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 顶部藏书阁抬头与切换栏
              XuanPaperCard(
                palette: palette,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
                showCornerOrnaments: false,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CinnabarSeal(
                          text: '藏书阁',
                          style: SealStyle.yin,
                          fontSize: 12,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '收录心仪诗笺与漫游足迹（本地持久保存）',
                          style: AppTypography.attribution(
                            palette.secondaryText,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),

                    // 收藏夹 / 阅读历史切换按钮组
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _buildSubTabChip(
                          key: const Key('collection_tab_favorites'),
                          index: 0,
                          label: '雅藏 · 收藏夹 (${favorites.length})',
                          palette: palette,
                        ),
                        const SizedBox(width: 8),
                        _buildSubTabChip(
                          key: const Key('collection_tab_history'),
                          index: 1,
                          label: '足迹 · 阅读历史 (${history.length})',
                          palette: palette,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 列表内容区
              Expanded(
                child: activeList.isEmpty
                    ? _buildEmptyCollectionState(palette)
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: activeList.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (BuildContext context, int index) {
                          final Poem poem = activeList[index];
                          return _buildCollectionPoemCard(
                            context: context,
                            poem: poem,
                            palette: palette,
                            isFavoritesTab: _selectedSubTab == 0,
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

  Widget _buildSubTabChip({
    required Key key,
    required int index,
    required String label,
    required TraditionalPalette palette,
  }) {
    final bool isSelected = _selectedSubTab == index;
    return InkWell(
      key: key,
      onTap: () {
        setState(() {
          _selectedSubTab = index;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.themeAccent
              : palette.background.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? palette.themeAccent : palette.borderLine,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label(
            isSelected
                ? TraditionalPalette.kXuanPaperWhite
                : palette.secondaryText,
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionPoemCard({
    required BuildContext context,
    required Poem poem,
    required TraditionalPalette palette,
    required bool isFavoritesTab,
  }) {
    final TraditionalPalette poemPalette =
        TraditionalPalette.resolve(poem.paletteType);

    return XuanPaperCard(
      key: Key('collection_card_${poem.id}'),
      palette: palette,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      showCornerOrnaments: false,
      onTap: () {
        PoemDetailView.open(
          context,
          viewModel: widget.viewModel,
          poem: poem,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // 左侧传统色竖条修饰
          Container(
            width: 4,
            height: 66,
            decoration: BoxDecoration(
              color: poemPalette.themeAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),

          // 中间诗句与出处
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CinnabarSeal(
                      text: poem.dynasty,
                      style: SealStyle.yang,
                      fontSize: 10.5,
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
                          palette.inkText,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '· ${poemPalette.name}',
                      style: AppTypography.label(
                        palette.mutedText,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  poem.featuredQuote,
                  style: AppTypography.poemBody(
                    palette.inkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 右侧操作：收藏夹支持移除收藏，历史列表支持加入/取消收藏
          if (isFavoritesTab)
            Tooltip(
              message: '移除收藏',
              child: OutlinedButton.icon(
                key: Key('remove_favorite_${poem.id}'),
                onPressed: () async {
                  await widget.viewModel.removeFavorite(poem.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '已从藏书阁移除《${poem.title}》',
                        style: AppTypography.label(
                          TraditionalPalette.kXuanPaperWhite,
                        ),
                      ),
                      backgroundColor: palette.inkText,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.cinnabarRed,
                  side: BorderSide(
                    color: palette.cinnabarRed.withValues(alpha: 0.45),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 15),
                label: Text(
                  '移除收藏',
                  style: AppTypography.label(
                    palette.cinnabarRed,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: palette.mutedText,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCollectionState(TraditionalPalette palette) {
    final bool isFavTab = _selectedSubTab == 0;
    return Center(
      child: XuanPaperCard(
        palette: palette,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 42),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CinnabarSeal(
              text: isFavTab ? '虚席以待' : '尚无足迹',
              style: SealStyle.yang,
              fontSize: 13,
            ),
            const SizedBox(height: 16),
            Text(
              isFavTab
                  ? '藏书阁中尚无珍藏诗笺\n在首页或详情页轻触「收藏佳句」即可收入阁中'
                  : '尚无阅读漫游记录',
              textAlign: TextAlign.center,
              style: AppTypography.prose(
                palette.mutedText,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () =>
                  widget.viewModel.setActiveTab(ShiJuNavTab.home),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.themeAccent,
                side: BorderSide(color: palette.themeAccent),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: Text(
                '前往首页拾句',
                style: AppTypography.label(palette.themeAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
