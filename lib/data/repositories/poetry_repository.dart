import '../../domain/models/auth_user_model.dart';
import '../../domain/models/poem_model.dart';
import '../services/curated_poetry_data.dart';
import '../services/local_storage_service.dart';

/// 诗词与名家数据仓库（Single Source of Truth）
class PoetryRepository {
  PoetryRepository({LocalStorageService? storageService})
      : _storageService = storageService ?? LocalStorageService();

  final LocalStorageService _storageService;

  /// 获取全部精选诗词
  List<Poem> getAllPoems() => CuratedPoetryData.poems;

  /// 获取全部意境分类筛选标签
  List<String> getAllMoodTags() => CuratedPoetryData.allMoodTags;

  /// 根据诗词 ID 查询单首诗词
  Poem? getPoemById(String id) {
    for (final Poem poem in CuratedPoetryData.poems) {
      if (poem.id == id) {
        return poem;
      }
    }
    return null;
  }

  /// 根据作者 ID 查询作者详情
  Author? getAuthorById(String authorId) {
    return CuratedPoetryData.authors[authorId];
  }

  /// 查询某位作者收录的全部诗词（用于详情页作者卡片作品聚合）
  List<Poem> getPoemsByAuthor(String authorId) {
    return CuratedPoetryData.poems
        .where((Poem poem) => poem.authorId == authorId)
        .toList();
  }

  /// 按关键词（诗句、诗名、作者、朝代）与意境标签过滤诗词
  List<Poem> searchPoems({
    String query = '',
    String selectedTag = '全部',
  }) {
    final String normalizedQuery = query.trim().toLowerCase();
    return CuratedPoetryData.poems.where((Poem poem) {
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
          inParagraphs ||
          inTags;
    }).toList();
  }

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
}
