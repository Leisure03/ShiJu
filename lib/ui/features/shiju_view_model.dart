import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../data/repositories/poetry_repository.dart';
import '../../data/services/app_update_service.dart';
import '../../data/services/wechat_auth_service.dart';
import '../../domain/models/app_update_model.dart';
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
    AppUpdateService? updateService,
  })  : _repository = repository ?? PoetryRepository(),
        _authService = authService ?? WeChatAuthService(),
        _updateService = updateService ?? AppUpdateService() {
    _poems = _repository.getAllPoems();
  }

  final PoetryRepository _repository;
  final WeChatAuthService _authService;
  final AppUpdateService _updateService;
  final Random _random = Random();

  List<Poem> _poems = <Poem>[];

  int _currentIndex = 0;
  bool _isVerticalLayout = true;
  bool _isDarkMode = false;
  ShiJuNavTab _activeTab = ShiJuNavTab.home;

  final List<String> _favoriteIds = <String>[];
  final List<String> _historyIds = <String>[];

  WeChatUser? _currentUser;
  bool _isSyncingCloud = false;

  // 「诗泉 (poetry.palemoky.com)」37 万首云端古诗词数据库状态
  bool _isFetchingShiquanRandom = false;
  bool _isSearchingShiquan = false;
  ShiquanStats _shiquanStats = const ShiquanStats();
  List<Poem> _remoteSearchResults = <Poem>[];
  final Set<String> _loadingAuthorIds = <String>{};

  // Jenkins 自动更新 (OTA Auto-Update) 核心状态
  String _currentAppVersion = AppUpdateService.kDefaultAppVersion;
  int _currentBuildNumber = AppUpdateService.kDefaultBuildNumber;
  int? _ignoredBuildNumber;
  AppReleaseManifest? _latestManifest;
  AppUpdateStatus _updateStatus = AppUpdateStatus.idle;
  double _updateProgress = 0.0;
  String _updateStepLabel = '';
  bool _shouldShowUpdateDialog = false;

  String _searchQuery = '';
  String _selectedTag = '全部';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 微信扫码认证服务
  WeChatAuthService get authService => _authService;

  /// Jenkins 自动更新服务
  AppUpdateService get updateService => _updateService;

  /// 是否正在从「诗泉 API」随机采撷诗词
  bool get isFetchingShiquanRandom => _isFetchingShiquanRandom;

  /// 是否正在调用「诗泉 API」全文搜索
  bool get isSearchingShiquan => _isSearchingShiquan;

  /// 「诗泉 API」云端诗库统计数据（默认 371,313 首诗词 · 13,577 位诗人）
  ShiquanStats get shiquanStats => _shiquanStats;

  /// 本地已缓存的诗泉云端诗词数量
  int get cachedRemotePoemCount => _repository.cachedRemotePoems.length;

  /// 当前客户端已安装版本号（如 1.0.6）
  String get currentAppVersion => _currentAppVersion;

  /// 当前客户端已安装构建号（如 108）
  int get currentBuildNumber => _currentBuildNumber;

  /// 当前客户端完整展示版本（如 v1.0.6 (#108)）
  String get currentDisplayVersion =>
      'v${_currentAppVersion.split('+').first} (#$_currentBuildNumber)';

  /// 检测到的 Jenkins 最新版本发布清单
  AppReleaseManifest? get latestManifest => _latestManifest;

  /// 当前更新生命周期状态
  AppUpdateStatus get updateStatus => _updateStatus;

  /// 是否存在待更新的 Jenkins 新版本构建
  bool get hasAppUpdate =>
      _latestManifest != null &&
      _latestManifest!.isNewerThan(
        currentVersion: _currentAppVersion,
        currentBuildNumber: _currentBuildNumber,
      );

  /// 更新包下载与校验进度（0.0 ~ 1.0）
  double get updateProgress => _updateProgress;

  /// 当前更新步骤描述文本
  String get updateStepLabel => _updateStepLabel;

  /// 是否需要在界面上自动弹出「发现新版本」更新提示框
  bool get shouldShowUpdateDialog => _shouldShowUpdateDialog && hasAppUpdate;

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

  /// 探索页实时过滤后的诗词列表（融合本地过滤结果与当前「诗泉 API」在线搜索结果）
  List<Poem> get filteredPoems {
    final List<Poem> localMatches = _repository.searchPoems(
      query: _searchQuery,
      selectedTag: _selectedTag,
    );
    if (_remoteSearchResults.isEmpty || _searchQuery.trim().isEmpty) {
      return localMatches;
    }
    final List<Poem> combined = List<Poem>.of(localMatches);
    for (final Poem remote in _remoteSearchResults) {
      final bool matchesTag = _selectedTag.isEmpty ||
          _selectedTag == '全部' ||
          remote.tags.contains(_selectedTag);
      if (matchesTag && !combined.any((Poem p) => p.id == remote.id)) {
        combined.add(remote);
      }
    }
    return combined;
  }

  /// 初始化加载持久化数据（收藏列表、阅读历史、诗泉本地缓存库、横竖排偏好、夜间模式、微信登录状态与 Jenkins 自动更新检测）
  Future<void> initialize() async {
    await _repository.loadCachedRemotePoems();
    _poems = _repository.getAllPoems();

    final List<String> savedFavorites = await _repository.loadFavoriteIds();
    final List<String> savedHistory = await _repository.loadHistoryIds();
    final bool savedVertical = await _repository.loadIsVerticalLayout();
    final bool savedDark = await _repository.loadIsDarkMode();
    final WeChatUser? savedUser = await _repository.loadAuthUser();
    final String? savedVersion = await _repository.loadInstalledVersion();
    final int? savedBuildNum = await _repository.loadInstalledBuildNumber();
    final int? savedIgnoredBuild = await _repository.loadIgnoredBuildNumber();
    final AppReleaseManifest? savedPublishedManifest =
        await _repository.loadPublishedManifest();

    _favoriteIds
      ..clear()
      ..addAll(savedFavorites);
    _historyIds
      ..clear()
      ..addAll(savedHistory);
    _isVerticalLayout = savedVertical;
    _isDarkMode = savedDark;
    _currentUser = savedUser;

    if (savedVersion != null && savedVersion.isNotEmpty) {
      _currentAppVersion = savedVersion;
    }
    if (savedBuildNum != null && savedBuildNum > _currentBuildNumber) {
      _currentBuildNumber = savedBuildNum;
    }
    _ignoredBuildNumber = savedIgnoredBuild;
    if (savedPublishedManifest != null) {
      _latestManifest = savedPublishedManifest;
      if (hasAppUpdate &&
          (savedPublishedManifest.forceUpdate ||
              _ignoredBuildNumber != savedPublishedManifest.buildNumber)) {
        _updateStatus = AppUpdateStatus.updateAvailable;
        _shouldShowUpdateDialog = true;
      }
    }

    _isInitialized = true;

    // 默认将首屏诗词记入阅读历史
    await recordReadingHistory(currentPoem.id, notify: false);
    notifyListeners();

    // 异步拉取远端 dist/build-manifest.json 检查是否有 Jenkins 新构建版本
    unawaited(checkForAppUpdate());
    // 异步刷新诗泉云端统计信息
    unawaited(_refreshShiquanStats());
  }

  Future<void> _refreshShiquanStats() async {
    final ShiquanStats? remoteStats = await _repository.fetchShiquanStats();
    if (remoteStats != null) {
      _shiquanStats = remoteStats;
      notifyListeners();
    }
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
    if (poem.isRemote) {
      await _repository.registerRemotePoems(<Poem>[poem]);
      _poems = _repository.getAllPoems();
    }
    final int idx = _poems.indexWhere((Poem p) => p.id == poem.id);
    if (idx != -1) {
      _currentIndex = idx;
    }
    await recordReadingHistory(poem.id, notify: false);
    notifyListeners();
    unawaited(ensureAuthorPoemsLoaded(poem.authorId));
  }

  /// 从「诗泉 API (poetry.palemoky.com)」37 万首云库中随机采撷一首新诗并切换展示
  Future<Poem?> fetchRandomFromShiquan({
    String? author,
    String? dynasty,
    String? type,
    String? char,
  }) async {
    if (_isFetchingShiquanRandom) return null;
    _isFetchingShiquanRandom = true;
    notifyListeners();

    final Poem? remotePoem = await _repository.fetchRandomFromShiquan(
      author: author,
      dynasty: dynasty,
      type: type,
      char: char,
    );

    _isFetchingShiquanRandom = false;
    if (remotePoem != null) {
      _poems = _repository.getAllPoems();
      final int idx = _poems.indexWhere((Poem p) => p.id == remotePoem.id);
      if (idx != -1) {
        _currentIndex = idx;
      }
      await recordReadingHistory(remotePoem.id, notify: false);
      notifyListeners();
      unawaited(ensureAuthorPoemsLoaded(remotePoem.authorId));
      return remotePoem;
    }

    // 离线或触发频控时优雅降级为本地诗库随机漫游
    await roamRandomQuote();
    return null;
  }

  /// 调用「诗泉 API」云端全库检索并合并至探索页结果列表
  Future<List<Poem>> searchShiquanOnline({String? customQuery}) async {
    final String query = (customQuery ?? _searchQuery).trim();
    if (query.isEmpty) {
      _remoteSearchResults = <Poem>[];
      notifyListeners();
      return const <Poem>[];
    }

    _isSearchingShiquan = true;
    notifyListeners();

    final result = await _repository.searchShiquanOnline(query: query);
    _poems = _repository.getAllPoems();
    if (query == _searchQuery.trim()) {
      _remoteSearchResults = result.poems;
    }

    _isSearchingShiquan = false;
    notifyListeners();
    return result.poems;
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
      final Poem? targetPoem = _repository.getPoemById(poemId);
      if (targetPoem != null && targetPoem.isRemote) {
        await _repository.registerRemotePoems(<Poem>[targetPoem]);
        _poems = _repository.getAllPoems();
      }
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
    if (query.trim().isEmpty) {
      _remoteSearchResults = <Poem>[];
    }
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
    _remoteSearchResults = <Poem>[];
    _activeTab = ShiJuNavTab.explore;
    notifyListeners();
  }

  /// 重置探索筛选条件
  void resetExploreFilters() {
    _searchQuery = '';
    _selectedTag = '全部';
    _remoteSearchResults = <Poem>[];
    notifyListeners();
  }

  /// 获取作者详情
  Author? getAuthorForPoem(Poem poem) =>
      _repository.getAuthorById(poem.authorId);

  /// 获取同一作者已加载的全部诗词
  List<Poem> getAuthorWorks(String authorId) =>
      _repository.getPoemsByAuthor(authorId);

  /// 获取同一作者在诗泉全库中的收录总首数
  int getAuthorTotalPoemCount(String authorId) =>
      _repository.getAuthorTotalPoemCount(authorId);

  /// 判断某位作者是否正在从诗泉云端加载作品全集
  bool isLoadingAuthorPoems(String authorId) =>
      _loadingAuthorIds.contains(authorId);

  /// 判断某位作者是否还有更多诗泉云端分页尚未加载
  bool canLoadMoreAuthorPoems(String authorId) =>
      _repository.canLoadMoreAuthorPoems(authorId);

  /// 自动拉取某位作者在「诗泉 API」中的作品列表与全库收录总首数
  Future<void> ensureAuthorPoemsLoaded(String authorId) async {
    if (!_repository.shiquanApiService.enableNetwork) {
      return;
    }
    if (_loadingAuthorIds.contains(authorId) ||
        _repository.getAuthorLoadedPage(authorId) >= 1) {
      return;
    }

    _loadingAuthorIds.add(authorId);
    notifyListeners();

    try {
      await _repository.fetchAuthorPoemsFromShiquan(
        authorId,
        page: 1,
        pageSize: 100,
      );
    } finally {
      _loadingAuthorIds.remove(authorId);
      notifyListeners();
    }
  }

  /// 加载某位作者在「诗泉 API」中的下一页诗作
  Future<void> loadMoreAuthorPoems(String authorId) async {
    if (!_repository.shiquanApiService.enableNetwork ||
        _loadingAuthorIds.contains(authorId) ||
        !_repository.canLoadMoreAuthorPoems(authorId)) {
      return;
    }

    final int nextPage = _repository.getAuthorLoadedPage(authorId) + 1;
    _loadingAuthorIds.add(authorId);
    notifyListeners();

    try {
      await _repository.fetchAuthorPoemsFromShiquan(
        authorId,
        page: nextPage,
        pageSize: 100,
      );
    } finally {
      _loadingAuthorIds.remove(authorId);
      notifyListeners();
    }
  }

  // ===========================================================================
  // Jenkins 持续交付 · 客户端自动检测更新与一键热更新闭环
  // ===========================================================================

  /// 检查是否有 Jenkins 新打包发布的版本（启动时、切回前台时或手动点击时调用）
  Future<bool> checkForAppUpdate({
    bool manual = false,
    AppReleaseManifest? injectedManifest,
  }) async {
    if (_updateStatus == AppUpdateStatus.downloading) {
      return false;
    }

    if (manual) {
      _updateStatus = AppUpdateStatus.checking;
      notifyListeners();
    }

    AppReleaseManifest? candidate = injectedManifest;
    candidate ??= await _updateService.fetchRemoteManifest();

    final AppReleaseManifest? savedPublished =
        await _repository.loadPublishedManifest();
    if (savedPublished != null) {
      if (candidate == null ||
          savedPublished.buildNumber > candidate.buildNumber) {
        candidate = savedPublished;
      }
    }

    if (candidate != null) {
      if (_latestManifest == null ||
          candidate.buildNumber >= _latestManifest!.buildNumber) {
        _latestManifest = candidate;
      }
    }

    if (hasAppUpdate && _latestManifest != null) {
      _updateStatus = AppUpdateStatus.updateAvailable;
      final bool isIgnored = !manual &&
          !_latestManifest!.forceUpdate &&
          _ignoredBuildNumber == _latestManifest!.buildNumber;
      if (!isIgnored) {
        _shouldShowUpdateDialog = true;
      }
      notifyListeners();
      return true;
    }

    _updateStatus = AppUpdateStatus.upToDate;
    _shouldShowUpdateDialog = false;
    notifyListeners();
    return false;
  }

  /// 当 Jenkins 流水线完成打包归档后，发布最新构建清单并触发客户端更新感知
  Future<void> publishJenkinsBuildManifest(
    AppReleaseManifest manifest, {
    bool autoPopup = true,
  }) async {
    _latestManifest = manifest;
    await _repository.savePublishedManifest(manifest);

    if (hasAppUpdate) {
      _updateStatus = AppUpdateStatus.updateAvailable;
      if (autoPopup) {
        _ignoredBuildNumber = null;
        await _repository.saveIgnoredBuildNumber(null);
        _shouldShowUpdateDialog = true;
      }
    }
    notifyListeners();
  }

  /// 标记更新弹窗已被 UI 层消费弹出，防止重复叠加弹窗
  void acknowledgeUpdateDialogShown() {
    if (!_shouldShowUpdateDialog) return;
    _shouldShowUpdateDialog = false;
  }

  /// 主动唤起新版本更新弹窗
  void openUpdateDialog() {
    _latestManifest ??= AppUpdateService.createManifestForBuild(
      buildNumber: _currentBuildNumber + 1,
    );
    _updateStatus = AppUpdateStatus.updateAvailable;
    _shouldShowUpdateDialog = true;
    notifyListeners();
  }

  /// 用户点击「稍后提醒」关闭更新弹窗
  Future<void> dismissUpdateDialog({bool ignoreThisBuild = true}) async {
    _shouldShowUpdateDialog = false;
    if (ignoreThisBuild && _latestManifest != null) {
      _ignoredBuildNumber = _latestManifest!.buildNumber;
      await _repository.saveIgnoredBuildNumber(_ignoredBuildNumber);
    }
    notifyListeners();
  }

  /// 执行一键下载更新包、校验 SHA-256 指纹并完成客户端版本热更新升级
  Future<void> performAppUpdate() async {
    final AppReleaseManifest? target = _latestManifest;
    if (target == null || _updateStatus == AppUpdateStatus.downloading) {
      return;
    }

    _updateStatus = AppUpdateStatus.downloading;
    _updateProgress = 0.22;
    _updateStepLabel =
        '正在从 Jenkins 制品库拉取 ${target.primaryArtifact.path} (${target.primaryArtifact.formattedSize})...';
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 90));
    _updateProgress = 0.58;
    _updateStepLabel =
        '正在校验产物 SHA-256 签名 (${target.primaryArtifact.sha256.substring(0, 12)}...)...';
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 90));
    _updateProgress = 0.88;
    _updateStepLabel = 'SHA-256 校验通过，正在解压并热替换静态资源包...';
    notifyListeners();

    await _updateService.applyLauncherHotUpdate();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    _currentAppVersion = target.cleanSemver;
    _currentBuildNumber = target.buildNumber;
    _ignoredBuildNumber = null;
    _updateProgress = 1.0;
    _updateStepLabel = '已成功更新至 ${target.displayVersion}！';
    _updateStatus = AppUpdateStatus.completed;
    _shouldShowUpdateDialog = false;
    notifyListeners();

    await _repository.saveInstalledVersion(_currentAppVersion);
    await _repository.saveInstalledBuildNumber(_currentBuildNumber);
    await _repository.saveIgnoredBuildNumber(null);
  }
}
