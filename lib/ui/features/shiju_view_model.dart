import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../data/repositories/poetry_repository.dart';
import '../../data/services/wechat_auth_service.dart';
import '../../domain/models/auth_user_model.dart';
import '../../domain/models/poem_model.dart';
import '../core/theme/traditional_palette.dart';

/// 顶部导航栏主视图枚举
enum ShiJuNavTab {
  /// 首页 · 名句卡片流
  home,

  /// 寻章摘句 · 探索与搜索
  explore,

  /// 我的藏书阁 · 收藏夹与阅读历史
  collection,
}

/// 「拾句（ShiJu）」核心状态管理 ViewModel
class ShiJuViewModel extends ChangeNotifier {
  ShiJuViewModel({
    PoetryRepository? repository,
    WeChatAuthService? authService,
  })  : _repository = repository ?? PoetryRepository(),
        _authService = authService ?? WeChatAuthService() {
    _poems = _repository.getAllPoems();
  }

  final PoetryRepository _repository;
  final WeChatAuthService _authService;
  final Random _random = Random();

  late final List<Poem> _poems;

  int _currentIndex = 0;
  bool _isVerticalLayout = true;
  bool _isDarkMode = false;
  ShiJuNavTab _activeTab = ShiJuNavTab.home;

  final List<String> _favoriteIds = <String>[];
  final List<String> _historyIds = <String>[];

  WeChatUser? _currentUser;
  bool _isSyncingCloud = false;

  String _searchQuery = '';
  String _selectedTag = '全部';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 微信扫码认证服务
  WeChatAuthService get authService => _authService;

  /// 当前已登录的微信雅士用户（未登录为 null）
  WeChatUser? get currentUser => _currentUser;

  /// 是否已通过微信扫码登录
  bool get isLoggedIn => _currentUser != null;

  /// 是否正在同步云端藏书阁
  bool get isSyncingCloud => _isSyncingCloud;

  /// 获取全部诗词
  List<Poem> get allPoems => _poems;

  /// 当前首页展示的诗词
  Poem get currentPoem => _poems[_currentIndex];

  /// 当前诗词序号（0-based）
  int get currentIndex => _currentIndex;

  /// 是否为古籍竖排模式（vertical-rl）
  bool get isVerticalLayout => _isVerticalLayout;

  /// 是否开启玄青夜间模式
  bool get isDarkMode => _isDarkMode;

  /// 当前激活的导航 Tab
  ShiJuNavTab get activeTab => _activeTab;

  /// 当前生效的中国传统色动态主题色板
  TraditionalPalette get activePalette => TraditionalPalette.resolve(
        currentPoem.paletteType,
        isDarkMode: _isDarkMode,
      );

  /// 根据指定诗词获取其对应的色板（支持详情页独立诗词展示）
  TraditionalPalette paletteForPoem(Poem poem) => TraditionalPalette.resolve(
        poem.paletteType,
        isDarkMode: _isDarkMode,
      );

  /// 收藏列表 ID 快照
  List<String> get favoriteIds => List<String>.unmodifiable(_favoriteIds);

  /// 阅读历史 ID 快照
  List<String> get historyIds => List<String>.unmodifiable(_historyIds);

  /// 已收藏的诗词实体列表
  List<Poem> get favoritePoems => _favoriteIds
      .map(_repository.getPoemById)
      .whereType<Poem>()
      .toList(growable: false);

  /// 阅读历史诗词实体列表
  List<Poem> get historyPoems => _historyIds
      .map(_repository.getPoemById)
      .whereType<Poem>()
      .toList(growable: false);

  /// 探索页全部意境标签
  List<String> get allMoodTags => _repository.getAllMoodTags();

  /// 当前搜索关键词
  String get searchQuery => _searchQuery;

  /// 当前选中的意境分类标签
  String get selectedTag => _selectedTag;

  /// 探索页实时过滤后的诗词列表
  List<Poem> get filteredPoems => _repository.searchPoems(
        query: _searchQuery,
        selectedTag: _selectedTag,
      );

