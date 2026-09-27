import '../../domain/models/app_update_model.dart';
import '../../domain/models/auth_user_model.dart';
import '../../domain/models/poem_model.dart';
import '../services/classical_knowledge_service.dart';
import '../services/curated_poetry_data.dart';
import '../services/local_storage_service.dart';
import '../services/shiquan_api_service.dart';

/// 诗词与名家数据仓库（Single Source of Truth：融合内置精修善本 + 诗泉 37 万首云库 + 古典考据知识库 + 本地持久化缓存）
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

  /// 在线补充考据后的作者传记缓存
  final Map<String, Author> _enrichedAuthors = <String, Author>{};

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

  /// 根据诗词 ID 查询单首诗词（同时检索内置诗库与诗泉本地缓存库）
  Poem? getPoemById(String id) {
    for (final Poem poem in CuratedPoetryData.poems) {
      if (poem.id == id) {
        return poem;
      }
    }
    for (int i = 0; i < _remotePoems.length; i++) {
      if (_remotePoems[i].id == id) {
        final Poem upgraded =
            ClassicalKnowledgeService.upgradePoemIfNeeded(_remotePoems[i]);
        if (!identical(upgraded, _remotePoems[i])) {
          _remotePoems[i] = upgraded;
        }
        return _remotePoems[i];
      }
    }
    return null;
  }

  /// 根据作者 ID 查询作者详情（融合内置名家库、扩充历代诗人详传库与在线百科考据）
  Author? getAuthorById(String authorId, {Poem? fallbackPoem}) {
    if (_enrichedAuthors.containsKey(authorId)) {
      return _enrichedAuthors[authorId];
    }
    final Author? curatedAuthor = CuratedPoetryData.authors[authorId];
    if (curatedAuthor != null) {
      return curatedAuthor;
    }

    // 寻找关联诗词以提取作者姓名与朝代
    Poem? referencePoem = fallbackPoem;
    if (referencePoem == null) {
      for (final Poem poem in getAllPoems()) {
        if (poem.authorId == authorId) {
          referencePoem = poem;
          break;
        }
      }
    }
    if (referencePoem == null) {
      return null;
    }

    final List<Poem> works = getPoemsByAuthor(
      authorId,
      authorName: referencePoem.authorName,
    );
    return ClassicalKnowledgeService.resolveAuthor(
      authorId: authorId,
      authorName: referencePoem.authorName,
      dynasty: referencePoem.dynasty,
      authorPoems: works.isNotEmpty ? works : <Poem>[referencePoem],
    );
  }

  /// 查询某位作者收录的全部诗词（自动按 authorId 与 authorName 双向聚合内置与诗泉同作者作品）
  List<Poem> getPoemsByAuthor(String authorId, {String? authorName}) {
    String? resolvedName = authorName;
    if (resolvedName == null || resolvedName.isEmpty) {
      final Author? curated = CuratedPoetryData.authors[authorId];
      if (curated != null) {
        resolvedName = curated.name;
      } else {
        for (final Poem p in getAllPoems()) {
          if (p.authorId == authorId) {
            resolvedName = p.authorName;
            break;
          }
        }
      }
    }

    final List<Poem> result = <Poem>[];
    for (final Poem poem in getAllPoems()) {
      final bool sameId = poem.authorId == authorId;
      final bool sameName = resolvedName != null &&
          resolvedName.isNotEmpty &&
          poem.authorName == resolvedName;
      if ((sameId || sameName) && !result.any((Poem e) => e.id == poem.id)) {
        result.add(poem);
      }
    }
    return result;
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

  /// 初始化加载本地缓存的「诗泉 API」诗词，并自动将旧版简略模板热升级为深度考据内容
  Future<List<Poem>> loadCachedRemotePoems() async {
    final List<Poem> saved = await _storageService.getCachedRemotePoems();
    _remotePoems.clear();
    bool upgradedAny = false;
    for (final Poem poem in saved) {
      final bool inCurated =
          CuratedPoetryData.poems.any((Poem c) => c.id == poem.id);
      if (!inCurated && !_remotePoems.any((Poem r) => r.id == poem.id)) {
        final Poem upgraded =
            ClassicalKnowledgeService.upgradePoemIfNeeded(poem);
        if (!identical(upgraded, poem)) {
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

  /// 将「诗泉 API」返回的诗词注册至内存与本地持久化数据库（支持覆盖更新已增强的同 ID 诗词）
  Future<bool> registerRemotePoems(
    Iterable<Poem> poems, {
    bool persist = true,
    bool overwriteExisting = false,
  }) async {
    bool changed = false;
    for (final Poem rawPoem in poems) {
      final Poem poem = ClassicalKnowledgeService.upgradePoemIfNeeded(rawPoem);
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
      } else if (overwriteExisting ||
          ClassicalKnowledgeService.hasLegacyTemplateContent(
            _remotePoems[existingIdx],
          )) {
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

  /// 为当前查看的诗人自动从「诗泉 API」拉取更多同作者代表诗作，丰富作者作品聚合列表
  Future<List<Poem>> fetchMoreWorksForAuthor(
    Poem poem, {
    int minTargetCount = 4,
  }) async {
    final List<Poem> currentWorks = getPoemsByAuthor(
      poem.authorId,
      authorName: poem.authorName,
    );
    if (currentWorks.length >= minTargetCount ||
        !_shiquanApiService.enableNetwork) {
      return currentWorks;
    }

    final List<Poem> fetched = await _shiquanApiService.fetchPoemsByAuthor(
      poem.authorName,
      maxCount: 6,
    );
    if (fetched.isNotEmpty) {
      await registerRemotePoems(fetched);
    }
    return getPoemsByAuthor(poem.authorId, authorName: poem.authorName);
  }

  /// 在线调用公开百科或可选 AI 接口，深度增强指定诗词与诗人生平考据
  Future<Poem?> enrichPoemAndAuthorOnline(
    Poem poem, {
    String? customApiKey,
    String? customBaseUrl,
    String? customModel,
  }) async {
    if (!_shiquanApiService.enableNetwork &&
        (customApiKey == null || customApiKey.trim().isEmpty)) {
      return null;
    }

    // 1. 尝试在线补充生僻诗人的维基百科史料传记
    final Author? baseAuthor = getAuthorById(poem.authorId, fallbackPoem: poem);
    if (baseAuthor != null) {
      final Author? wikiAuthor =
          await ClassicalKnowledgeService.fetchAuthorBioFromWiki(
        baseAuthor: baseAuthor,
        authorPoems: getPoemsByAuthor(
          poem.authorId,
          authorName: poem.authorName,
        ),
        httpClient: _shiquanApiService.httpClient,
      );
      if (wikiAuthor != null) {
        _enrichedAuthors[poem.authorId] = wikiAuthor;
      }
    }

    // 2. 尝试通过 AI 或在线百科深化该诗的背景、译注与赏析
    if (poem.isRemote) {
      final Poem? enrichedPoem =
          await ClassicalKnowledgeService.enrichPoemOnline(
        poem: poem,
        customApiKey: customApiKey,
        customBaseUrl: customBaseUrl,
        customModel: customModel,
        httpClient: _shiquanApiService.httpClient,
      );
      if (enrichedPoem != null) {
        await registerRemotePoems(
          <Poem>[enrichedPoem],
          overwriteExisting: true,
        );
        return enrichedPoem;
      }
    }
    return null;
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
