import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/poem_model.dart';
import '../../ui/core/theme/traditional_palette.dart';
import 'classical_knowledge_service.dart';
import 'curated_poetry_data.dart';

/// 诗泉搜索分页结果封装
@immutable
class ShiquanSearchResult {
  const ShiquanSearchResult({
    required this.poems,
    this.page = 1,
    this.pageSize = 12,
    this.hasMore = false,
  });

  final List<Poem> poems;
  final int page;
  final int pageSize;
  final bool hasMore;
}

/// 「诗泉（https://poetry.palemoky.com）」开源古诗词 API 客户端服务
///
/// 收录唐诗、宋词、元曲、诗经、楚辞等 37 万余首古典诗词、1.3 万余位诗人。
/// 支持：
/// - `/api/poems/random`：随机推荐诗词（支持按作者、朝代、体裁、飞花令单字筛选）
/// - `/api/search`：全文搜索诗词（支持分页）
/// - `/api/stats`：获取云端诗库统计数据
class ShiquanApiService {
  ShiquanApiService({
    this.baseUrl = kDefaultBaseUrl,
    this.httpClient,
    this.enableNetwork = true,
    this.requestTimeout = const Duration(seconds: 6),
  });

  /// 默认诗泉 API 根地址（支持通过 --dart-define=SHIQUAN_API_URL 覆盖）
  static const String kDefaultBaseUrl = String.fromEnvironment(
    'SHIQUAN_API_URL',
    defaultValue: 'https://poetry.palemoky.com',
  );

  final String baseUrl;
  final http.Client? httpClient;
  final bool enableNetwork;
  final Duration requestTimeout;

  /// Cloudflare D1 会话一致性书签（透传 x-d1-bookmark 响应头）
  String? _d1Bookmark;

  /// 内置名家姓名到 authorId 的映射表，使诗泉返回的同作者作品自动关联至内置名家小传
  static const Map<String, String> _knownAuthorNameMap = <String, String>{
    '唐温如': 'tang_wenru',
    '唐珙': 'tang_wenru',
    '苏轼': 'su_shi',
    '李白': 'li_bai',
    '王维': 'wang_wei',
    '李清照': 'li_qingzhao',
    '辛弃疾': 'xin_qiji',
    '张若虚': 'zhang_ruoxu',
    '王勃': 'wang_bo',
    '纳兰性德': 'nalan_xingde',
  };

  Map<String, String> _buildHeaders() {
    final Map<String, String> headers = <String, String>{
      'accept': 'application/json',
    };
    if (_d1Bookmark != null && _d1Bookmark!.isNotEmpty) {
      headers['x-d1-bookmark'] = _d1Bookmark!;
    }
    return headers;
  }

  void _syncBookmark(http.Response response) {
    final String? nextBookmark = response.headers['x-d1-bookmark'];
    if (nextBookmark != null && nextBookmark.isNotEmpty) {
      _d1Bookmark = nextBookmark;
    }
  }

  Uri _buildUri(String path, Map<String, String> queryParameters) {
    final String cleanBase = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final String cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$cleanBase$cleanPath')
        .replace(queryParameters: queryParameters);
  }

  /// 从「诗泉 API」随机抽取一首古诗词（`/api/poems/random`）
  Future<Poem?> fetchRandomPoem({
    String? author,
    String? dynasty,
    String? type,
    String? char,
    String lang = 'zh-Hans',
  }) async {
    if (!enableNetwork) {
      return null;
    }

    final Map<String, String> queryParams = <String, String>{
      'lang': lang,
    };
    if (author != null && author.trim().isNotEmpty) {
      queryParams['author'] = author.trim();
    }
    if (dynasty != null && dynasty.trim().isNotEmpty) {
      queryParams['dynasty'] = dynasty.trim();
    }
    if (type != null && type.trim().isNotEmpty) {
      queryParams['type'] = type.trim();
    }
    if (char != null && char.trim().isNotEmpty) {
      queryParams['char'] = char.trim();
    }

    final http.Client client = httpClient ?? http.Client();
    try {
      final Uri uri = _buildUri('/api/poems/random', queryParams);
      final http.Response response = await client
          .get(uri, headers: _buildHeaders())
          .timeout(requestTimeout);
      _syncBookmark(response);

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final String bodyText =
            utf8.decode(response.bodyBytes, allowMalformed: true);
        final Object? decoded = jsonDecode(bodyText);
        if (decoded is Map<String, dynamic>) {
          final Object? data = decoded['data'];
          if (data is Map<String, dynamic>) {
            return mapShiquanJsonToPoem(data);
          }
        }
      }
    } catch (e) {
      debugPrint('ShiquanApiService.fetchRandomPoem error: $e');
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
    return null;
  }