  /// 初始化加载持久化数据（收藏列表、阅读历史、横竖排偏好、夜间模式、微信登录状态）
  Future<void> initialize() async {
    final List<String> savedFavorites = await _repository.loadFavoriteIds();
    final List<String> savedHistory = await _repository.loadHistoryIds();
    final bool savedVertical = await _repository.loadIsVerticalLayout();
    final bool savedDark = await _repository.loadIsDarkMode();
    final WeChatUser? savedUser = await _repository.loadAuthUser();

    _favoriteIds
      ..clear()
      ..addAll(savedFavorites);
    _historyIds
      ..clear()
      ..addAll(savedHistory);
    _isVerticalLayout = savedVertical;
    _isDarkMode = savedDark;
    _currentUser = savedUser;
    _isInitialized = true;

    // 默认将首屏诗词记入阅读历史
    await recordReadingHistory(currentPoem.id, notify: false);
    notifyListeners();
  }

  /// 完成微信扫码登录，保存雅士档案并合并云端藏书阁收藏
  Future<int> loginWithWeChat(
    WeChatUser user, {
    List<String> cloudFavorites = const <String>[],
  }) async {
    int mergedCount = 0;
    for (final String poemId in cloudFavorites.reversed) {
      if (_repository.getPoemById(poemId) != null &&
          !_favoriteIds.contains(poemId)) {
        _favoriteIds.insert(0, poemId);
        mergedCount++;
      }
    }

    final DateTime now = DateTime.now();
    _currentUser = user.copyWith(
      loginTime: now,
      lastSyncTime: now,
    );
    notifyListeners();

    if (mergedCount > 0) {
      await _repository.saveFavoriteIds(_favoriteIds);
    }
    await _repository.saveAuthUser(_currentUser);
    return mergedCount;
  }

  /// 修撰已登录雅士的名刺信息（雅号、斋号、专属朱砂闲章、头像传统色）
  Future<void> updateUserProfile({
    String? nickname,
    String? poeticTitle,
    String? sealText,
    PaletteType? avatarTheme,
  }) async {
    if (_currentUser == null) return;
    final String cleanNickname = (nickname ?? _currentUser!.nickname).trim();
    final String cleanTitle = (poeticTitle ?? _currentUser!.poeticTitle).trim();
    final String cleanSeal = (sealText ?? _currentUser!.sealText).trim();

    _currentUser = _currentUser!.copyWith(
      nickname: cleanNickname.isEmpty ? _currentUser!.nickname : cleanNickname,
      poeticTitle: cleanTitle.isEmpty ? _currentUser!.poeticTitle : cleanTitle,
      sealText: cleanSeal.isEmpty ? _currentUser!.sealText : cleanSeal,
      avatarTheme: avatarTheme ?? _currentUser!.avatarTheme,
      lastSyncTime: DateTime.now(),
    );
    notifyListeners();
    await _repository.saveAuthUser(_currentUser);
  }

