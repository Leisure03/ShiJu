import '../../domain/models/app_update_model.dart';
import '../../domain/models/auth_user_model.dart';
import '../../domain/models/poem_model.dart';
import '../services/curated_poetry_data.dart';
import '../services/local_storage_service.dart';
import '../services/shiquan_api_service.dart';

/// 诗词与名家数据仓库（Single Source of Truth：融合内置精修善本 + 诗泉 37 万首云库 + 本地持久化缓存）
class PoetryRepository {
  PoetryRepository({
    LocalStorageService? storageService,
    ShiquanApiService? shiquanApiService,
  })  : _storageService = storageService ?? LocalStorageService(),
        _shiquanApiService = shiquanApiService ?? ShiquanApiService();

  final LocalStorageService _storageService;
  final ShiquanApiService _shiquanApiService;

  /// 已从「诗泉 API」拉取并缓存在本地的诗词列表
  final List<Poem> _remotePoems = <Poem>[];

  /// 按作者 ID 聚合的诗泉云端诗作目录缓存（用于详情页展示该诗人全集列表）
  final Map<String, List<Poem>> _authorCatalogPoems = <String, List<Poem>>{};

  /// 作者 ID -> 诗泉全库收录诗词总数
  final Map<String, int> _authorTotalPoemCounts = <String, int>{};

  /// 作者 ID -> 当前已拉取的最大页码（pageSize=100）
  final Map<String, int> _authorLoadedPages = <String, int>{};

  /// 作者 ID -> 是否仍有更多分页可拉取
  final Map<String, bool> _authorHasMorePages = <String, bool>{};

  ShiquanApiService get shiquanApiService => _shiquanApiService;

  /// 获取全部诗词（内置 18 首名篇 + 已缓存的诗泉云端诗词）
  List<Poem> getAllPoems() => <Poem>[
        ...CuratedPoetryData.poems,
        ..._remotePoems,
      ];

  /// 获取已缓存在本地的诗泉云端诗词列表
  List<Poem> get cachedRemotePoems => List<Poem>.unmodifiable(_remotePoems);

  /// 获取全部意境分类筛选标签
  List<String> getAllMoodTags() => CuratedPoetryData.allMoodTags;

  /// 根据诗词 ID 查询单首诗词（同时检索内置诗库、诗泉本地缓存库与作者全集缓存）
  Poem? getPoemById(String id) {
    for (final Poem poem in CuratedPoetryData.poems) {
      if (poem.id == id) {
        return poem;
      }
    }
    for (final Poem poem in _remotePoems) {
      if (poem.id == id) {
        return poem;
      }
    }
    for (final List<Poem> works in _authorCatalogPoems.values) {
      for (final Poem poem in works) {
        if (poem.id == id) {
          return poem;
        }
      }
    }
    return null;
  }

  /// 根据作者 ID 查询作者详情（若为诗泉云端诗人，则自动结合其收录总数与代表作生成生平小传）
  Author? getAuthorById(String authorId) {
    final Author? curatedAuthor = CuratedPoetryData.authors[authorId];
    if (curatedAuthor != null) {
      return curatedAuthor;
    }
    final List<Poem> works = getPoemsByAuthor(authorId);
    if (works.isNotEmpty) {
      final Poem primary = works.first;
      final int totalCount = getAuthorTotalPoemCount(authorId);
      final List<String> repTitles = works
          .take(3)
          .map((Poem p) => '《${p.title}》')
          .toSet()
          .toList();
      final String repText = repTitles.join('、');
      final String countDesc =
          totalCount > 1 ? '（共收录诗作 $totalCount 首）' : '';
      final String lifeSpanText = totalCount > 1
          ? '${primary.dynasty}代名家 · 诗泉收录 $totalCount 首'
          : '${primary.dynasty}代名家';
      return Author(
        id: authorId,
        name: primary.authorName,
        dynasty: primary.dynasty,
        courtesyName: '诗泉古籍典藏诗人',
        lifeSpan: lifeSpanText,
        biography:
            '${primary.authorName}，${primary.dynasty}代诗人，其诗作收录于开源古典文学工程「诗泉（poetry.palemoky.com）」37 万首全库之中$countDesc。'
            '作品讲究声律格调与意象经营，代表作有$repText等，字里行间尽显${primary.dynasty}代文人雅士之精神风貌。',
      );
    }
    return null;
  }

  /// 查询某位作者已加载的全部诗词（自动合并内置名篇、本地漫游缓存与诗泉作者全集目录，去重保序）
  List<Poem> getPoemsByAuthor(String authorId) {
    final Map<String, Poem> merged = <String, Poem>{};
    for (final Poem poem in CuratedPoetryData.poems) {
      if (poem.authorId == authorId) {
        merged[poem.id] = poem;
      }
    }
    for (final Poem poem in _remotePoems) {
      if (poem.authorId == authorId) {
        merged[poem.id] = poem;
      }
    }
    final List<Poem>? catalog = _authorCatalogPoems[authorId];
    if (catalog != null) {
      for (final Poem poem in catalog) {
        merged.putIfAbsent(poem.id, () => poem);
      }
    }
    return merged.values.toList();
  }