  /// 调用「诗泉 API」全文搜索诗词（`/api/search`）
  Future<ShiquanSearchResult> searchPoems({
    required String query,
    int page = 1,
    int pageSize = 12,
    String lang = 'zh-Hans',
  }) async {
    final String trimmed = query.trim();
    if (!enableNetwork || trimmed.isEmpty) {
      return const ShiquanSearchResult(poems: <Poem>[]);
    }

    final Map<String, String> queryParams = <String, String>{
      'q': trimmed,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      'lang': lang,
    };

    final http.Client client = httpClient ?? http.Client();
    try {
      final Uri uri = _buildUri('/api/search', queryParams);
      final http.Response response = await client
          .get(uri, headers: _buildHeaders())
          .timeout(requestTimeout);
      _syncBookmark(response);

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final String bodyText =
            utf8.decode(response.bodyBytes, allowMalformed: true);
        final Object? decoded = jsonDecode(bodyText);
        if (decoded is Map<String, dynamic>) {
          final List<Poem> parsedPoems = <Poem>[];
          final Object? data = decoded['data'];
          if (data is List<dynamic>) {
            for (final Object? item in data) {
              if (item is Map<String, dynamic>) {
                parsedPoems.add(mapShiquanJsonToPoem(item));
              }
            }
          }
          bool hasMore = false;
          if (decoded['pagination'] is Map<String, dynamic>) {
            final Map<String, dynamic> pag =
                decoded['pagination'] as Map<String, dynamic>;
            hasMore = (pag['hasMore'] as bool?) ?? false;
          }
          return ShiquanSearchResult(
            poems: parsedPoems,
            page: page,
            pageSize: pageSize,
            hasMore: hasMore,
          );
        }
      }
    } catch (e) {
      debugPrint('ShiquanApiService.searchPoems error: $e');
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
    return const ShiquanSearchResult(poems: <Poem>[]);
  }

  /// 获取「诗泉 API」云端收录统计（`/api/stats`）
  Future<ShiquanStats?> fetchStats({String lang = 'zh-Hans'}) async {
    if (!enableNetwork) {
      return null;
    }

    final http.Client client = httpClient ?? http.Client();
    try {
      final Uri uri = _buildUri('/api/stats', <String, String>{'lang': lang});
      final http.Response response = await client
          .get(uri, headers: _buildHeaders())
          .timeout(requestTimeout);
      _syncBookmark(response);

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final String bodyText =
            utf8.decode(response.bodyBytes, allowMalformed: true);
        final Object? decoded = jsonDecode(bodyText);
        if (decoded is Map<String, dynamic>) {
          return ShiquanStats.fromJson(decoded);
        }
      }
    } catch (e) {
      debugPrint('ShiquanApiService.fetchStats error: $e');
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
    return null;
  }

  /// 拉取指定诗人的多首代表诗词（用于详情页作者作品聚合，避免仅显示单首作品）
  Future<List<Poem>> fetchPoemsByAuthor(
    String authorName, {
    int maxCount = 6,
    String lang = 'zh-Hans',
  }) async {
    final String cleanAuthor = authorName.trim();
    if (!enableNetwork || cleanAuthor.isEmpty || cleanAuthor == '佚名') {
      return const <Poem>[];
    }

    final List<Poem> collected = <Poem>[];
    // 1. 先通过 searchPoems 检索该作者名下的作品
    final ShiquanSearchResult searchRes = await searchPoems(
      query: cleanAuthor,
      page: 1,
      pageSize: 12,
      lang: lang,
    );
    for (final Poem p in searchRes.poems) {
      if (p.authorName == cleanAuthor &&
          !collected.any((Poem e) => e.id == p.id || e.title == p.title)) {
        collected.add(p);
        if (collected.length >= maxCount) {
          return collected;
        }
      }
    }

    // 2. 若搜索结果不足，补充调用按作者随机抽取接口
    for (int i = 0; i < 2 && collected.length < maxCount; i++) {
      final Poem? randomWork = await fetchRandomPoem(
        author: cleanAuthor,
        lang: lang,
      );
      if (randomWork != null &&
          randomWork.authorName == cleanAuthor &&
          !collected.any(
            (Poem e) => e.id == randomWork.id || e.title == randomWork.title,
          )) {
        collected.add(randomWork);
      }
    }
    return collected;
  }

