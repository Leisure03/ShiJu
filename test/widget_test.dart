import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiju/data/repositories/poetry_repository.dart';
import 'package:shiju/data/services/local_storage_service.dart';
import 'package:shiju/data/services/storage_driver_stub.dart';
import 'package:shiju/main.dart';
import 'package:shiju/ui/core/theme/traditional_palette.dart';
import 'package:shiju/ui/core/widgets/shichen_greeting_bar.dart';
import 'package:shiju/ui/features/shiju_view_model.dart';

/// 内存模拟 StorageDriver，用于隔离测试 localStorage 持久化逻辑
class InMemoryStorageDriver implements StorageDriver {
  final Map<String, String> store = <String, String>{};

  @override
  Future<String?> getItem(String key) async => store[key];

  @override
  Future<void> setItem(String key, String value) async {
    store[key] = value;
  }
}

ShiJuViewModel _createTestViewModel({InMemoryStorageDriver? driver}) {
  final InMemoryStorageDriver storageDriver = driver ?? InMemoryStorageDriver();
  final LocalStorageService storageService =
      LocalStorageService(driver: storageDriver);
  final PoetryRepository repository =
      PoetryRepository(storageService: storageService);
  return ShiJuViewModel(repository: repository);
}

void main() {
  group('拾句 (ShiJu) 核心领域与工具测试', () {
    test('十二时辰计算器能准确映射古代时辰与应景导语', () {
      final ShichenInfo xuShi =
          ShichenInfo.fromDateTime(DateTime(2026, 9, 26, 20, 15));
      expect(xuShi.name, '戌时');
      expect(xuShi.alias, '夜阑');
      expect(xuShi.fullTitle, '戌时 · 夜阑');

      final ShichenInfo ziShi =
          ShichenInfo.fromDateTime(DateTime(2026, 9, 26, 23, 30));
      expect(ziShi.name, '子时');
      expect(ziShi.alias, '夜半');
    });

    test('奶雾蔷薇与雾灰藕紫双生色板解析准确', () {
      final TraditionalPalette dayPalette =
          TraditionalPalette.resolve(PaletteType.tianShuiBi);
      expect(dayPalette.name, '奶雾蔷薇');
      expect(dayPalette.background, const Color(0xFFF8CDED));
      expect(dayPalette.themeAccent, const Color(0xFFA198A8));

      final TraditionalPalette dark = TraditionalPalette.resolve(
        PaletteType.tianShuiBi,
        isDarkMode: true,
      );
      expect(dark.name, '雾灰藕紫');
      expect(dark.background, const Color(0xFFA198A8));
      expect(dark.inkText, const Color(0xFFF8CDED));
    });

    test('LocalStorageService 持久化保存收藏列表、阅读历史与横竖排偏好', () async {
      final InMemoryStorageDriver driver = InMemoryStorageDriver();
      final ShiJuViewModel vm1 = _createTestViewModel(driver: driver);
      await vm1.initialize();

      expect(vm1.isVerticalLayout, isTrue);
      await vm1.toggleVerticalLayout();
      expect(vm1.isVerticalLayout, isFalse);

      await vm1.toggleFavorite('poem_01');
      expect(vm1.isFavorite('poem_01'), isTrue);

      // 新建 ViewModel 实例验证从持久化存储恢复状态
      final ShiJuViewModel vm2 = _createTestViewModel(driver: driver);
      await vm2.initialize();
      expect(vm2.isVerticalLayout, isFalse);
      expect(vm2.isFavorite('poem_01'), isTrue);
      expect(vm2.historyIds, isNotEmpty);
    });
  });

  group('拾句 (ShiJu) UI 与三大模块交互测试', () {
    testWidgets('模块一：首页名句卡片展示、横竖排切换、漫游切换与空格快捷键', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ShiJuViewModel viewModel = _createTestViewModel();
      await viewModel.initialize();

      await tester.pumpWidget(ShiJuApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // 默认首篇为唐温如《题龙阳县青草湖》
      expect(viewModel.currentPoem.title, '题龙阳县青草湖');
      expect(find.text('今日拾句'), findsOneWidget);

      // 切换为现代横排居中，验证整句文本与出处渲染
      await tester.tap(find.byKey(const Key('toggle_layout_button')));
      await tester.pumpAndSettle();
      expect(viewModel.isVerticalLayout, isFalse);
      expect(find.text('醉后不知天在水，满船清梦压星河。'), findsOneWidget);
      expect(find.text('〔元〕唐温如 ·《题龙阳县青草湖》'), findsOneWidget);

      // 点击「下一句」切换至苏轼《水调歌头·明月几时有》
      await tester.tap(find.byKey(const Key('next_quote_button')));
      await tester.pumpAndSettle();
      expect(viewModel.currentPoem.title, '水调歌头·明月几时有');
      expect(find.text('但愿人长久，千里共婵娟。'), findsOneWidget);

      // 按空格键随机漫游到另一句
      final String beforeSpaceId = viewModel.currentPoem.id;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(viewModel.currentPoem.id, isNot(equals(beforeSpaceId)));
    });

    testWidgets('模块二：点击名句卡片展开详情页、名句朱砂高亮、赏析Tab切换与同作者作品聚合', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ShiJuViewModel viewModel = _createTestViewModel();
      await viewModel.initialize();
      // 切换至横排并定位到苏轼《水调歌头·明月几时有》（苏轼名下共收录 4 首作品）
      await viewModel.toggleVerticalLayout();
      await viewModel.nextQuote();

      await tester.pumpWidget(ShiJuApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(find.text('但愿人长久，千里共婵娟。'), findsOneWidget);

      // 点击名句卡片任意区域，平滑展开进入详情页
      await tester.tap(find.text('但愿人长久，千里共婵娟。'));
      await tester.pumpAndSettle();

      // 验证完整诗词正文展示且推荐名句被朱砂红高亮标记
      expect(find.text('全诗展卷'), findsOneWidget);
      expect(find.text('明月几时有？把酒问青天。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('highlighted_line_但愿人长久，千里共婵娟。')),
        findsOneWidget,
      );

      // 验证默认展示【译文与注释】Tab
      expect(find.text('诗意今译'), findsOneWidget);
      expect(find.text('字词典故逐条注释'), findsOneWidget);

      // 切换至【创作背景与赏析】Tab
      await tester.tap(find.byKey(const Key('detail_tab_1')));
      await tester.pumpAndSettle();
      expect(find.text('创作背景与生平境遇'), findsOneWidget);
      expect(find.text('东方审美深度鉴赏'), findsOneWidget);

      // 验证作者生平卡片及「查看该作者收录的全部诗词（共 4 首）」
      expect(find.text('查看该作者收录的全部诗词（共 4 首）'), findsOneWidget);
      expect(find.text('《定风波·莫听穿林打叶声》'), findsOneWidget);

      // 点击同作者的另一首作品《定风波·莫听穿林打叶声》，验证详情页内无缝切换
      await tester.ensureVisible(
        find.byKey(const Key('author_work_item_poem_03')),
      );
      await tester.tap(find.byKey(const Key('author_work_item_poem_03')));
      await tester.pumpAndSettle();

      expect(viewModel.currentPoem.title, '定风波·莫听穿林打叶声');
      expect(
        find.byKey(
          const ValueKey<String>('highlighted_line_回首向来萧瑟处，归去，也无风雨也无晴。'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('模块三：寻章摘句实时搜索、意境标签筛选、藏书阁收藏移除与诗笺海报弹窗', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ShiJuViewModel viewModel = _createTestViewModel();
      await viewModel.initialize();

      await tester.pumpWidget(ShiJuApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // 1. 在首页点击「生成诗笺海报」按钮，验证海报预览弹窗
      await tester.tap(find.byKey(const Key('home_poster_button')));
      await tester.pumpAndSettle();
      expect(find.text('诗笺预览'), findsOneWidget);
      expect(find.text('拾句珍藏'), findsOneWidget);
      expect(find.text('扫码拾句'), findsOneWidget);

      // 关闭海报弹窗
      await tester.tap(find.byTooltip('关闭海报预览'));
      await tester.pumpAndSettle();

      // 2. 在首页收藏当前诗词，并进入「藏书阁」验证
      await tester.tap(find.byKey(const Key('home_favorite_button')));
      await tester.pumpAndSettle();
      expect(viewModel.isFavorite('poem_01'), isTrue);

      await tester.tap(find.byKey(const Key('nav_tab_collection')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection_card_poem_01')), findsOneWidget);

      // 在藏书阁点击「移除收藏」
      await tester.tap(find.byKey(const Key('remove_favorite_poem_01')));
      await tester.pumpAndSettle();
      expect(viewModel.isFavorite('poem_01'), isFalse);

      // 3. 切换至「寻章摘句」探索页，验证意境分类标签筛选与关键词搜索
      await tester.tap(find.byKey(const Key('nav_tab_explore')));
      await tester.pumpAndSettle();

      // 点击 #星空 标签筛选
      await tester.tap(find.byKey(const Key('explore_tag_星空')));
      await tester.pumpAndSettle();
      expect(viewModel.selectedTag, '星空');
      expect(viewModel.filteredPoems.length, 4);

      // 输入关键词“唐温如”精确过滤
      await tester.enterText(
        find.byKey(const Key('explore_search_input')),
        '唐温如',
      );
      await tester.pumpAndSettle();
      expect(viewModel.filteredPoems.length, 1);
      expect(viewModel.filteredPoems.first.title, '题龙阳县青草湖');

      // 4. 验证雾灰藕紫反转模式一键切换
      await tester.tap(find.byKey(const Key('toggle_dark_mode_button')));
      await tester.pumpAndSettle();
      expect(viewModel.isDarkMode, isTrue);
      expect(viewModel.activePalette.name, '雾灰藕紫');
    });
  });
}