  /// 手动触发藏书阁与漫游足迹云端同步
  Future<void> syncCloudCollection() async {
    if (_currentUser == null || _isSyncingCloud) return;
    _isSyncingCloud = true;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 360));
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(lastSyncTime: DateTime.now());
      await _repository.saveAuthUser(_currentUser);
    }
    _isSyncingCloud = false;
    notifyListeners();
  }

  /// 退出微信登录
  Future<void> logout() async {
    if (_currentUser == null) return;
    _currentUser = null;
    notifyListeners();
    await _repository.saveAuthUser(null);
  }

  /// 切换顶部导航 Tab
  void setActiveTab(ShiJuNavTab tab) {
    if (_activeTab == tab) return;
    _activeTab = tab;
    notifyListeners();
  }

  /// 一键切换「古籍竖排（vertical-rl）」与「现代横排居中」
  Future<void> toggleVerticalLayout() async {
    _isVerticalLayout = !_isVerticalLayout;
    notifyListeners();
    await _repository.saveIsVerticalLayout(_isVerticalLayout);
  }

  /// 切换「玄青夜间模式」与「中国传统色动态主题」
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _repository.saveIsDarkMode(_isDarkMode);
  }

  /// 下一句
  Future<void> nextQuote() async {
    _currentIndex = (_currentIndex + 1) % _poems.length;
    await recordReadingHistory(currentPoem.id, notify: false);
    notifyListeners();
  }

  /// 上一句
  Future<void> previousQuote() async {
    _currentIndex = (_currentIndex - 1 + _poems.length) % _poems.length;
    await recordReadingHistory(currentPoem.id, notify: false);
    notifyListeners();
  }

  /// 偶遇下一句（随机漫游，确保切换到不同于当前的一句）
  Future<void> roamRandomQuote() async {
    if (_poems.length <= 1) return;
    int nextIdx = _random.nextInt(_poems.length);
    if (nextIdx == _currentIndex) {
      nextIdx = (_currentIndex + 1 + _random.nextInt(_poems.length - 1)) %
          _poems.length;
    }
    _currentIndex = nextIdx;
    await recordReadingHistory(currentPoem.id, notify: false);
    notifyListeners();
  }

  /// 选中指定诗词作为当前诗词并记录阅读历史
  Future<void> selectPoem(Poem poem) async {
    final int idx = _poems.indexWhere((Poem p) => p.id == poem.id);
    if (idx != -1) {
      _currentIndex = idx;
    }
    await recordReadingHistory(poem.id, notify: false);
    notifyListeners();
  }

  /// 判断某首诗词是否已收藏
  bool isFavorite(String poemId) => _favoriteIds.contains(poemId);

  /// 收藏 / 取消收藏切换
  Future<bool> toggleFavorite(String poemId) async {
    final bool nowFavorited;
    if (_favoriteIds.contains(poemId)) {
      _favoriteIds.remove(poemId);
      nowFavorited = false;
    } else {
      _favoriteIds.insert(0, poemId);
      nowFavorited = true;
    }
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(lastSyncTime: DateTime.now());
    }
    notifyListeners();
    await _repository.saveFavoriteIds(_favoriteIds);
    if (_currentUser != null) {
      await _repository.saveAuthUser(_currentUser);
    }
    return nowFavorited;
  }

  /// 从藏书阁移除收藏
  Future<void> removeFavorite(String poemId) async {
    if (_favoriteIds.remove(poemId)) {
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(lastSyncTime: DateTime.now());
      }
      notifyListeners();
      await _repository.saveFavoriteIds(_favoriteIds);
      if (_currentUser != null) {
        await _repository.saveAuthUser(_currentUser);
      }
    }
  }

  /// 记录阅读历史（去重并置顶，最多保留 30 条）
  Future<void> recordReadingHistory(String poemId, {bool notify = true}) async {
    _historyIds.remove(poemId);
    _historyIds.insert(0, poemId);
    if (_historyIds.length > 30) {
      _historyIds.removeRange(30, _historyIds.length);
    }
    if (notify) {
      notifyListeners();
    }
    await _repository.saveHistoryIds(_historyIds);
  }

  /// 清空阅读历史
  Future<void> clearHistory() async {
    _historyIds.clear();
    notifyListeners();
    await _repository.saveHistoryIds(_historyIds);
  }

  /// 设置搜索关键词
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  /// 设置意境分类筛选标签
  void setSelectedTag(String tag) {
    if (_selectedTag == tag) return;
    _selectedTag = tag;
    notifyListeners();
  }

  /// 点击首页名句卡片上的意境标签时，直接跳转至探索页并筛选该标签
  void jumpToExploreWithTag(String tag) {
    _selectedTag = tag;
    _searchQuery = '';
    _activeTab = ShiJuNavTab.explore;
    notifyListeners();
  }

  /// 重置探索筛选条件
  void resetExploreFilters() {
    _searchQuery = '';
    _selectedTag = '全部';
    notifyListeners();
  }

  /// 获取作者详情
  Author? getAuthorForPoem(Poem poem) =>
      _repository.getAuthorById(poem.authorId);

  /// 获取同一作者收录的全部诗词
  List<Poem> getAuthorWorks(String authorId) =>
      _repository.getPoemsByAuthor(authorId);
}