  /// 将「诗泉 API」返回的单首诗词 JSON 转换为领域模型 [Poem]，
  /// 自动提炼代表名句、推断意境标签、匹配中国传统色主题，并生成深度考据、逐联赏析与训诂注释。
  static Poem mapShiquanJsonToPoem(Map<String, dynamic> raw) {
    final Object? rawId = raw['id'];
    final int numericId =
        rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0;
    final String poemId =
        numericId > 0 ? 'shiquan_$numericId' : 'shiquan_${raw.hashCode.abs()}';

    final String rawTitle = ((raw['title'] as String?) ?? '无题')
        .replaceAll(RegExp(r'\s+'), ' · ')
        .trim();
    final String title = rawTitle.isEmpty ? '无题' : rawTitle;

    // 解析作者
    String authorName = '佚名';
    int authorNumericId = 0;
    if (raw['author'] is Map<String, dynamic>) {
      final Map<String, dynamic> authorMap =
          raw['author'] as Map<String, dynamic>;
      authorName = ((authorMap['name'] as String?) ?? '佚名').trim();
      final Object? aid = authorMap['id'];
      authorNumericId = aid is num ? aid.toInt() : int.tryParse('$aid') ?? 0;
    } else if (raw['author'] is String) {
      authorName = (raw['author'] as String).trim();
    }
    if (authorName.isEmpty) {
      authorName = '佚名';
    }

    final String authorId =
        ClassicalKnowledgeService.resolveKnownAuthorId(authorName) ??
            _knownAuthorNameMap[authorName] ??
            (authorNumericId > 0
                ? 'shiquan_author_$authorNumericId'
                : 'shiquan_author_${authorName.hashCode.abs()}');

    // 解析朝代
    String dynasty = '唐';
    if (raw['dynasty'] is Map<String, dynamic>) {
      final Map<String, dynamic> dynastyMap =
          raw['dynasty'] as Map<String, dynamic>;
      dynasty = ((dynastyMap['name'] as String?) ?? '唐').trim();
    } else if (raw['dynasty'] is String) {
      dynasty = (raw['dynasty'] as String).trim();
    }
    if (dynasty.isEmpty || dynasty == '其他') {
      dynasty = '古典';
    }

    // 解析诗句段落
    final List<String> paragraphs = <String>[];
    final Object? rawContent = raw['content'] ?? raw['paragraphs'];
    if (rawContent is List<dynamic>) {
      for (final Object? line in rawContent) {
        if (line is String && line.trim().isNotEmpty) {
          paragraphs.add(line.trim());
        }
      }
    } else if (rawContent is String && rawContent.trim().isNotEmpty) {
      paragraphs.addAll(
        rawContent
            .split(RegExp(r'[\r\n]+'))
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty),
      );
    }
    if (paragraphs.isEmpty) {
      paragraphs.add('清风明月本无价，近水远山皆有情。');
    }

    // 解析体裁
    String genre = '';
    if (raw['type'] is Map<String, dynamic>) {
      final Map<String, dynamic> typeMap = raw['type'] as Map<String, dynamic>;
      genre = ((typeMap['name'] as String?) ?? '').trim();
    } else if (raw['type'] is String) {
      genre = (raw['type'] as String).trim();
    }
    if (genre.isEmpty || genre == '其他') {
      genre = ClassicalKnowledgeService.inferGenreFromParagraphs(
        paragraphs,
        dynasty,
      );
    }

    // 若与内置 18 首精选名篇同标题且同作者，优先复用内置精修赏析与译注
    for (final Poem curated in CuratedPoetryData.poems) {
      if (curated.authorName == authorName &&
          (curated.title == title ||
              title.contains(curated.title) ||
              curated.title.contains(title))) {
        return curated;
      }
    }

    // 智能甄选首页展示的代表名句（优先选择含对仗标点的完整联句）
    final String featuredQuote = _selectFeaturedQuote(paragraphs);

    // 智能推断意境分类标签
    final List<String> tags = _inferMoodTags(
      title: title,
      paragraphs: paragraphs,
      genre: genre,
      dynasty: dynasty,
    );

    // 根据意境标签与 ID 匹配专属中国传统色主题
    final PaletteType paletteType = _resolvePaletteForPoem(
      tags: tags,
      numericId: numericId,
      title: title,
    );

