import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/traditional_palette.dart';
import '../core/theme/window_theme_sync.dart';
import '../core/widgets/cinnabar_seal.dart';
import '../core/widgets/shichen_greeting_bar.dart';
import 'collection/views/collection_view.dart';
import 'explore/views/explore_view.dart';
import 'home/views/home_view.dart';
import 'pipeline/views/jenkins_pipeline_view.dart';
import 'shiju_view_model.dart';

/// 「拾句（ShiJu）」顶层视觉与导航容器
class ShiJuAppShell extends StatefulWidget {
  const ShiJuAppShell({
    super.key,
    required this.viewModel,
  });

  final ShiJuViewModel viewModel;

  @override
  State<ShiJuAppShell> createState() => _ShiJuAppShellState();
}

class _ShiJuAppShellState extends State<ShiJuAppShell> {
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    if (primary != null &&
        primary.context != null &&
        primary.context!.widget is EditableText) {
      return KeyEventResult.ignored;
    }
    if (widget.viewModel.activeTab != ShiJuNavTab.home) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.space) {
      widget.viewModel.roamRandomQuote();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.viewModel.nextQuote();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.viewModel.previousQuote();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (BuildContext context, _) {
        final TraditionalPalette palette = widget.viewModel.activePalette;
        final ShiJuNavTab activeTab = widget.viewModel.activeTab;

        return Focus(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: palette.background),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic,
            builder: (BuildContext context, Color? animatedBg, Widget? child) {
              final Color currentBg = animatedBg ?? palette.background;
              // 实时将系统/浏览器窗口标题栏颜色同步为当前渐变帧的传统色，彻底消除白边色差
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
                    // 顶部宋刻古籍书眉极简导航栏
                    _buildBookMarginHeader(context, palette, activeTab),

                    // 主体内容视图
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        child: switch (activeTab) {
                          ShiJuNavTab.home => HomeView(
                              key: const ValueKey<String>('nav_home'),
                              viewModel: widget.viewModel,
                            ),
                          ShiJuNavTab.explore => ExploreView(
                              key: const ValueKey<String>('nav_explore'),
                              viewModel: widget.viewModel,
                            ),
                          ShiJuNavTab.collection => CollectionView(
                              key: const ValueKey<String>('nav_collection'),
                              viewModel: widget.viewModel,
                            ),
                          ShiJuNavTab.pipeline => JenkinsPipelineView(
                              key: const ValueKey<String>('nav_pipeline'),
                              viewModel: widget.viewModel,
                            ),
                        },
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

  /// 宋刻书眉极简顶栏（大面积留白、无生硬按钮盒、朱砂底线点缀）
  Widget _buildBookMarginHeader(
    BuildContext context,
    TraditionalPalette palette,
    ShiJuNavTab activeTab,
  ) {
    final bool isVertical = widget.viewModel.isVerticalLayout;
    final bool isDark = widget.viewModel.isDarkMode;
    final int favCount = widget.viewModel.favoriteIds.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool isWide = constraints.maxWidth >= 700;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      // 书眉左栏：朱砂方印「拾句」 + 时辰导语
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            InkWell(
                              onTap: () => widget.viewModel
                                  .setActiveTab(ShiJuNavTab.home),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const CinnabarSeal(
                                      text: '拾句',
                                      style: SealStyle.yin,
                                      fontSize: 11.5,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 5.5,
                                        vertical: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Text(
                                      'ShiJu',
                                      style: AppTypography.attribution(
                                        palette.mutedText,
                                        fontSize: 12.5,
                                      ).copyWith(letterSpacing: 1.8),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isWide) ...<Widget>[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Container(
                                  width: 0.8,
                                  height: 13,
                                  color: palette.borderLine,
                                ),
                              ),
                              Expanded(
                                child: ShichenGreetingBar(palette: palette),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // 书眉右栏：极简墨字导航 + 竖排/夜间轻量开关
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          _buildMinimalNavTab(
                            key: const Key('nav_tab_home'),
                            label: '拾句',
                            isSelected: activeTab == ShiJuNavTab.home,
                            palette: palette,
                            onTap: () => widget.viewModel
                                .setActiveTab(ShiJuNavTab.home),
                          ),
                          const SizedBox(width: 18),
                          _buildMinimalNavTab(
                            key: const Key('nav_tab_explore'),
                            label: '寻章摘句',
                            isSelected: activeTab == ShiJuNavTab.explore,
                            palette: palette,
                            onTap: () => widget.viewModel
                                .setActiveTab(ShiJuNavTab.explore),
                          ),
                          const SizedBox(width: 18),
                          _buildMinimalNavTab(
                            key: const Key('nav_tab_collection'),
                            label: favCount > 0 ? '藏书阁·$favCount' : '藏书阁',
                            isSelected: activeTab == ShiJuNavTab.collection,
                            palette: palette,
                            onTap: () => widget.viewModel
                                .setActiveTab(ShiJuNavTab.collection),
                          ),
                          const SizedBox(width: 18),
                          _buildMinimalNavTab(
                            key: const Key('nav_tab_pipeline'),
                            label: '流水线',
                            isSelected: activeTab == ShiJuNavTab.pipeline,
                            palette: palette,
                            onTap: () => widget.viewModel
                                .setActiveTab(ShiJuNavTab.pipeline),
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Container(
                              width: 0.8,
                              height: 13,
                              color: palette.borderLine,
                            ),
                          ),

                          // 极简版式切换：竖排 / 横排
                          Tooltip(
                            message: isVertical
                                ? '当前：古籍竖排（点击切换为现代横排）'
                                : '当前：现代横排（点击切换为古籍竖排）',
                            child: InkWell(
                              key: const Key('toggle_layout_button'),
                              onTap: widget.viewModel.toggleVerticalLayout,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      isVertical
                                          ? Icons.vertical_distribute_rounded
                                          : Icons.format_align_center_rounded,
                                      size: 14,
                                      color: palette.themeAccent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isVertical ? '竖排' : '横排',
                                      style: AppTypography.label(
                                        palette.secondaryText,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // 极简双生配色切换：雾灰藕紫 / 奶雾蔷薇
                          Tooltip(
                            message: isDark ? '切换为奶雾蔷薇配色' : '切换为雾灰藕紫配色',
                            child: InkWell(
                              key: const Key('toggle_dark_mode_button'),
                              onTap: widget.viewModel.toggleDarkMode,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      isDark
                                          ? Icons.wb_sunny_outlined
                                          : Icons.nights_stay_outlined,
                                      size: 14,
                                      color: isDark
                                          ? TraditionalPalette.kNaiWuQiangWei
                                          : palette.secondaryText,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isDark ? '蔷薇' : '藕紫',
                                      style: AppTypography.label(
                                        palette.secondaryText,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (!isWide) ...<Widget>[
                    const SizedBox(height: 8),
                    ShichenGreetingBar(palette: palette),
                  ],

                  const SizedBox(height: 8),
                  // 古籍书眉极细乌丝横线
                  Container(
                    height: 0.6,
                    color: palette.borderLine,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 极简无边框文字导航项（选中时底部浮现一抹朱砂红笔触横线）
  Widget _buildMinimalNavTab({
    required Key key,
    required String label,
    required bool isSelected,
    required TraditionalPalette palette,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: AppTypography.label(
                isSelected ? palette.inkText : palette.mutedText,
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ).copyWith(letterSpacing: 1.4),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: isSelected ? 18 : 0,
              height: 2.0,
              decoration: BoxDecoration(
                color: isSelected ? palette.cinnabarRed : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