  /// 获取某位作者在诗泉全库中的收录总首数（若尚未拉取云端数据或处于离线测试模式，则返回本地已加载首数）
  int getAuthorTotalPoemCount(String authorId) {
    final int loadedCount = getPoemsByAuthor(authorId).length;
    final int? remoteTotal = _authorTotalPoemCounts[authorId];
    if (remoteTotal != null && remoteTotal > loadedCount) {
      return remoteTotal;
    }
    if (_shiquanApiService.enableNetwork &&
        authorId.startsWith('shiquan_author_')) {
      final int? numericId =
          ShiquanApiService.resolveShiquanAuthorNumericId(authorId);
      if (numericId != null) {
        final int? presetTotal =
            ShiquanApiService.knownAuthorTotalCountByNumericId[numericId];
        if (presetTotal != null && presetTotal > loadedCount) {
          return presetTotal;
        }
      }
    }
    return loadedCount;
  }

  /// 判断某位作者是否还有更多诗泉云端分页尚未加载
  bool canLoadMoreAuthorPoems(String authorId) {
    return _authorHasMorePages[authorId] ?? false;
  }

  /// 获取某位作者当前已加载的诗泉云端分页页码
  int getAuthorLoadedPage(String authorId) {
    return _authorLoadedPages[authorId] ?? 0;
  }

  /// 从「诗泉 API」拉取指定作者的诗作列表与全库收录总首数（`/api/poems?authorId=...`）
  Future<ShiquanAuthorPoemsResult?> fetchAuthorPoemsFromShiquan(
    String authorId, {
    int page = 1,
    int pageSize = 100,
  }) async {
    final ShiquanAuthorPoemsResult? result =
        await _shiquanApiService.fetchAuthorPoems(
      authorId: authorId,
      page: page,
      pageSize: pageSize,
    );
    if (result == null) {
      return null;
    }

    final List<Poem> list =
        _authorCatalogPoems.putIfAbsent(authorId, () => <Poem>[]);
    for (final Poem poem in result.poems) {
      final bool inCurated =
          CuratedPoetryData.poems.any((Poem c) => c.id == poem.id);
      if (!inCurated && !list.any((Poem p) => p.id == poem.id)) {
        list.add(poem);
      }
    }

    final int loadedCount = getPoemsByAuthor(authorId).length;
    final int resolvedTotal =
        result.totalCount >= loadedCount ? result.totalCount : loadedCount;
    _authorTotalPoemCounts[authorId] = resolvedTotal;
    _authorLoadedPages[authorId] = page;
    _authorHasMorePages[authorId] = result.hasMore;

    return ShiquanAuthorPoemsResult(
      poems: result.poems,
      totalCount: resolvedTotal,
      page: result.page,
      pageSize: result.pageSize,
      hasMore: result.hasMore,
    );
  }

  /// 按关键词（诗句、诗名、作者、朝代、体裁）与意境标签过滤本地已收录/缓存的诗词
  List<Poem> searchPoems({
    String query = '',
    String selectedTag = '全部',
  }) {
    final String normalizedQuery = query.trim().toLowerCase();
    return getAllPoems().where((Poem poem) {
      final bool matchesTag = selectedTag.isEmpty ||
          selectedTag == '全部' ||
          poem.tags.contains(selectedTag);
      if (!matchesTag) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      final bool inQuote =
          poem.featuredQuote.toLowerCase().contains(normalizedQuery);
      final bool inTitle = poem.title.toLowerCase().contains(normalizedQuery);
      final bool inAuthor =
          poem.authorName.toLowerCase().contains(normalizedQuery);
      final bool inDynasty =
          poem.dynasty.toLowerCase().contains(normalizedQuery);
      final bool inGenre =
          (poem.genre ?? '').toLowerCase().contains(normalizedQuery);
      final bool inParagraphs = poem.paragraphs.any(
        (String line) => line.toLowerCase().contains(normalizedQuery),
      );
      final bool inTags = poem.tags.any(
        (String tag) => tag.toLowerCase().contains(normalizedQuery),
      );
      return inQuote ||
          inTitle ||
          inAuthor ||
          inDynasty ||
          inGenre ||
          inParagraphs ||
          inTags;
    }).toList();
  }