    return Poem(
      id: poemId,
      featuredQuote: featuredQuote,
      title: title,
      dynasty: dynasty,
      authorId: authorId,
      authorName: authorName,
      paragraphs: paragraphs,
      tags: tags,
      paletteType: paletteType,
      isRemote: true,
      genre: genre,
      translation: ClassicalKnowledgeService.generateTranslation(
        title: title,
        dynasty: dynasty,
        authorName: authorName,
        genre: genre,
        paragraphs: paragraphs,
      ),
      annotations: ClassicalKnowledgeService.generateAnnotations(
        title: title,
        dynasty: dynasty,
        authorName: authorName,
        genre: genre,
        paragraphs: paragraphs,
      ),
      background: ClassicalKnowledgeService.generateBackground(
        title: title,
        dynasty: dynasty,
        authorName: authorName,
        genre: genre,
        paragraphs: paragraphs,
      ),
      appreciation: ClassicalKnowledgeService.generateAppreciation(
        title: title,
        dynasty: dynasty,
        authorName: authorName,
        genre: genre,
        featuredQuote: featuredQuote,
        paragraphs: paragraphs,
        tags: tags,
      ),
    );
  }

  static String _selectFeaturedQuote(List<String> paragraphs) {
    if (paragraphs.isEmpty) {
      return '';
    }
    // 优先寻找包含逗号/顿号且长度适中（10 ~ 28 字）的完整诗联
    for (final String line in paragraphs) {
      final int len = line.length;
      if ((line.contains('，') || line.contains('、')) &&
          len >= 10 &&
          len <= 28) {
        return line;
      }
    }
    // 若每行仅为单句（不含逗号），将前两句合并为一联
    if (paragraphs.length >= 2 &&
        !paragraphs[0].contains('，') &&
        paragraphs[0].length <= 12) {
      final String first =
          paragraphs[0].replaceAll(RegExp(r'[，。！？；,.!?]$'), '');
      final String second =
          paragraphs[1].replaceAll(RegExp(r'[，。！？；,.!?]$'), '');
      return '$first，$second。';
    }
    return paragraphs.first;
  }

  static List<String> _inferMoodTags({
    required String title,
    required List<String> paragraphs,
    required String genre,
    required String dynasty,
  }) {
    final String corpus = '$title ${paragraphs.join(' ')}';
    final List<String> matched = <String>[];

    void checkAndAdd(String tag, RegExp pattern) {
      if (matched.length < 3 &&
          !matched.contains(tag) &&
          pattern.hasMatch(corpus)) {
        matched.add(tag);
      }
    }

    checkAndAdd('咏月', RegExp(r'[月婵娟蟾桂魄玉盘清辉]'));
    checkAndAdd('星空', RegExp(r'[星河汉银汉北斗乾坤云霄天河夜]'));
    checkAndAdd('山水', RegExp(r'[山川水江湖海溪涧林泉峰峦松竹烟云翠碧]'));
    checkAndAdd('思乡', RegExp(r'[乡故园归家客旅雁书愁思梦长安洛阳]'));
    checkAndAdd('送别', RegExp(r'[送别离赠辞行舟柳亭酒杯岐路万里故人]'));
    checkAndAdd('豪放', RegExp(r'[剑酒豪壮万里千秋苍茫风云吞山河雄大江铁马]'));
    checkAndAdd('婉约', RegExp(r'[花春香泪柳帘眉心红芳雨莺燕相思柔情]'));
    checkAndAdd('哲理', RegExp(r'[道禅空心悟真知古今天地人生浮生乾坤造化贤名]'));
    checkAndAdd('旷达', RegExp(r'[闲笑醉任平生悠然逍遥清风卧沧海扁舟天地]'));

    if (matched.isEmpty) {
      if (genre.contains('词')) {
        matched.add('婉约');
      } else if (genre.contains('绝句') || genre.contains('律诗')) {
        matched.add('山水');
      } else {
        matched.add('旷达');
      }
    }

    if (matched.length < 2) {
      const List<String> fallbacks = <String>['山水', '旷达', '哲理'];
      for (final String fb in fallbacks) {
        if (!matched.contains(fb)) {
          matched.add(fb);
          break;
        }
      }
    }

    return matched;
  }

  static PaletteType _resolvePaletteForPoem({
    required List<String> tags,
    required int numericId,
    required String title,
  }) {
    if (tags.contains('山水') || tags.contains('星空')) {
      return PaletteType.tianShuiBi;
    }
    if (tags.contains('咏月') || tags.contains('哲理')) {
      return PaletteType.songHuaHuang;
    }
    if (tags.contains('思乡') || tags.contains('送别')) {
      return PaletteType.muShanZi;
    }
    if (tags.contains('婉约')) {
      return PaletteType.yanZhiFen;
    }
    const List<PaletteType> lightPalettes = <PaletteType>[
      PaletteType.xuanPaper,
      PaletteType.tianShuiBi,
      PaletteType.songHuaHuang,
      PaletteType.muShanZi,
      PaletteType.yanZhiFen,
    ];
    final int seed = numericId > 0 ? numericId : title.hashCode.abs();
    return lightPalettes[seed % lightPalettes.length];
  }
}
