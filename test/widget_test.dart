import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shiju/data/repositories/poetry_repository.dart';
import 'package:shiju/data/services/app_update_service.dart';
import 'package:shiju/data/services/local_storage_service.dart';
import 'package:shiju/data/services/shiquan_api_service.dart';
import 'package:shiju/data/services/storage_driver_stub.dart';
import 'package:shiju/domain/models/app_update_model.dart';
import 'package:shiju/domain/models/auth_user_model.dart';
import 'package:shiju/domain/models/poem_model.dart';
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

ShiJuViewModel _createTestViewModel({
  InMemoryStorageDriver? driver,
  AppUpdateService? updateService,
  ShiquanApiService? shiquanApiService,
}) {
  final InMemoryStorageDriver storageDriver = driver ?? InMemoryStorageDriver();
  final LocalStorageService storageService =
      LocalStorageService(driver: storageDriver);
  final PoetryRepository repository = PoetryRepository(
    storageService: storageService,
    shiquanApiService:
        shiquanApiService ?? ShiquanApiService(enableNetwork: false),
  );
  return ShiJuViewModel(
    repository: repository,
    updateService:
        updateService ?? AppUpdateService(enableNetworkProbe: false),
  );
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

    test('中国传统色色板解析与玄青夜间模式覆盖准确', () {
      final TraditionalPalette tianShui =
          TraditionalPalette.resolve(PaletteType.tianShuiBi);
      expect(tianShui.name, '天水碧');
      expect(tianShui.background, const Color(0xFFE2EEEB));
      expect(tianShui.themeAccent, const Color(0xFF2F6B66));

      final TraditionalPalette dark = TraditionalPalette.resolve(
        PaletteType.tianShuiBi,
        isDarkMode: true,
      );
      expect(dark.name, '玄青色');
      expect(dark.background, const Color(0xFF15191D));
      expect(dark.inkText, const Color(0xFFE8E4DC));
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

    test('微信扫码登录用户信息持久化保存、云端收藏合并与退出登录清理', () async {
      final InMemoryStorageDriver driver = InMemoryStorageDriver();
      final ShiJuViewModel vm1 = _createTestViewModel(driver: driver);
      await vm1.initialize();
      expect(vm1.isLoggedIn, isFalse);

      final WeChatPresetAccount preset = WeChatPresetAccount.presets[1];
      final int merged = await vm1.loginWithWeChat(
        preset.toWeChatUser(),
        cloudFavorites: preset.defaultFavorites,
      );
      expect(vm1.isLoggedIn, isTrue);
      expect(vm1.currentUser?.nickname, '松风煮茗');
      expect(merged, 2);
      expect(vm1.isFavorite('poem_02'), isTrue);

      // 重建 ViewModel 验证微信登录状态自动从持久化恢复
      final ShiJuViewModel vm2 = _createTestViewModel(driver: driver);
      await vm2.initialize();
      expect(vm2.isLoggedIn, isTrue);
      expect(vm2.currentUser?.nickname, '松风煮茗');
      expect(vm2.currentUser?.sealText, '清欢');

      // 退出登录验证清理
      await vm2.logout();
      expect(vm2.isLoggedIn, isFalse);
      final ShiJuViewModel vm3 = _createTestViewModel(driver: driver);
      await vm3.initialize();
      expect(vm3.isLoggedIn, isFalse);
    });
  });

  group('拾句 (ShiJu) UI 与四大模块交互测试', () {
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

      // 4. 验证玄青夜间模式一键切换
      await tester.tap(find.byKey(const Key('toggle_dark_mode_button')));
      await tester.pumpAndSettle();
      expect(viewModel.isDarkMode, isTrue);
      expect(viewModel.activePalette.name, '玄青色');
    });

    testWidgets('模块四：微信扫码登录弹窗、扫码确认与过期刷新流转、雅士名刺修撰与退出登录', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ShiJuViewModel viewModel = _createTestViewModel();
      await viewModel.initialize();

      await tester.pumpWidget(ShiJuApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // 1. 初始未登录，顶栏显示「微信登录」按钮
      expect(viewModel.isLoggedIn, isFalse);
      expect(find.text('微信登录'), findsOneWidget);

      // 2. 点击顶栏「微信登录」打开扫码弹窗
      await tester.tap(find.byKey(const Key('header_auth_button')));
      await tester.pumpAndSettle();
      expect(find.text('微信扫码登录'), findsOneWidget);
      expect(find.byKey(const Key('wechat_qr_code_box')), findsOneWidget);

      // 3. 验证二维码过期与刷新流转
      await tester.tap(find.byKey(const Key('simulate_expire_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qr_mask_expired')), findsOneWidget);
      expect(find.text('二维码已失效'), findsOneWidget);

      await tester.tap(find.byKey(const Key('qr_refresh_overlay_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qr_mask_expired')), findsNothing);

      // 4. 选择预设雅士「松风煮茗」并模拟手机微信扫码 -> 手机端确认登录
      await tester.tap(find.byKey(const Key('preset_account_wx_shiju_02')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('simulate_scan_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qr_mask_scanned')), findsOneWidget);
      expect(find.text('扫码成功'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm_wechat_login_button')));
      await tester.pumpAndSettle();

      // 5. 验证已登录状态、顶栏雅号展示与云端收藏合并
      expect(viewModel.isLoggedIn, isTrue);
      expect(viewModel.currentUser?.nickname, '松风煮茗');
      expect(find.text('松风煮茗'), findsOneWidget);
      expect(viewModel.favoriteIds.length, greaterThanOrEqualTo(2));

      // 6. 点击顶栏雅士头像打开「雅士名刺」，修撰雅号与专属闲章
      await tester.tap(find.byKey(const Key('header_auth_button')));
      await tester.pumpAndSettle();
      expect(find.text('雅士名刺'), findsOneWidget);
      expect(find.text('微信已绑定'), findsOneWidget);

      await tester.tap(find.byKey(const Key('toggle_edit_profile_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit_nickname_input')),
        '清溪散人',
      );
      await tester.enterText(
        find.byKey(const Key('edit_seal_input')),
        '听竹',
      );
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();

      expect(viewModel.currentUser?.nickname, '清溪散人');
      expect(viewModel.currentUser?.sealText, '听竹');

      // 7. 点击「退出微信登录」，验证恢复未登录状态
      await tester.tap(find.byKey(const Key('logout_wechat_button')));
      await tester.pumpAndSettle();
      expect(viewModel.isLoggedIn, isFalse);
      expect(find.text('微信登录'), findsOneWidget);
    });

    testWidgets('iPhone 17 (393x852) 竖屏视口下全页面响应式渲染无溢出', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ShiJuViewModel viewModel = _createTestViewModel();
      await viewModel.initialize();

      await tester.pumpWidget(ShiJuApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // 首页在 393px 下正常渲染
      expect(find.text('今日拾句'), findsOneWidget);

      // 切换横排并打开详情页
      await tester.tap(find.byKey(const Key('toggle_layout_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('醉后不知天在水，满船清梦压星河。'));
      await tester.pumpAndSettle();
      expect(find.text('全诗展卷'), findsOneWidget);

      // 返回首页，依次切换寻章摘句与藏书阁
      await tester.tap(find.text('返回拾句'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav_tab_explore')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('explore_search_input')), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav_tab_collection')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection_tab_favorites')), findsOneWidget);
    });

    testWidgets('顶部导航栏仅展示拾句、寻章摘句、藏书阁，不显示流水线入口', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1180, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ShiJuViewModel viewModel = _createTestViewModel();
      await viewModel.initialize();

      await tester.pumpWidget(ShiJuApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nav_tab_home')), findsOneWidget);
      expect(find.byKey(const Key('nav_tab_explore')), findsOneWidget);
      expect(find.byKey(const Key('nav_tab_collection')), findsOneWidget);
      expect(find.byKey(const Key('nav_tab_pipeline')), findsNothing);
      expect(find.text('流水线'), findsNothing);
    });

    testWidgets('模块六：Jenkins 打包发布新构建清单后，客户端再次进入自动弹出更新提示并完成一键升级', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1180, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final InMemoryStorageDriver driver = InMemoryStorageDriver();
      // 模拟 Jenkins 刚刚打包生成了 #109 构建清单 (v1.0.7+109)
      final AppReleaseManifest remoteBuild109 =
          AppUpdateService.createManifestForBuild(
        buildNumber: 109,
        gitBranch: 'jenkins_auto_update',
        gitCommit: '82c6df6',
      );
      final AppUpdateService mockUpdateService = AppUpdateService(
        enableNetworkProbe: false,
        customFetcher: () async => remoteBuild109,
      );

      final ShiJuViewModel viewModel = _createTestViewModel(
        driver: driver,
        updateService: mockUpdateService,
      );
      expect(viewModel.currentBuildNumber, 108);

      // 用户打开软件（initialize 自动拉取 build-manifest.json 并比对版本）
      await viewModel.initialize();
      await tester.pumpWidget(ShiJuApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // 1. 验证进入软件后自动弹出「发现新版本 · 拾句 (ShiJu)」对话框
      expect(find.byKey(const Key('app_auto_update_dialog')), findsOneWidget);
      expect(find.text('发现新版本 · 拾句 (ShiJu)'), findsOneWidget);
      expect(find.text('v1.0.7 (#109)'), findsOneWidget);

      // 2. 点击「立即更新」，验证自动完成下载、SHA-256 校验并升级至 #109
      await tester.tap(find.byKey(const Key('confirm_app_update_button')));
      await tester.pumpAndSettle();

      expect(viewModel.currentBuildNumber, 109);
      expect(viewModel.currentAppVersion, '1.0.7');
      expect(viewModel.hasAppUpdate, isFalse);
      expect(find.byKey(const Key('app_auto_update_dialog')), findsNothing);

      // 3. 模拟 Jenkins 再次打包生成 #110，用户手里的软件切回前台 (resumed) 时自动弹出 #110 更新窗
      final AppReleaseManifest remoteBuild110 =
          AppUpdateService.createManifestForBuild(buildNumber: 110);
      await viewModel.publishJenkinsBuildManifest(
        remoteBuild110,
        autoPopup: false,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('app_auto_update_dialog')), findsOneWidget);
      expect(find.text('v1.0.8 (#110)'), findsOneWidget);
    });

    testWidgets('模块七：接入「诗泉 API (poetry.palemoky.com)」随机采诗、全库搜索与本地持久化缓存', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1180, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final InMemoryStorageDriver driver = InMemoryStorageDriver();
      final MockClient mockHttpClient =
          MockClient((http.Request request) async {
        if (request.url.path == '/api/stats') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, dynamic>{
                'data': <String, dynamic>{
                  'poems': 371313,
                  'authors': 13577,
                  'dynasties': 11,
                  'types': 17,
                },
                'lang': 'zh-Hans',
              }),
            ),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
              'x-d1-bookmark': 'bookmark_001',
            },
          );
        }
        if (request.url.path == '/api/poems/random') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, dynamic>{
                'data': <String, dynamic>{
                  'id': 310281,
                  'title': '送族弟单父主簿凝',
                  'content': <String>[
                    '吾家青萍剑，操割有余闲。',
                    '鞍马月桥南，光辉岐路间。',
                  ],
                  'author': <String, dynamic>{'id': 2045, 'name': '李白'},
                  'dynasty': <String, dynamic>{'id': 6, 'name': '唐'},
                  'type': <String, dynamic>{'id': 13, 'name': '五言律诗'},
                },
                'lang': 'zh-Hans',
              }),
            ),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }
        if (request.url.path == '/api/search') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, dynamic>{
                'data': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 4949,
                    'title': '与充维那',
                    'content': <String>[
                      '机梭未动若为颜，一点虚灵入道环。',
                      '明月光中窥自己，白云影外到家山。',
                    ],
                    'author': <String, dynamic>{'id': 7312, 'name': '释正觉'},
                    'dynasty': <String, dynamic>{'id': 6, 'name': '唐'},
                    'type': <String, dynamic>{'id': 14, 'name': '七言律诗'},
                  },
                ],
                'pagination': <String, dynamic>{
                  'page': 1,
                  'pageSize': 12,
                  'hasMore': false,
                },
                'lang': 'zh-Hans',
              }),
            ),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }
        return http.Response('Not Found', 404);
      });

      final ShiquanApiService shiquanService = ShiquanApiService(
        httpClient: mockHttpClient,
        enableNetwork: true,
      );
      final ShiJuViewModel viewModel = _createTestViewModel(
        driver: driver,
        shiquanApiService: shiquanService,
      );
      await viewModel.initialize();

      await tester.pumpWidget(ShiJuApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // 1. 首页点击「诗泉采诗」按钮，从诗泉 API 随机采得李白《送族弟单父主簿凝》并切换展示
      await tester.tap(find.byKey(const Key('shiquan_random_button')));
      await tester.pumpAndSettle();

      expect(viewModel.currentPoem.id, 'shiquan_310281');
      expect(viewModel.currentPoem.title, '送族弟单父主簿凝');
      expect(viewModel.currentPoem.isRemote, isTrue);
      // 自动关联至内置名家李白 (li_bai)
      expect(viewModel.currentPoem.authorId, 'li_bai');
      expect(find.text('诗泉云卷'), findsOneWidget);

      // 2. 切换至「寻章摘句」探索页，输入本地不存在的关键词并点击「诗泉全库检索」
      await tester.tap(find.byKey(const Key('nav_tab_explore')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('explore_search_input')),
        '明月光中窥自己',
      );
      await tester.pumpAndSettle();
      expect(viewModel.filteredPoems, isEmpty);

      await tester.tap(find.byKey(const Key('empty_state_shiquan_search_button')));
      await tester.pumpAndSettle();

      expect(viewModel.filteredPoems.length, 1);
      final Poem searchedPoem = viewModel.filteredPoems.first;
      expect(searchedPoem.id, 'shiquan_4949');
      expect(searchedPoem.title, '与充维那');
      expect(searchedPoem.authorName, '释正觉');

      // 3. 验证诗泉云端诗词已持久化落盘至 LocalStorageService，重启 ViewModel 后仍可直接读取与生成诗人小传
      final ShiJuViewModel rebootedVm = _createTestViewModel(driver: driver);
      await rebootedVm.initialize();
      expect(rebootedVm.cachedRemotePoemCount, 2);
      final Author? dynamicAuthor = rebootedVm.getAuthorForPoem(searchedPoem);
      expect(dynamicAuthor, isNotNull);
      expect(dynamicAuthor!.name, '释正觉');
      expect(dynamicAuthor.courtesyName, contains('宏智'));
      expect(dynamicAuthor.biography, contains('曹洞宗'));
    });

    test('模块八：胡曾《咏史诗：颍川》及云端诗词深度考据、逐句起承转合鉴赏、典故注释与旧缓存热升级', () async {
      final Poem yingchuanPoem = ShiquanApiService.mapShiquanJsonToPoem(
        <String, dynamic>{
          'id': 365159,
          'title': '咏史诗：颍川',
          'content': <String>[
            '古贤高尚不争名，行止由来动杳冥。',
            '今日浪为千里客，看花惭上德星亭。',
          ],
          'author': <String, dynamic>{'id': 7944, 'name': '胡曾'},
          'dynasty': <String, dynamic>{'id': 6, 'name': '唐'},
          'type': <String, dynamic>{'id': 12, 'name': '七言绝句'},
        },
      );

      // 验证不再包含旧版空洞套话，而是包含详实史料考据与逐句起承转合剖析
      expect(yingchuanPoem.authorId, 'hu_zeng');
      expect(yingchuanPoem.background, contains('许由'));
      expect(yingchuanPoem.background, contains('陈寔'));
      expect(yingchuanPoem.background, contains('德星亭'));
      expect(yingchuanPoem.appreciation, contains('古贤高尚不争名'));
      expect(yingchuanPoem.appreciation, contains('行止由来动杳冥'));
      expect(yingchuanPoem.appreciation, contains('今日浪为千里客'));
      expect(yingchuanPoem.appreciation, contains('看花惭上德星亭'));
      expect(
        yingchuanPoem.annotations.any((PoemAnnotation a) => a.term == '德星亭'),
        isTrue,
      );

      final PoetryRepository repo = PoetryRepository(
        storageService: LocalStorageService(driver: InMemoryStorageDriver()),
        shiquanApiService: ShiquanApiService(enableNetwork: false),
      );
      await repo.registerRemotePoems(<Poem>[yingchuanPoem]);
      final Author? huZeng = repo.getAuthorById(
        yingchuanPoem.authorId,
        fallbackPoem: yingchuanPoem,
      );
      expect(huZeng, isNotNull);
      expect(huZeng!.name, '胡曾');
      expect(huZeng.courtesyName, contains('咸通'));
      expect(huZeng.biography, contains('一百五十首'));
      expect(huZeng.biography, isNot(contains('收录于开源古典文学工程「诗泉')));
    });
  });
}