  /// 初始化加载本地缓存的「诗泉 API」诗词（若旧缓存仍为导读模板译文则自动升级为完整逐句白话今译）
  Future<List<Poem>> loadCachedRemotePoems() async {
    final List<Poem> saved = await _storageService.getCachedRemotePoems();
    _remotePoems.clear();
    bool upgradedAny = false;
    for (final Poem poem in saved) {
      final bool inCurated =
          CuratedPoetryData.poems.any((Poem c) => c.id == poem.id);
      if (!inCurated && !_remotePoems.any((Poem r) => r.id == poem.id)) {
        final Poem upgraded = ShiquanApiService.upgradeRemotePoemIfNeeded(poem);
        if (upgraded.translation != poem.translation ||
            upgraded.annotations.length != poem.annotations.length) {
          upgradedAny = true;
        }
        _remotePoems.add(upgraded);
      }
    }
    if (upgradedAny) {
      await _storageService.saveCachedRemotePoems(_remotePoems);
    }
    return List<Poem>.unmodifiable(_remotePoems);
  }

  /// 将「诗泉 API」返回的诗词注册至内存与本地持久化数据库
  Future<bool> registerRemotePoems(
    Iterable<Poem> poems, {
    bool persist = true,
  }) async {
    bool changed = false;
    for (final Poem rawPoem in poems) {
      final Poem poem = ShiquanApiService.upgradeRemotePoemIfNeeded(rawPoem);
      final bool inCurated =
          CuratedPoetryData.poems.any((Poem c) => c.id == poem.id);
      if (inCurated) {
        continue;
      }
      final int existingIdx =
          _remotePoems.indexWhere((Poem r) => r.id == poem.id);
      if (existingIdx == -1) {
        _remotePoems.add(poem);
        changed = true;
      } else if (_remotePoems[existingIdx].translation != poem.translation) {
        _remotePoems[existingIdx] = poem;
        changed = true;
      }
    }
    if (changed && _remotePoems.length > 160) {
      _remotePoems.removeRange(0, _remotePoems.length - 160);
    }
    if (changed && persist) {
      await _storageService.saveCachedRemotePoems(_remotePoems);
    }
    return changed;
  }

  /// 从「诗泉 API」随机采撷一首古诗词并自动落盘缓存
  Future<Poem?> fetchRandomFromShiquan({
    String? author,
    String? dynasty,
    String? type,
    String? char,
  }) async {
    final Poem? poem = await _shiquanApiService.fetchRandomPoem(
      author: author,
      dynasty: dynasty,
      type: type,
      char: char,
    );
    if (poem != null) {
      await registerRemotePoems(<Poem>[poem]);
    }
    return poem;
  }

  /// 调用「诗泉 API」在线全文检索并自动将检索结果注册至本地缓存
  Future<ShiquanSearchResult> searchShiquanOnline({
    required String query,
    int page = 1,
    int pageSize = 12,
  }) async {
    final ShiquanSearchResult result = await _shiquanApiService.searchPoems(
      query: query,
      page: page,
      pageSize: pageSize,
    );
    if (result.poems.isNotEmpty) {
      await registerRemotePoems(result.poems);
    }
    return result;
  }

  /// 获取「诗泉 API」云端诗库统计数据
  Future<ShiquanStats?> fetchShiquanStats() => _shiquanApiService.fetchStats();

  Future<List<String>> loadFavoriteIds() => _storageService.getFavoriteIds();

  Future<void> saveFavoriteIds(List<String> ids) =>
      _storageService.saveFavoriteIds(ids);

  Future<List<String>> loadHistoryIds() => _storageService.getHistoryIds();

  Future<void> saveHistoryIds(List<String> ids) =>
      _storageService.saveHistoryIds(ids);

  Future<bool> loadIsVerticalLayout() =>
      _storageService.getIsVerticalLayout(defaultValue: true);

  Future<void> saveIsVerticalLayout(bool isVertical) =>
      _storageService.saveIsVerticalLayout(isVertical);

  Future<bool> loadIsDarkMode() =>
      _storageService.getIsDarkMode(defaultValue: false);

  Future<void> saveIsDarkMode(bool isDark) =>
      _storageService.saveIsDarkMode(isDark);

  Future<WeChatUser?> loadAuthUser() => _storageService.getAuthUser();

  Future<void> saveAuthUser(WeChatUser? user) =>
      _storageService.saveAuthUser(user);

  Future<String?> loadInstalledVersion() =>
      _storageService.getInstalledVersion();

  Future<void> saveInstalledVersion(String version) =>
      _storageService.saveInstalledVersion(version);

  Future<int?> loadInstalledBuildNumber() =>
      _storageService.getInstalledBuildNumber();

  Future<void> saveInstalledBuildNumber(int buildNumber) =>
      _storageService.saveInstalledBuildNumber(buildNumber);

  Future<int?> loadIgnoredBuildNumber() =>
      _storageService.getIgnoredBuildNumber();

  Future<void> saveIgnoredBuildNumber(int? buildNumber) =>
      _storageService.saveIgnoredBuildNumber(buildNumber);

  Future<AppReleaseManifest?> loadPublishedManifest() =>
      _storageService.getPublishedManifest();

  Future<void> savePublishedManifest(AppReleaseManifest? manifest) =>
      _storageService.savePublishedManifest(manifest);
}
