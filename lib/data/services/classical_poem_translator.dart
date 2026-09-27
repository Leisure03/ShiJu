import '../../domain/models/poem_model.dart';

/// 古典诗词逐句白话今译与字词典故注释引擎
///
/// 针对「诗泉 API」等仅返回古诗原文的云端诗词，基于古典诗律（五言「二三」、七言「二二三」及词曲长短句节奏）、
/// 文言虚词句式规则与古汉语双音节词库，将全诗逐句转化为通顺典雅的现代白话译文，并提取诗中重点字词典故注释。
class ClassicalPoemTranslator {
  ClassicalPoemTranslator._();

  /// 判断一段译文是否为旧版模板式导读（需要升级为逐句完整白话今译）
  static bool isLegacyTemplateTranslation(String translation) {
    final String trimmed = translation.trim();
    if (trimmed.isEmpty) {
      return true;
    }
    return (trimmed.startsWith('本篇为') && trimmed.contains('为核心意象展开')) ||
        trimmed.contains('勾勒出清雅深远的东方诗学画卷');
  }

  /// 将整首诗词的段落列表逐句翻译为完整白话今译
  static String translatePoem({
    required List<String> paragraphs,
    String? title,
    String? dynasty,
    String? authorName,
  }) {
    if (paragraphs.isEmpty) {
      return '';
    }

    final List<String> translatedLines = <String>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final String rawLine = paragraphs[i].trim();
      if (rawLine.isEmpty) {
        continue;
      }
      final String lineTranslation = _translateLine(rawLine);
      if (lineTranslation.isNotEmpty) {
        translatedLines.add(lineTranslation);
      }
    }

    if (translatedLines.isEmpty) {
      return paragraphs.join('');
    }

    // 合并各联译文并规范标点衔接
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < translatedLines.length; i++) {
      String segment = translatedLines[i].trim();
      if (segment.isEmpty) continue;
      if (!RegExp(r'[。！？；，、]$').hasMatch(segment)) {
        // 若原诗为单句一行（如五绝/七绝分四行），奇数行用逗号，偶数行或末行用句号
        final bool isLast = i == translatedLines.length - 1;
        segment = (i.isEven && !isLast) ? '$segment，' : '$segment。';
      } else if (segment.endsWith('，') && i == translatedLines.length - 1) {
        segment = '${segment.substring(0, segment.length - 1)}。';
      }
      buffer.write(segment);
    }

    return _polishModernText(buffer.toString());
  }

  /// 从诗词原文与标题中提取重点字词、意象与典故逐条注释
  static List<PoemAnnotation> generateAnnotations({
    required String title,
    required String dynasty,
    required String authorName,
    required String genre,
    required List<String> paragraphs,
  }) {
    final String rawCorpus = '$title ${paragraphs.join(' ')}';
    final String normalizedCorpus = normalizeVariants(rawCorpus);
    final List<PoemAnnotation> matchedNotes = <PoemAnnotation>[];
    final Set<String> addedTerms = <String>{};

    // 1. 优先匹配诗中出现的典故、特定意象与古汉语重点词汇（按词长与典型度优先）
    for (final _GlossaryEntry entry in _annotationGlossary) {
      if (matchedNotes.length >= 4) {
        break;
      }
      if (entry.matches(rawCorpus, normalizedCorpus) &&
          !addedTerms.contains(entry.term)) {
        matchedNotes.add(
          PoemAnnotation(
            term: entry.term,
            explanation: entry.explanation,
          ),
        );
        addedTerms.add(entry.term);
      }
    }

    // 2. 若匹配不足 3 条，从诗句中自动提取有代表性的古汉语双字词生成释义
    if (matchedNotes.length < 3) {
      for (final String line in paragraphs) {
        if (matchedNotes.length >= 3) break;
        final List<String> clauses = _splitClauses(line);
        for (final String clause in clauses) {
          if (matchedNotes.length >= 3) break;
          final String norm = normalizeVariants(clause);
          for (final MapEntry<String, String> entry in _bigramDict.entries) {
            if (entry.key.length >= 2 &&
                norm.contains(entry.key) &&
                !addedTerms.contains(entry.key) &&
                !_commonSkipTerms.contains(entry.key)) {
              matchedNotes.add(
                PoemAnnotation(
                  term: entry.key,
                  explanation: '诗中指${entry.value}。',
                ),
              );
              addedTerms.add(entry.key);
              if (matchedNotes.length >= 3) break;
            }
          }
        }
      }
    }

    // 3. 补充题解或体裁说明作为兜底，确保注释详实完整
    if (matchedNotes.length < 2) {
      matchedNotes.add(
        PoemAnnotation(
          term: '题解 ·《$title》',
          explanation: '$dynasty代诗人$authorName所作$genre，借吟咏眼前风物以寄托胸中怀抱。',
        ),
      );
    }

    return matchedNotes;
  }

  /// 将异体字与常见古籍繁体字规范化，便于词库与句式匹配
  static String normalizeVariants(String input) {
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final String ch = input[i];
      sb.write(_variantCharMap[ch] ?? ch);
    }
    return sb.toString();
  }

  static const Map<String, String> _variantCharMap = <String, String>{
    '髪': '发',
    '髮': '发',
    '皦': '皎',
    '裏': '里',
    '裡': '里',
    '閒': '闲',
    '雲': '云',
    '風': '风',
    '歸': '归',
    '無': '无',
    '與': '与',
    '為': '为',
    '長': '长',
    '書': '书',
    '車': '车',
    '馬': '马',
    '鳥': '鸟',
    '見': '见',
    '門': '门',
    '開': '开',
    '關': '关',
    '處': '处',
    '來': '来',
    '時': '时',
    '聲': '声',
    '聽': '听',
    '萬': '万',
    '葉': '叶',
    '頭': '头',
    '顔': '颜',
    '顏': '颜',
    '嘆': '叹',
    '歎': '叹',
    '淚': '泪',
    '盡': '尽',
    '斷': '断',
    '獨': '独',
    '猶': '犹',
    '幾': '几',
    '歡': '欢',
    '舊': '旧',
    '雙': '双',
    '殘': '残',
    '煙': '烟',
    '樓': '楼',
    '臺': '台',
    '簾': '帘',
    '燈': '灯',
    '夢': '梦',
    '鄉': '乡',
    '邊': '边',
    '遠': '远',
    '還': '还',
    '過': '过',
    '遲': '迟',
    '難': '难',
    '離': '离',
    '飛': '飞',
    '飲': '饮',
    '舩': '船',
    '盃': '杯',
    '鴈': '雁',
    '峯': '峰',
    '巖': '岩',
    '谿': '溪',
    '遊': '游',
    '於': '于',
    '歲': '岁',
    '華': '华',
    '東': '东',
    '應': '应',
    '當': '当',
    '須': '须',
    '對': '对',
    '將': '将',
    '誰': '谁',
    '問': '问',
    '間': '间',
    '陰': '阴',
    '陽': '阳',
    '氣': '气',
    '連': '连',
    '満': '满',
    '滿': '满',
    '滄': '沧',
    '蒼': '苍',
    '窮': '穷',
    '絕': '绝',
    '綠': '绿',
    '紅': '红',
    '黃': '黄',
    '藍': '蓝',
    '鶴': '鹤',
    '鷗': '鸥',
    '鷺': '鹭',
    '鶯': '莺',
    '蟬': '蝉',
    '樹': '树',
    '花': '花',
    '草': '草',
    '輕': '轻',
    '重': '重',
    '點': '点',
    '興': '兴',
    '覺': '觉',
    '識': '识',
    '語': '语',
    '話': '话',
    '詩': '诗',
    '詞': '词',
    '賦': '赋',
    '劍': '剑',
    '琴': '琴',
    '簫': '箫',
    '笛': '笛',
    '鐘': '钟',
    '鼓': '鼓',
    '塵': '尘',
    '國': '国',
    '城': '城',
    '橋': '桥',
    '驛': '驿',
    '館': '馆',
    '閣': '阁',
    '院': '院',
    '窗': '窗',
    '戶': '户',
    '衣': '衣',
    '裳': '裳',
    '鬢': '鬓',
    '眉': '眉',
    '眼': '眼',
    '愁': '愁',
    '懷': '怀',
    '憶': '忆',
    '戀': '恋',
    '憐': '怜',
    '惜': '惜',
    '羨': '羡',
    '醉': '醉',
    '醒': '醒',
    '睡': '睡',
    '寢': '寝',
    '臥': '卧',
    '行': '行',
    '步': '步',
    '走': '走',
    '乘': '乘',
    '駕': '驾',
    '渡': '渡',
    '泛': '泛',
    '釣': '钓',
    '耕': '耕',
    '讀': '读',
    '寫': '写',
    '題': '题',
    '寄': '寄',
    '送': '送',
    '別': '别',
    '逢': '逢',
    '遇': '遇',
    '尋': '寻',
    '訪': '访',
    '望': '望',
    '看': '看',
    '觀': '观',
    '視': '视',
  };

  static List<String> _splitClauses(String line) {
    return line
        .split(RegExp(r'[，。！？；：、,.!?;:\s]+'))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
  }

  /// 翻译单行诗句（可包含一联或多句分句），保留并转换对应标点
  static String _translateLine(String line) {
    final RegExp tokenPattern = RegExp(r'([^，。！？；：、,.!?;:]+)([，。！？；：、,.!?;:]*)');
    final Iterable<RegExpMatch> matches = tokenPattern.allMatches(line);
    if (matches.isEmpty) {
      return '';
    }

    final List<String> parts = <String>[];
    final List<RegExpMatch> matchList = matches.toList();
    for (int i = 0; i < matchList.length; i++) {
      final RegExpMatch match = matchList[i];
      final String rawClause = (match.group(1) ?? '').trim();
      String punct = (match.group(2) ?? '').trim();
      if (rawClause.isEmpty) continue;

      final String translatedClause = translateClause(rawClause);
      if (punct.isEmpty) {
        punct = (i < matchList.length - 1) ? '，' : '。';
      } else if (punct == '、') {
        punct = '，';
      } else if (punct == ',') {
        punct = '，';
      } else if (punct == '.') {
        punct = '。';
      } else if (punct == '?') {
        punct = '？';
      } else if (punct == '!') {
        punct = '！';
      }

      // 若译文含反问语气且原句末为句号，可保持自然句读
      parts.add('$translatedClause$punct');
    }

    return parts.join('');
  }

  /// 翻译单个无标点分句（如「读书十车老已忘」「鞍马月桥南」）
  static String translateClause(String rawClause) {
    final String cleaned = rawClause
        .replaceAll(RegExp(r'[，。！？；：、“”‘’《》\s,.!?;:]'), '')
        .trim();
    if (cleaned.isEmpty) {
      return '';
    }

    final String norm = normalizeVariants(cleaned);

    // 1. 优先匹配整句精修映射
    final String? exactMatch = _exactClauseTranslations[norm];
    if (exactMatch != null) {
      return exactMatch;
    }

    // 2. 匹配典型文言句式模板
    final String? patternMatch = _matchSyntacticPatterns(norm);
    if (patternMatch != null) {
      return _polishClause(patternMatch);
    }

    // 3. 按古典诗律字数与语法结构拆解今译
    final int len = norm.length;
    String result;
    if (len == 7) {
      result = _translateSevenCharClause(norm);
    } else if (len == 5) {
      result = _translateFiveCharClause(norm);
    } else if (len == 4) {
      result = _translateFourCharClause(norm);
    } else if (len == 6) {
      result = _translateSixCharClause(norm);
    } else if (len == 3) {
      result = _translateThreeCharUnit(norm, isStandalone: true);
    } else if (len == 2) {
      result = _translateBigram(norm);
    } else {
      result = _translateGeneralSegment(norm);
    }

    return _polishClause(result);
  }

  /// 整句精修白话今译表（覆盖常见名句与典型诗句）
  static const Map<String, String> _exactClauseTranslations = <String, String>{
    // 沈辽《读书》
    '读书十车老已忘': '昔日纵使饱读十车诗书，到了年老之时也已渐渐遗忘',
    '人生得意须少壮': '人生快意施展抱负，终究应当趁着年少壮盛的时光',
    '白发渐多筋力衰': '如今两鬓白发日渐增多，筋骨气力也随之衰微',
    '谁为流年更惆怅': '还有谁会为了似水流逝的华年而更加黯然惆怅',
    '自寄蛮夷朋旧稀': '自从羁旅偏远荒僻之地，昔日亲朋故旧便音讯寥落',
    '更将黄卷卧斜晖': '更捧着一卷古籍书册，闲卧在傍晚的夕阳余晖之中',
    '古来枉直何足道': '自古以来世间的曲直是非又有什么值得挂齿说道',
    '昨日皎皎今还非': '昨日看似皎洁分明之事，到了今日回看却又成了非议与虚妄',
    // 李白《送族弟单父主簿凝》
    '吾家青萍剑': '我们家族的才俊恰似削铁如泥的青萍宝剑',
    '操割有余闲': '裁断政务自是游刃有余、从容清闲',
    '鞍马月桥南': '骑乘鞍马相送至月桥南畔',
    '光辉岐路间': '凛凛光彩照耀在离别的岐路之间',
    '光辉歧路间': '凛凛光彩照耀在离别的歧路之间',
    // 释正觉《与充维那》
    '机梭未动若为颜': '造化机梭尚未牵动时本自澄澈如初',
    '一点虚灵入道环': '一点澄明空灵的本心悄然契入圆融禅道之境',
    '明月光中窥自己': '在皎洁的明月清辉中观照自我真性',
    '白云影外到家山': '于悠悠白云倒影之外回归心灵故园家山',
    // 郑谷《九日偶怀寄左省张起居》
    '令节争欢我独闲': '佳节良辰众人竞相欢娱，唯独我安享清闲',
    '荒台尽日向晴山': '登上荒台整日里静静远眺晴朗的群山',
    '浑无酒泛金英菊': '手边全然没有美酒可浮泛金黄的秋菊',
    '羡君官重多吟兴': '钦羡您位重名高却依然饶有赋诗吟咏的雅兴',
    '醉带南陂落照还': '乘醉披着南陂的落日余晖尽兴归还',
    // 其他常见名句
    '清风明月本无价': '耳畔清风与天上明月本是无价之宝',
    '近水远山皆有情': '眼前绿水与远处青山皆含脉脉深情',
  };

  /// 匹配常见文言句式结构
  static String? _matchSyntacticPatterns(String norm) {
    // 1. 谁为 + A + 更 + B
    final RegExpMatch? mWhoFor =
        RegExp(r'^谁为(.{2})更(.{2})$').firstMatch(norm);
    if (mWhoFor != null) {
      return '还有谁会为了${_translateGeneralSegment(mWhoFor.group(1)!)}而更加${_translateGeneralSegment(mWhoFor.group(2)!)}';
    }

    // 2. 古来 / 自古 + A + 何足道 / 不足道
    final RegExpMatch? mWorthSaying =
        RegExp(r'^(古来|自古)(.+)何足道$').firstMatch(norm);
    if (mWorthSaying != null) {
      return '自古以来${_translateGeneralSegment(mWorthSaying.group(2)!)}又有什么值得挂齿说道';
    }

    // 3. 昨日 + A + 今还非 / 今已非
    final RegExpMatch? mYesterday =
        RegExp(r'^昨日(.{2})今(还非|已非)$').firstMatch(norm);
    if (mYesterday != null) {
      return '昨日${_translateGeneralSegment(mYesterday.group(1)!)}之事，到了今日却已似是而非';
    }

    // 4. 自寄 / 自从 + A(2) + B(2) + C(1)
    final RegExpMatch? mSince =
        RegExp(r'^(自寄|自从)(.{2})(.{2})(.)$').firstMatch(norm);
    if (mSince != null) {
      final String prefix = mSince.group(1) == '自寄' ? '自从羁旅寄居' : '自从';
      final String place = _translateBigram(mSince.group(2)!);
      final String tail =
          _translateThreeCharUnit('${mSince.group(3)!}${mSince.group(4)!}');
      return '$prefix$place，$tail';
    }

    // 5. 更将 / 且将 / 聊将 / 欲将 + A(2) + B(1) + C(2)
    final RegExpMatch? mTake =
        RegExp(r'^(更将|且将|聊将|欲将|还将)(.{2})(.{3})$').firstMatch(norm);
    if (mTake != null) {
      final Map<String, String> prefixMap = <String, String>{
        '更将': '更携着',
        '且将': '姑且拿那',
        '聊将': '聊且借着',
        '欲将': '想要将那',
        '还将': '依然拿着',
      };
      final String p = prefixMap[mTake.group(1)!] ?? '拿着';
      final String obj = _translateBigram(mTake.group(2)!);
      final String tail = _translateThreeCharUnit(mTake.group(3)!);
      return '$p$obj，$tail';
    }

    // 6. 浑无 / 全无 / 苦无 + A(1) + B(1) + C(3)
    final RegExpMatch? mNoWine =
        RegExp(r'^(浑无|全无|苦无|恨无)(.)(.)(.{3})$').firstMatch(norm);
    if (mNoWine != null) {
      final String prefix =
          mNoWine.group(1) == '苦无' || mNoWine.group(1) == '恨无'
              ? '只恨手边没有'
              : '全然没有';
      final String noun = _translateSingleChar(
        mNoWine.group(2)!,
        role: _CharRole.noun,
      );
      final String verb = _translateSingleChar(
        mNoWine.group(3)!,
        role: _CharRole.verb,
      );
      final String obj = _translateGeneralSegment(mNoWine.group(4)!);
      return '$prefix$noun可$verb$obj';
    }

    // 7. 不知 / 何处 / 几时 / 莫道 / 君不见 / 唯有 / 但见
    final RegExpMatch? mLeading = RegExp(
      r'^(不知|何处|几时|何时|莫道|休道|唯有|惟有|但见|只见|不觉|正是|恰似|安得|借问|试问|岂知|谁知|回首|独坐|独倚|相逢)(.+)$',
    ).firstMatch(norm);
    if (mLeading != null && norm.length >= 5) {
      const Map<String, String> leadMap = <String, String>{
        '不知': '不知',
        '何处': '何处',
        '几时': '何时才能',
        '何时': '何时才能',
        '莫道': '莫要说',
        '休道': '休要说',
        '唯有': '唯有那',
        '惟有': '唯有那',
        '但见': '只看见',
        '只见': '只看见',
        '不觉': '不知不觉间',
        '正是': '恰逢',
        '恰似': '恰似那',
        '安得': '怎能求得',
        '借问': '试问',
        '试问': '试问',
        '岂知': '哪里知晓',
        '谁知': '谁人知晓',
        '回首': '回首遥望',
        '独坐': '独自静坐在',
        '独倚': '独自凭倚着',
        '相逢': '相逢之际',
      };
      final String head = leadMap[mLeading.group(1)!] ?? mLeading.group(1)!;
      final String rest = mLeading.group(2)!;
      final String translatedRest = rest.length == 5
          ? _translateFiveCharClause(rest)
          : rest.length == 3
              ? _translateThreeCharUnit(rest)
              : _translateGeneralSegment(rest);
      return '$head$translatedRest';
    }

    return null;
  }

  /// 七言诗句（2 + 2 + 3 节奏）结构今译
  static String _translateSevenCharClause(String norm) {
    final String firstTwo = norm.substring(0, 2);
    final String secondTwo = norm.substring(2, 4);
    final String firstFour = norm.substring(0, 4);
    final String tailThree = norm.substring(4, 7);

    // 若前四字整体在四字词库中
    final String? fourPhrase = _fourCharDict[firstFour];
    final String prefixText;
    if (fourPhrase != null) {
      prefixText = fourPhrase;
    } else {
      prefixText = _combineTwoBigrams(firstTwo, secondTwo);
    }

    final String tailText = _translateThreeCharUnit(
      tailThree,
      precedingContext: firstFour,
    );

    // 若前四字以方位词结尾（如「明月光中」「白云影外」），自然衔接后三字谓语
    if (_isLocativeEnding(secondTwo) && !prefixText.startsWith('在') && !prefixText.startsWith('于')) {
      return '在$prefixText$tailText';
    }

    return '$prefixText$tailText';
  }

  /// 五言诗句（2 + 3 节奏）结构今译
  static String _translateFiveCharClause(String norm) {
    final String firstTwo = norm.substring(0, 2);
    final String tailThree = norm.substring(2, 5);

    final String prefixText = _translateBigram(firstTwo);
    final String tailText = _translateThreeCharUnit(
      tailThree,
      precedingContext: firstTwo,
    );

    return '$prefixText$tailText';
  }

  /// 四言诗句（2 + 2 节奏）结构今译
  static String _translateFourCharClause(String norm) {
    final String? fourPhrase = _fourCharDict[norm];
    if (fourPhrase != null) {
      return fourPhrase;
    }
    return _combineTwoBigrams(norm.substring(0, 2), norm.substring(2, 4));
  }

  /// 六言诗句（2 + 2 + 2 或 3 + 3 节奏）结构今译
  static String _translateSixCharClause(String norm) {
    final String a = _translateBigram(norm.substring(0, 2));
    final String b = _translateBigram(norm.substring(2, 4));
    final String c = _translateBigram(norm.substring(4, 6));
    return '$a$b$c';
  }

  /// 组合两个双字词单元（处理主谓、动宾、偏正与方位关系）
  static String _combineTwoBigrams(String firstTwo, String secondTwo) {
    final String t1 = _translateBigram(firstTwo);
    final String t2 = _translateBigram(secondTwo);

    // 若第二组是方位词组（如「光中」「影外」「山前」「溪边」）
    if (_isLocativeEnding(secondTwo)) {
      return '$t1$t2';
    }

    return '$t1$t2';
  }

  static bool _isLocativeEnding(String twoChars) {
    if (twoChars.length != 2) return false;
    return _locativePostpositions.contains(twoChars[1]);
  }

  /// 三字尾（或三字句）语法结构分析与今译（区分「整体三字」「1+2 动宾/状中」「2+1 主谓/方位」）
  static String _translateThreeCharUnit(
    String three, {
    String? precedingContext,
    bool isStandalone = false,
  }) {
    if (three.length != 3) {
      return _translateGeneralSegment(three);
    }

    // 1. 优先查三字固定词组表
    final String? trigram = _trigramDict[three];
    if (trigram != null) {
      return trigram;
    }

    final String c1 = three[0];
    final String c3 = three[2];
    final String firstTwo = three.substring(0, 2);
    final String lastTwo = three.substring(1, 3);

    // 2. 若末字为方位后置词（如「月桥南」「岐路间」「白云间」「春风里」「夕阳下」）
    // 但排除「入道环」这类 c1 为动词的情况
    if (_locativePostpositions.contains(c3) &&
        !_leadingVerbsAndPreps.contains(c1)) {
      final String np = _translateBigram(firstTwo);
      final String loc = _locativeSuffixMap[c3] ?? c3;
      if (precedingContext != null && precedingContext.isNotEmpty) {
        return '于$np$loc';
      }
      return '在$np$loc';
    }

    // 3. 「1 + 2」结构：首字为介词/动词/助动词/副词，后两字构成宾语或补语（如「卧斜晖」「向晴山」「入道环」「窥自己」「到家山」「须少壮」「更惆怅」「有余闲」「多吟兴」）
    if (_leadingVerbsAndPreps.contains(c1) &&
        (_bigramDict.containsKey(lastTwo) || !_predicateEndings.contains(c3))) {
      final String headVerb = _leadingVerbMap[c1] ??
          _translateSingleChar(c1, role: _CharRole.verb);
      final String obj = _translateBigram(lastTwo);
      if (_postureVerbsWithLocative.contains(c1)) {
        return '$headVerb于$obj之中';
      }
      return '$headVerb$obj';
    }

    // 4. 「2 + 1」结构：前两字为主语/名词短语/状语，末字为单音节谓语动词或形容词（如「筋力衰」「朋旧稀」「落照还」「白发多」「秋风起」）
    final String left = _translateBigram(firstTwo);
    final String right = _predicateEndingMap[c3] ??
        _translateSingleChar(c3, role: _CharRole.predicate);
    return '$left$right';
  }

  /// 翻译双字词单元
  static String _translateBigram(String two) {
    if (two.length != 2) {
      return _translateGeneralSegment(two);
    }

    final String? direct = _bigramDict[two];
    if (direct != null) {
      return direct;
    }

    final String c1 = two[0];
    final String c2 = two[1];

    // 叠字（如「皎皎」「悠悠」「萧萧」「凄凄」「盈盈」「迢迢」「茫茫」）
    if (c1 == c2) {
      final String? redup = _reduplicatedDict[two];
      if (redup != null) return redup;
      final String base = _translateSingleChar(c1, role: _CharRole.adjective);
      return '$two（$base之貌）';
    }

    // 数词/量词 + 名词（如「十车」「千山」「万里」「一壶」「三更」「孤舟」「满城」）
    if (_numeralOrQuantifiers.contains(c1)) {
      final String q = _quantifierPrefixMap[c1] ?? c1;
      final String n = _translateSingleChar(c2, role: _CharRole.noun);
      return '$q$n';
    }

    // 副词/否定词 + 动词/形容词（如「渐多」「未动」「已忘」「独闲」「争欢」「空留」）
    if (_adverbPrefixes.contains(c1)) {
      final String adv = _adverbPrefixMap[c1] ?? c1;
      final String v = _translateSingleChar(c2, role: _CharRole.verb);
      return '$adv$v';
    }

    // 名词 + 方位词（如「光中」「影外」「桥南」「山前」「溪边」「天涯」）
    if (_locativePostpositions.contains(c2)) {
      final String n = _translateSingleChar(c1, role: _CharRole.noun);
      final String loc = _locativeSuffixMap[c2] ?? c2;
      return '$n$loc';
    }

    // 形容词/颜色词 + 名词（如「晴山」「荒台」「斜晖」「黄卷」「寒江」「孤月」「清风」「白云」）
    if (_modifierPrefixes.contains(c1)) {
      final String mod = _modifierPrefixMap[c1] ??
          _translateSingleChar(c1, role: _CharRole.adjective);
      final String n = _translateSingleChar(c2, role: _CharRole.noun);
      return '$mod$n';
    }

    // 动词 + 宾语（如「读书」「把酒」「看山」「听雨」「思乡」「怀人」「羡君」「醉带」）
    if (_leadingVerbsAndPreps.contains(c1)) {
      final String v = _leadingVerbMap[c1] ??
          _translateSingleChar(c1, role: _CharRole.verb);
      final String o = _translateSingleChar(c2, role: _CharRole.noun);
      return '$v$o';
    }

    // 默认按双字组合今译
    final String left = _translateSingleChar(c1, role: _CharRole.general);
    final String right = _translateSingleChar(c2, role: _CharRole.general);
    return '$left$right';
  }

  /// 任意长度片段的最大正向匹配今译（用于长短句、词牌及非五七言句）
  static String _translateGeneralSegment(String text) {
    final StringBuffer sb = StringBuffer();
    int i = 0;
    while (i < text.length) {
      final int remaining = text.length - i;
      if (remaining >= 4) {
        final String sub4 = text.substring(i, i + 4);
        if (_fourCharDict.containsKey(sub4)) {
          sb.write(_fourCharDict[sub4]);
          i += 4;
          continue;
        }
      }
      if (remaining >= 3) {
        final String sub3 = text.substring(i, i + 3);
        if (_trigramDict.containsKey(sub3)) {
          sb.write(_trigramDict[sub3]);
          i += 3;
          continue;
        }
        if (remaining == 3) {
          sb.write(_translateThreeCharUnit(sub3));
          i += 3;
          continue;
        }
      }
      if (remaining >= 2) {
        final String sub2 = text.substring(i, i + 2);
        sb.write(_translateBigram(sub2));
        i += 2;
        continue;
      }
      sb.write(_translateSingleChar(text[i], role: _CharRole.general));
      i += 1;
    }
    return sb.toString();
  }

  static String _translateSingleChar(
    String ch, {
    required _CharRole role,
  }) {
    if (role == _CharRole.predicate && _predicateEndingMap.containsKey(ch)) {
      return _predicateEndingMap[ch]!;
    }
    if (role == _CharRole.verb && _leadingVerbMap.containsKey(ch)) {
      return _leadingVerbMap[ch]!;
    }
    if (role == _CharRole.noun && _singleNounMap.containsKey(ch)) {
      return _singleNounMap[ch]!;
    }
    if (role == _CharRole.adjective && _modifierPrefixMap.containsKey(ch)) {
      return _modifierPrefixMap[ch]!;
    }
    return _singleNounMap[ch] ??
        _leadingVerbMap[ch] ??
        _modifierPrefixMap[ch] ??
        _predicateEndingMap[ch] ??
        ch;
  }

  /// 对单句译文做去重与语感润色
  static String _polishClause(String input) {
    String s = input.trim();
    // 消除相邻重复词或冗余助词
    s = s
        .replaceAll('之中之中', '之中')
        .replaceAll('之外之外', '之外')
        .replaceAll('之间之间', '之间')
        .replaceAll('之上之上', '之上')
        .replaceAll('之下之下', '之下')
        .replaceAll('在在', '在')
        .replaceAll('于于', '于')
        .replaceAll('在于', '于')
        .replaceAll('于在', '在')
        .replaceAll('的的', '的')
        .replaceAll('山群山', '群山')
        .replaceAll('水碧水', '碧水')
        .replaceAll('月明月', '明月')
        .replaceAll('云白云', '白云')
        .replaceAll('风清风', '清风')
        .replaceAll('花繁花', '繁花');
    return s;
  }

  /// 对整段译文进行标点与语流润色
  static String _polishModernText(String input) {
    return input
        .replaceAll('，，', '，')
        .replaceAll('。。', '。')
        .replaceAll('，。', '。')
        .trim();
  }

  // ===========================================================================
  // 古汉语语法集合与词表
  // ===========================================================================

  static const Set<String> _locativePostpositions = <String>{
    '中',
    '内',
    '外',
    '间',
    '上',
    '下',
    '前',
    '后',
    '南',
    '北',
    '东',
    '西',
    '边',
    '畔',
    '旁',
    '侧',
    '里',
    '头',
    '底',
    '处',
    '际',
    '端',
    '阴',
    '阳',
    '隅',
    '陲',
  };

  static const Map<String, String> _locativeSuffixMap = <String, String>{
    '中': '之中',
    '内': '之内',
    '外': '之外',
    '间': '之间',
    '上': '之上',
    '下': '之下',
    '前': '之前',
    '后': '之后',
    '南': '南畔',
    '北': '北畔',
    '东': '东畔',
    '西': '西畔',
    '边': '岸边',
    '畔': '水畔',
    '旁': '身旁',
    '侧': '一侧',
    '里': '深处',
    '头': '尽头',
    '底': '底下',
    '处': '之处',
    '际': '之际',
    '端': '一端',
    '陲': '边陲',
  };

  static const Set<String> _postureVerbsWithLocative = <String>{
    '卧',
    '眠',
    '宿',
    '坐',
    '栖',
    '隐',
    '藏',
    '立',
    '住',
    '居',
    '泊',
  };

  static const Set<String> _leadingVerbsAndPreps = <String>{
    '向',
    '对',
    '临',
    '面',
    '入',
    '进',
    '归',
    '到',
    '至',
    '达',
    '过',
    '度',
    '穿',
    '越',
    '绕',
    '登',
    '出',
    '离',
    '辞',
    '别',
    '去',
    '来',
    '回',
    '还',
    '返',
    '卧',
    '眠',
    '宿',
    '坐',
    '倚',
    '凭',
    '立',
    '住',
    '居',
    '留',
    '驻',
    '隐',
    '藏',
    '在',
    '看',
    '望',
    '观',
    '视',
    '瞻',
    '窥',
    '见',
    '听',
    '闻',
    '思',
    '念',
    '怀',
    '忆',
    '惜',
    '怜',
    '爱',
    '羡',
    '慕',
    '恨',
    '愁',
    '悲',
    '叹',
    '笑',
    '问',
    '访',
    '寻',
    '觅',
    '知',
    '识',
    '解',
    '悟',
    '忘',
    '须',
    '当',
    '应',
    '宜',
    '欲',
    '愿',
    '肯',
    '敢',
    '能',
    '好',
    '喜',
    '畏',
    '恐',
    '怕',
    '有',
    '无',
    '少',
    '多',
    '满',
    '遍',
    '尽',
    '空',
    '添',
    '生',
    '起',
    '发',
    '动',
    '开',
    '成',
    '作',
    '化',
    '为',
    '是',
    '非',
    '如',
    '似',
    '若',
    '胜',
    '更',
    '犹',
    '尚',
    '仍',
    '亦',
    '皆',
    '俱',
    '独',
    '自',
    '徒',
    '枉',
    '已',
    '未',
    '不',
    '莫',
    '休',
    '渐',
    '忽',
    '乍',
    '聊',
    '且',
    '暂',
    '复',
    '又',
    '再',
    '相',
    '共',
    '同',
    '把',
    '将',
    '持',
    '携',
    '带',
    '伴',
    '随',
    '逐',
    '乘',
    '驾',
    '泛',
    '渡',
    '酌',
    '饮',
    '倾',
    '挥',
    '抚',
    '弄',
    '吹',
    '照',
    '映',
    '拂',
    '洒',
    '染',
    '惊',
    '破',
    '断',
    '送',
    '迎',
    '寄',
    '托',
    '题',
    '写',
    '读',
    '吟',
    '咏',
    '歌',
    '舞',
  };

  static const Map<String, String> _leadingVerbMap = <String, String>{
    '向': '静对',
    '对': '面对',
    '临': '登临',
    '面': '面向',
    '入': '步入',
    '进': '进入',
    '归': '归向',
    '到': '抵达',
    '至': '来到',
    '达': '通达',
    '过': '行过',
    '度': '渡过',
    '穿': '穿过',
    '越': '越过',
    '绕': '萦绕',
    '登': '登上',
    '出': '走出',
    '离': '离开',
    '辞': '辞别',
    '别': '告别',
    '去': '离去',
    '来': '来到',
    '回': '回望',
    '还': '归还',
    '返': '返回',
    '卧': '闲卧',
    '眠': '安眠',
    '宿': '夜宿',
    '坐': '静坐',
    '倚': '凭倚',
    '凭': '凭栏',
    '立': '伫立',
    '住': '停驻',
    '居': '栖居',
    '留': '留驻',
    '驻': '驻足',
    '隐': '隐逸',
    '藏': '深藏',
    '在': '身处',
    '看': '静看',
    '望': '遥望',
    '观': '静观',
    '视': '凝视',
    '瞻': '瞻望',
    '窥': '观照',
    '见': '望见',
    '听': '聆听',
    '闻': '听闻',
    '思': '思念',
    '念': '感念',
    '怀': '心怀',
    '忆': '追忆',
    '惜': '怜惜',
    '怜': '怜爱',
    '爱': '喜爱',
    '羡': '钦羡',
    '慕': '仰慕',
    '恨': '怅恨',
    '愁': '忧愁',
    '悲': '悲叹',
    '叹': '感叹',
    '笑': '欢笑',
    '问': '探问',
    '访': '寻访',
    '寻': '寻觅',
    '觅': '寻觅',
    '知': '知晓',
    '识': '相识',
    '解': '领会',
    '悟': '彻悟',
    '忘': '忘怀',
    '须': '终须',
    '当': '应当',
    '应': '想来应是',
    '宜': '最宜',
    '欲': '想要',
    '愿': '只愿',
    '肯': '怎肯',
    '敢': '怎敢',
    '能': '能够',
    '好': '喜爱',
    '喜': '欣喜',
    '畏': '畏惧',
    '恐': '唯恐',
    '怕': '生怕',
    '有': '尚有',
    '无': '并无',
    '少': '缺少',
    '多': '饶有',
    '满': '洒满',
    '遍': '走遍',
    '尽': '穷尽',
    '空': '徒然',
    '添': '平添',
    '生': '生出',
    '起': '兴起',
    '发': '抒发',
    '动': '触动',
    '开': '敞开',
    '成': '化作',
    '作': '化为',
    '化': '融化',
    '为': '为了',
    '是': '正是',
    '非': '并非',
    '如': '宛如',
    '似': '好似',
    '若': '恍若',
    '胜': '胜过',
    '更': '更加',
    '犹': '依然',
    '尚': '尚且',
    '仍': '仍然',
    '亦': '亦是',
    '皆': '皆都',
    '俱': '全都',
    '独': '唯独',
    '自': '自然',
    '徒': '徒然',
    '枉': '枉自',
    '已': '已经',
    '未': '尚未',
    '不': '不曾',
    '莫': '切莫',
    '休': '休要',
    '渐': '日渐',
    '忽': '忽然',
    '乍': '骤然',
    '聊': '姑且',
    '且': '暂且',
    '暂': '暂时',
    '复': '再度',
    '又': '又复',
    '再': '再次',
    '相': '彼此',
    '共': '共同',
    '同': '一同',
    '把': '手持',
    '将': '携着',
    '持': '手执',
    '携': '携手',
    '带': '披带',
    '伴': '相伴',
    '随': '伴随',
    '逐': '追逐',
    '乘': '乘着',
    '驾': '驾着',
    '泛': '浮泛',
    '渡': '远渡',
    '酌': '斟饮',
    '饮': '畅饮',
    '倾': '倾尽',
    '挥': '挥洒',
    '抚': '轻抚',
    '弄': '赏弄',
    '吹': '吹拂',
    '照': '映照',
    '映': '掩映',
    '拂': '轻拂',
    '洒': '挥洒',
    '染': '浸染',
    '惊': '惊动',
    '破': '冲破',
    '断': '斩断',
    '送': '送别',
    '迎': '相迎',
    '寄': '寄托',
    '托': '托付',
    '题': '题写',
    '写': '抒写',
    '读': '研读',
    '吟': '吟咏',
    '咏': '歌咏',
    '歌': '高歌',
    '舞': '起舞',
  };

  static const Set<String> _predicateEndings = <String>{
    '衰',
    '稀',
    '多',
    '少',
    '深',
    '浅',
    '高',
    '低',
    '远',
    '近',
    '长',
    '短',
    '清',
    '明',
    '暗',
    '寒',
    '冷',
    '暖',
    '闲',
    '忙',
    '静',
    '动',
    '空',
    '满',
    '尽',
    '绝',
    '断',
    '开',
    '落',
    '残',
    '歇',
    '老',
    '瘦',
    '新',
    '旧',
    '好',
    '是',
    '非',
    '难',
    '易',
    '迟',
    '早',
    '急',
    '缓',
    '重',
    '轻',
    '平',
    '生',
    '死',
    '成',
    '在',
    '亡',
    '去',
    '来',
    '归',
    '还',
    '返',
    '飞',
    '流',
    '起',
    '下',
    '入',
    '出',
    '行',
    '止',
    '住',
    '留',
    '宿',
    '眠',
    '醉',
    '醒',
    '笑',
    '啼',
    '鸣',
    '吟',
    '歌',
    '舞',
    '愁',
    '恨',
    '悲',
    '欢',
    '喜',
    '惊',
    '迷',
    '悟',
    '忘',
    '道',
  };

  static const Map<String, String> _predicateEndingMap = <String, String>{
    '衰': '日渐衰微',
    '稀': '音讯稀疏',
    '多': '日渐繁多',
    '少': '愈发稀少',
    '深': '幽深绵长',
    '浅': '清浅微茫',
    '高': '高耸入云',
    '低': '低垂轻拂',
    '远': '绵延辽远',
    '近': '相去匪遥',
    '长': '悠远绵长',
    '短': '苦短易逝',
    '清': '澄澈清朗',
    '明': '皎洁分明',
    '暗': '渐趋幽暗',
    '寒': '清寒逼人',
    '冷': '微凉清冷',
    '暖': '温煦融融',
    '闲': '自在清闲',
    '忙': '奔波匆忙',
    '静': '万籁俱静',
    '动': '微澜轻动',
    '空': '澄明皆空',
    '满': '盈满四方',
    '尽': '消散殆尽',
    '绝': '悄然断绝',
    '断': '声息断绝',
    '开': '欣然绽放',
    '落': '纷然飘落',
    '残': '凋零残破',
    '歇': '消歇散去',
    '老': '渐趋苍老',
    '瘦': '清减消瘦',
    '新': '焕然一新',
    '旧': '依稀如旧',
    '好': '正好相宜',
    '是': '本自如是',
    '非': '似是而非',
    '难': '尤为艰难',
    '易': '轻而易举',
    '迟': '姗姗来迟',
    '早': '春光尚早',
    '急': '湍急奔涌',
    '缓': '舒缓从容',
    '重': '深重绵密',
    '轻': '轻盈自在',
    '平': '平展如镜',
    '生': '悄然滋生',
    '死': '湮灭无闻',
    '成': '浑然天成',
    '在': '依然尚存',
    '亡': '消亡殆尽',
    '去': '悄然远去',
    '来': '翩然而至',
    '归': '踏途归来',
    '还': '尽兴归还',
    '返': '缓步返回',
    '飞': '凌空飞舞',
    '流': '潺潺流淌',
    '起': '随之兴起',
    '下': '冉冉落下',
    '入': '悄然映入',
    '出': '破云而出',
    '行': '信步前行',
    '止': '悄然止息',
    '住': '停驻不前',
    '留': '长久停留',
    '宿': '投宿栖息',
    '眠': '安然入眠',
    '醉': '酣然沉醉',
    '醒': '悄然醒转',
    '笑': '欣然欢笑',
    '啼': '婉转啼鸣',
    '鸣': '清越长鸣',
    '吟': '低回吟咏',
    '歌': '放声高歌',
    '舞': '翩然起舞',
    '愁': '暗生愁绪',
    '恨': '空留遗恨',
    '悲': '令人悲叹',
    '欢': '尽情欢娱',
    '喜': '欣然欢喜',
    '惊': '心头微惊',
    '迷': '迷离难辨',
    '悟': '豁然彻悟',
    '忘': '渐渐遗忘',
    '道': '挂齿说道',
  };

  static const Set<String> _numeralOrQuantifiers = <String>{
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '七',
    '八',
    '九',
    '十',
    '百',
    '千',
    '万',
    '半',
    '几',
    '数',
    '双',
    '孤',
    '独',
    '满',
    '遍',
    '片',
    '点',
    '寸',
  };

  static const Map<String, String> _quantifierPrefixMap = <String, String>{
    '一': '一',
    '二': '两',
    '三': '三',
    '四': '四',
    '五': '五',
    '六': '六',
    '七': '七',
    '八': '八',
    '九': '九',
    '十': '十',
    '百': '百',
    '千': '千重',
    '万': '万千',
    '半': '半',
    '几': '几度',
    '数': '数点',
    '双': '成双',
    '孤': '孤寂的',
    '独': '独自',
    '满': '满目',
    '遍': '遍地',
    '片': '一片',
    '点': '点点',
    '寸': '寸寸',
  };

  static const Set<String> _adverbPrefixes = <String>{
    '不',
    '未',
    '莫',
    '休',
    '无',
    '非',
    '已',
    '既',
    '渐',
    '更',
    '犹',
    '尚',
    '还',
    '自',
    '独',
    '空',
    '徒',
    '枉',
    '皆',
    '俱',
    '尽',
    '浑',
    '长',
    '常',
    '偶',
    '忽',
    '乍',
    '欲',
    '将',
    '须',
    '当',
    '应',
    '难',
    '易',
    '争',
    '共',
    '相',
    '同',
  };

  static const Map<String, String> _adverbPrefixMap = <String, String>{
    '不': '不曾',
    '未': '尚未',
    '莫': '切莫',
    '休': '休要',
    '无': '并无',
    '非': '并非',
    '已': '已经',
    '既': '既然',
    '渐': '日渐',
    '更': '更加',
    '犹': '依然',
    '尚': '尚且',
    '还': '依然',
    '自': '独自',
    '独': '唯独',
    '空': '徒然',
    '徒': '徒自',
    '枉': '枉自',
    '皆': '皆都',
    '俱': '全都',
    '尽': '尽数',
    '浑': '全然',
    '长': '长久',
    '常': '时常',
    '偶': '偶然',
    '忽': '忽然',
    '乍': '骤然',
    '欲': '想要',
    '将': '将要',
    '须': '须得',
    '当': '应当',
    '应': '应是',
    '难': '难以',
    '易': '容易',
    '争': '竞相',
    '共': '共同',
    '相': '互相',
    '同': '一同',
  };

  static const Set<String> _modifierPrefixes = <String>{
    '青',
    '碧',
    '翠',
    '绿',
    '红',
    '朱',
    '丹',
    '白',
    '素',
    '皓',
    '黄',
    '金',
    '紫',
    '玄',
    '苍',
    '孤',
    '寒',
    '冷',
    '清',
    '明',
    '幽',
    '空',
    '荒',
    '远',
    '近',
    '高',
    '深',
    '古',
    '旧',
    '故',
    '新',
    '残',
    '落',
    '飞',
    '流',
    '浮',
    '轻',
    '重',
    '闲',
    '野',
    '暮',
    '朝',
    '春',
    '秋',
    '夏',
    '冬',
    '夜',
    '晓',
    '晴',
    '阴',
    '芳',
    '香',
    '斜',
  };

  static const Map<String, String> _modifierPrefixMap = <String, String>{
    '青': '青翠的',
    '碧': '碧绿的',
    '翠': '苍翠的',
    '绿': '翠绿的',
    '红': '绯红的',
    '朱': '朱红的',
    '丹': '丹霞般的',
    '白': '素白的',
    '素': '素净的',
    '皓': '皎洁的',
    '黄': '金黄的',
    '金': '金色的',
    '紫': '紫气萦绕的',
    '玄': '玄幽的',
    '苍': '苍茫的',
    '孤': '孤寂的',
    '寒': '清寒的',
    '冷': '清冷的',
    '清': '澄澈的',
    '明': '明朗的',
    '幽': '幽深的',
    '空': '空旷的',
    '荒': '荒凉的',
    '远': '遥远的',
    '近': '近处的',
    '高': '高耸的',
    '深': '深邃的',
    '古': '古老的',
    '旧': '昔日的',
    '故': '故旧的',
    '新': '初生的',
    '残': '残存的',
    '落': '飘落的',
    '飞': '飞舞的',
    '流': '流转的',
    '浮': '漂浮的',
    '轻': '轻盈的',
    '重': '层叠的',
    '闲': '悠闲的',
    '野': '郊野的',
    '暮': '傍晚的',
    '朝': '清晨的',
    '春': '春日里的',
    '秋': '深秋的',
    '夏': '夏日的',
    '冬': '寒冬的',
    '夜': '夜色中的',
    '晓': '拂晓的',
    '晴': '晴朗的',
    '阴': '阴翳的',
    '芳': '芬芳的',
    '香': '幽香的',
    '斜': '西斜的',
  };

  static const Map<String, String> _singleNounMap = <String, String>{
    '山': '群山',
    '水': '碧水',
    '江': '江水',
    '河': '长河',
    '海': '沧海',
    '湖': '湖波',
    '溪': '溪流',
    '涧': '山涧',
    '泉': '清泉',
    '石': '山石',
    '林': '林木',
    '木': '草木',
    '树': '林树',
    '花': '繁花',
    '草': '芳草',
    '叶': '落叶',
    '竹': '翠竹',
    '松': '青松',
    '柳': '杨柳',
    '梅': '寒梅',
    '兰': '幽兰',
    '菊': '秋菊',
    '莲': '荷莲',
    '风': '清风',
    '雨': '烟雨',
    '云': '白云',
    '雪': '飞雪',
    '霜': '寒霜',
    '露': '清露',
    '烟': '云烟',
    '霞': '云霞',
    '日': '日光',
    '月': '明月',
    '星': '星辰',
    '天': '长天',
    '地': '大地',
    '春': '春光',
    '夏': '夏日',
    '秋': '秋色',
    '冬': '寒冬',
    '朝': '清晨',
    '暮': '薄暮',
    '夜': '夜色',
    '晓': '破晓',
    '舟': '扁舟',
    '船': '行船',
    '帆': '孤帆',
    '车': '车马',
    '马': '骏马',
    '剑': '宝剑',
    '酒': '美酒',
    '杯': '酒杯',
    '樽': '酒樽',
    '琴': '瑶琴',
    '笛': '竹笛',
    '箫': '洞箫',
    '歌': '歌声',
    '诗': '诗篇',
    '书': '诗书',
    '卷': '书卷',
    '信': '书信',
    '雁': '鸿雁',
    '鸟': '飞鸟',
    '莺': '黄莺',
    '燕': '春燕',
    '鹤': '仙鹤',
    '鸥': '沙鸥',
    '鹭': '白鹭',
    '猿': '山猿',
    '蝉': '秋蝉',
    '楼': '高楼',
    '台': '高台',
    '亭': '山亭',
    '阁': '楼阁',
    '庭': '庭院',
    '门': '门扉',
    '窗': '轩窗',
    '帘': '珠帘',
    '灯': '灯火',
    '烛': '烛光',
    '衣': '衣衫',
    '裳': '衣裳',
    '袖': '衣袖',
    '发': '鬓发',
    '鬓': '双鬓',
    '眉': '眉宇',
    '眼': '眼眸',
    '泪': '泪水',
    '颜': '容颜',
    '心': '心怀',
    '情': '情思',
    '愁': '愁绪',
    '恨': '离恨',
    '梦': '清梦',
    '魂': '神魂',
    '身': '此身',
    '客': '羁客',
    '人': '世人',
    '君': '君子',
    '吾': '我',
    '我': '我',
    '余': '我',
    '予': '我',
    '尔': '你',
    '汝': '你',
    '乡': '故乡',
    '家': '家园',
    '国': '家国',
    '城': '城池',
    '村': '村落',
    '路': '旅途',
    '途': '路途',
    '桥': '小桥',
    '寺': '古寺',
    '钟': '钟声',
    '鼓': '鼓声',
    '尘': '尘世',
    '道': '大道',
    '年': '华年',
    '岁': '岁月',
    '时': '时节',
    '声': '声响',
    '影': '清影',
    '光': '清辉',
    '色': '景致',
    '香': '幽香',
    '兴': '雅兴',
    '意': '心意',
  };

  static const Map<String, String> _reduplicatedDict = <String, String>{
    '皎皎': '皎洁澄明',
    '悠悠': '悠远绵长',
    '萧萧': '萧瑟飒飒',
    '凄凄': '凄清微寒',
    '依依': '依依不舍',
    '盈盈': '清澈盈盈',
    '迢迢': '千里迢迢',
    '茫茫': '苍茫浩渺',
    '浩浩': '浩荡无际',
    '落落': '坦荡磊落',
    '郁郁': '郁郁葱葱',
    '青青': '青翠欲滴',
    '苍苍': '苍茫寥廓',
    '冥冥': '幽远迷茫',
    '悄悄': '寂静无声',
    '默默': '脉脉无言',
    '空空': '空明澄澈',
    '纷纷': '纷繁交错',
    '点点': '零星点点',
    '片片': '片片飞舞',
    '重重': '层峦叠嶂',
    '处处': '随处可见',
    '年年': '岁岁年年',
    '日日': '朝朝暮暮',
    '夜夜': '夜夜更深',
    '朝朝': '朝朝暮暮',
    '暮暮': '朝朝暮暮',
    '亭亭': '亭亭玉立',
    '袅袅': '袅袅升腾',
    '潺潺': '潺潺流淌',
  };

  /// 四字成语与固定诗语今译表
  static const Map<String, String> _fourCharDict = <String, String>{
    '读书十车': '饱读十车诗书',
    '人生得意': '人生快意称心',
    '白发渐多': '两鬓白发渐增',
    '谁为流年': '谁人会为似水流年',
    '自寄蛮夷': '自从羁旅偏远之地',
    '更将黄卷': '更携着古籍黄卷',
    '古来枉直': '自古以来是非曲直',
    '昨日皎皎': '昨日看似皎洁分明',
    '令节争欢': '佳节里众人竞相欢娱',
    '荒台尽日': '登上荒台整日里',
    '羡君官重': '钦羡您位重名高',
    '醉带南陂': '乘醉披着南陂的',
    '机梭未动': '织机穿梭尚未牵动',
    '一点虚灵': '一点澄明空灵之心',
    '明月光中': '皎洁明月清辉之中',
    '白云影外': '悠悠白云疏影之外',
    '清风明月': '清风与明月',
    '近水远山': '近处绿水与远方青山',
    '春风桃李': '春风吹拂下桃李盛开',
    '秋雨梧桐': '秋雨淅沥拍打梧桐',
    '天涯海角': '远在天涯海角',
    '万水千山': '跨越万水千山',
    '千山万水': '跋涉千山万水',
    '良辰美景': '良辰美景当前',
    '悲欢离合': '人世间的悲欢离合',
    '阴晴圆缺': '明月的阴晴圆缺',
    '金戈铁马': '金戈铁马的沙场',
    '烟波浩渺': '浩渺无际的烟波',
    '风花雪月': '四时风花雪月',
    '山高水长': '山高水远而情意绵长',
    '水天一色': '碧水与长天融为一色',
    '落花流水': '落花飘零而流水东去',
  };

  /// 三字诗语今译表
  static const Map<String, String> _trigramDict = <String, String>{
    '青萍剑': '削铁如泥的青萍宝剑',
    '有余闲': '尚有游刃有余的闲暇',
    '月桥南': '在月桥南畔',
    '岐路间': '于离别的岐路之间',
    '歧路间': '于离别的歧路之间',
    '老已忘': '到了年老却已渐渐遗忘',
    '须少壮': '终究应当趁着年少壮盛之时',
    '筋力衰': '筋骨气力也随之衰微',
    '更惆怅': '而更加黯然惆怅',
    '朋旧稀': '昔日亲朋故旧便音讯稀疏',
    '卧斜晖': '闲卧在傍晚的夕阳余晖之中',
    '何足道': '又有什么值得挂齿说道',
    '今还非': '到了今日回看却又似是而非',
    '若为颜': '又将以何种容颜相对',
    '入道环': '悄然契入圆融禅道之境',
    '窥自己': '静心观照自我本心',
    '到家山': '回归心灵故园家山',
    '我独闲': '唯独我安享清闲',
    '向晴山': '静静远眺晴朗的群山',
    '金英菊': '金黄灿烂的秋菊',
    '多吟兴': '却依然饶有赋诗吟咏的雅兴',
    '落照还': '落日余晖尽兴归还',
    '不知处': '不知身在何处',
    '行路难': '感叹世途行路艰难',
    '相思苦': '饱尝相思之苦',
    '不胜寒': '禁受不住高处的清寒',
    '泪沾衣': '热泪不禁沾湿衣衫',
    '泪满巾': '泪水濡湿了佩巾',
    '人未归': '远行之人尚未归来',
    '客未归': '羁旅之客尚未归还',
    '春风里': '在和煦的春风里',
    '秋风起': '萧瑟秋风骤然吹起',
    '明月夜': '在皎洁的明月之夜',
    '白云间': '在悠悠白云深处',
    '斜阳里': '在傍晚的夕阳余晖里',
    '夕阳斜': '傍晚夕阳渐渐西斜',
    '水东流': '江水浩荡向东流去',
    '花满楼': '繁花盛开香满高楼',
    '月如钩': '新月弯弯如玉钩',
    '鬓成丝': '两鬓斑白如银丝',
    '独凭栏': '独自凭栏远眺',
    '凭栏处': '在凭栏远眺之处',
    '归去来': '不如就此归去',
    '任平生': '任凭走完这一生',
  };

  /// 高频古典诗词双字词库
  static const Map<String, String> _bigramDict = <String, String>{
    // 读书与仕途哲思
    '读书': '研读诗书',
    '十车': '十车书卷',
    '五车': '五车典籍',
    '黄卷': '古籍书卷',
    '青编': '史册典籍',
    '诗书': '诗书典籍',
    '文章': '锦绣文章',
    '翰墨': '笔墨文章',
    '得意': '快意称心',
    '少壮': '年少壮盛之时',
    '筋力': '筋骨气力',
    '白发': '两鬓白发',
    '华发': '斑白鬓发',
    '青丝': '乌黑鬓发',
    '流年': '似水流年',
    '华年': '青春华年',
    '浮生': '浮生岁月',
    '平生': '平生岁月',
    '余生': '此生余年',
    '人生': '人生在世',
    '古来': '自古以来',
    '自古': '自古以来',
    '千古': '千秋万古',
    '万古': '万古千秋',
    '今朝': '今日今朝',
    '昨日': '往昔昨日',
    '明日': '明日清晨',
    '明朝': '明日清晨',
    '当年': '往昔当年',
    '旧时': '往昔旧日',
    '往事': '过往旧事',
    '世事': '世间万事',
    '人间': '人世之间',
    '尘世': '红尘俗世',
    '乾坤': '天地乾坤',
    '天地': '天地之间',
    '造化': '天地造化',
    '枉直': '是非曲直',
    '是非': '是非对错',
    '荣辱': '荣华与屈辱',
    '得失': '进退得失',
    '功名': '功名利禄',
    '富贵': '富贵荣华',
    '官重': '位重名高',
    '余闲': '从容闲暇',
    '清闲': '清静悠闲',
    '独闲': '独自清闲',
    '操割': '裁断政务',
    '机梭': '造化机梭',
    '虚灵': '澄明空灵之心',
    '道环': '圆融禅道之境',
    '自己': '自我本心',
    '真性': '澄明真性',
    '禅心': '澄净禅心',

    // 情感与交游
    '惆怅': '黯然惆怅',
    '凄凉': '凄清悲凉',
    '寂寞': '孤寂落寞',
    '孤单': '孤单寂寥',
    '相思': '脉脉相思',
    '离别': '依依惜别',
    '别离': '生离死别',
    '送别': '置酒送别',
    '断肠': '柔肠寸断',
    '销魂': '黯然销魂',
    '多情': '脉脉多情',
    '无情': '冷漠无情',
    '闲愁': '无端闲愁',
    '离愁': '离愁别绪',
    '乡心': '思乡之心',
    '乡思': '思乡情怀',
    '乡愁': '故乡之思',
    '归心': '思归之心',
    '归思': '归乡之念',
    '壮志': '凌云壮志',
    '逸兴': '超逸雅兴',
    '吟兴': '赋诗吟咏之兴',
    '诗兴': '作诗雅兴',
    '清欢': '清雅之欢',
    '争欢': '竞相欢娱',
    '交欢': '把酒交欢',
    '朋旧': '亲朋故旧',
    '故人': '往日故交',
    '知己': '知心好友',
    '知音': '高山流水之知音',
    '亲故': '亲友故旧',
    '同游': '携手同游',
    '宦游': '出外宦游',
    '羁旅': '羁旅漂泊',
    '游子': '远行游子',
    '征人': '远戍征人',
    '佳人': '绝代佳人',
    '美人': '窈窕美人',
    '王孙': '贵族游子',
    '渔父': '江上渔翁',
    '林叟': '山林老翁',
    '吾家': '我们家族',
    '羡君': '钦羡您',
    '与君': '与您一同',
    '忆君': '思念于您',
    '思君': '挂念于您',
    '送君': '送别于您',
    '劝君': '奉劝友人',
    '为君': '为了友人',

    // 时序与节令
    '令节': '佳节良辰',
    '佳节': '良辰佳节',
    '重阳': '重阳佳节',
    '九日': '重阳佳节',
    '寒食': '寒食时节',
    '清明': '清明时节',
    '元夕': '元宵佳节',
    '中秋': '中秋月夜',
    '七夕': '七夕良宵',
    '除夕': '岁末除夕',
    '尽日': '整日里',
    '终日': '整日里',
    '连日': '连日以来',
    '彻夜': '整夜里',
    '一夜': '一整夜',
    '半夜': '半夜时分',
    '夜半': '夜半时分',
    '夜深': '夜深人静',
    '夜阑': '夜深人静',
    '三更': '三更深夜',
    '五更': '五更拂晓',
    '日暮': '日暮黄昏',
    '黄昏': '暮色黄昏',
    '薄暮': '傍晚薄暮',
    '平明': '黎明破晓',
    '清晨': '清晨破晓',
    '払晓': '拂晓时分',
    '斜晖': '夕阳余晖',
    '斜阳': '傍晚斜阳',
    '夕阳': '傍晚夕阳',
    '落照': '落日余晖',
    '残照': '夕阳残照',
    '落日': '西沉落日',
    '朝阳': '初升朝阳',
    '初日': '初升红日',
    '春风': '和煦春风',
    '秋风': '萧瑟秋风',
    '西风': '飒飒秋风',
    '东风': '浩荡东风',
    '南风': '温煦南风',
    '北风': '凛冽北风',
    '朔风': '塞外寒风',
    '清风': '习习清风',
    '微风': '柔和微风',
    '长风': '万里长风',
    '春光': '明媚春光',
    '春色': '满园春色',
    '春芳': '春日芳菲',
    '秋色': '万里秋色',
    '秋光': '澄澈秋光',
    '秋意': '微凉秋意',

    // 自然山水与风物
    '明月': '皎洁明月',
    '孤月': '天边孤月',
    '寒月': '清冷寒月',
    '新月': '初升新月',
    '残月': '晓天残月',
    '秋月': '澄澈秋月',
    '月色': '如水月色',
    '月光': '皎洁月光',
    '清辉': '澄澈清辉',
    '白云': '悠悠白云',
    '孤云': '天边孤云',
    '浮云': '游子般的浮云',
    '暮云': '傍晚暮云',
    '彩云': '绚丽彩云',
    '青云': '万里青云',
    '云霞': '绚烂云霞',
    '云汉': '璀璨银河',
    '星河': '璀璨星河',
    '银河': '浩瀚银河',
    '天河': '浩渺天河',
    '晴山': '晴朗的群山',
    '青山': '苍翠青山',
    '远山': '远方群山',
    '寒山': '深秋寒山',
    '空山': '空旷群山',
    '家山': '故园家山',
    '故山': '故乡山林',
    '南山': '终南山色',
    '西山': '西山暮色',
    '春山': '明净春山',
    '秋山': '澄净秋山',
    '千山': '千重山峦',
    '万山': '万重群山',
    '绿水': '澄碧流水',
    '碧水': '澄澈碧水',
    '秋水': '澄澈秋水',
    '春水': '浩渺春水',
    '流水': '潺潺流水',
    '清泉': '清澈山泉',
    '寒泉': '清冽寒泉',
    '江水': '浩荡江水',
    '江流': '奔涌江流',
    '沧海': '浩瀚沧海',
    '江海': '浩渺江海',
    '江湖': '烟波江湖',
    '洞庭': '浩渺洞庭湖',
    '潇湘': '潇湘水畔',
    '烟雨': '迷蒙烟雨',
    '风雨': '凄风苦雨',
    '细雨': '蒙蒙细雨',
    '夜雨': '淅沥夜雨',
    '暮雨': '傍晚暮雨',
    '春雨': '潇潇春雨',
    '秋雨': '微凉秋雨',
    '新雨': '初歇新雨',
    '飞雪': '漫天飞雪',
    '寒霜': '凛冽寒霜',
    '白露': '晶莹白露',
    '清露': '晨间清露',
    '云烟': '缥缈云烟',
    '风烟': '万里风烟',
    '波澜': '浩渺波澜',
    '波涛': '汹涌波涛',

    // 地理建筑与器物
    '荒台': '荒凉高台',
    '高台': '巍峨高台',
    '楼台': '亭台楼阁',
    '高楼': '百尺高楼',
    '危楼': '高耸楼阁',
    '西楼': '西畔高楼',
    '南楼': '南畔高楼',
    '朱阁': '朱红楼阁',
    '城阙': '巍峨城阙',
    '庭院': '幽深庭院',
    '中庭': '庭院之中',
    '茅店': '茅草客店',
    '孤舟': '一叶孤舟',
    '扁舟': '一叶扁舟',
    '轻舟': '轻快小舟',
    '兰舟': '木兰小舟',
    '归舟': '返乡归舟',
    '渔舟': '江上渔舟',
    '孤帆': '天边孤帆',
    '鞍马': '骑乘鞍马',
    '车马': '喧阗车马',
    '月桥': '月下长桥',
    '溪桥': '溪头小桥',
    '岐路': '离别岔路',
    '歧路': '离别岔路',
    '归路': '返乡归路',
    '天涯': '天涯海角',
    '海内': '四海之内',
    '万里': '万里之遥',
    '千里': '千里之遥',
    '蛮夷': '偏远荒僻之地',
    '南陂': '南坡池岸',
    '东篱': '东篱之下',
    '故园': '故乡家园',
    '故乡': '万里故乡',
    '家国': '万里家国',
    '长安': '帝京长安',
    '洛阳': '东都洛阳',
    '江南': '烟雨江南',
    '塞外': '苍茫塞外',
    '关山': '万里关山',
    '光辉': '凛凛光彩',
    '芳菲': '春日芳菲',
    '落花': '飘零落花',
    '飞花': '漫天飞花',
    '桃花': '灼灼桃花',
    '杏花': '粉白杏花',
    '梨花': '如雪梨花',
    '梅花': '傲雪梅花',
    '菊花': '凌霜秋菊',
    '黄花': '金黄秋菊',
    '荷花': '亭亭荷花',
    '藕花': '清香荷花',
    '杨柳': '依依杨柳',
    '垂柳': '拂水垂柳',
    '芳草': '萋萋芳草',
    '幽篁': '幽深竹林',
    '松竹': '苍松翠竹',
    '杜鹃': '啼血杜鹃',
    '鸿雁': '南飞鸿雁',
    '归雁': '北归大雁',
    '秋雁': '南飞秋雁',
    '鸥鹭': '水畔鸥鹭',
    '美酒': '醇香美酒',
    '浊酒': '一壶浊酒',
    '清酒': '清冽美酒',
    '把酒': '端起酒杯',
    '举杯': '高举酒杯',
    '独酌': '独自斟饮',
    '沉醉': '酣然沉醉',
    '醉后': '饮醉之后',
    '醉带': '乘醉披带',
  };

  static const Set<String> _commonSkipTerms = <String>{
    '自己',
    '人生',
    '明日',
    '今日',
    '昨日',
    '古来',
    '自古',
    '清闲',
    '人间',
    '天地',
    '离别',
    '相思',
  };

  /// 重点字词、意象与典故注释词库（按优先级排序）
  static const List<_GlossaryEntry> _annotationGlossary = <_GlossaryEntry>[
    // 沈辽《读书》相关典故字词
    _GlossaryEntry(
      term: '读书十车',
      keywords: <String>['十车', '五车'],
      explanation: '化用《庄子·天下》“惠施多方，其书五车”，以十车极言平生博览群书、藏书阅读之宏富。',
    ),
    _GlossaryEntry(
      term: '黄卷',
      keywords: <String>['黄卷'],
      explanation: '古人书卷多用黄檗（bò）汁浸染防蠹，故称书籍典册为“黄卷”。',
    ),
    _GlossaryEntry(
      term: '枉直',
      keywords: <String>['枉直'],
      explanation: '出自《论语·颜渊》“举直错诸枉”，指世俗之曲直、是非与毁誉。',
    ),
    _GlossaryEntry(
      term: '皦皦',
      keywords: <String>['皦皦', '皎皎'],
      explanation: '皦（jiǎo）同“皎”，形容光明洁白、黑白分明之貌，诗中指往日自以为清晰昭然的世事。',
    ),
    _GlossaryEntry(
      term: '斜晖',
      keywords: <String>['斜晖', '落照', '残照'],
      explanation: '傍晚西斜的日光余晖，古典诗词中常借夕阳暮色烘托悠然闲居或岁月迟暮之感。',
    ),
    _GlossaryEntry(
      term: '流年',
      keywords: <String>['流年'],
      explanation: '如流水般易逝的光阴年华。',
    ),
    _GlossaryEntry(
      term: '蛮夷',
      keywords: <String>['蛮夷'],
      explanation: '古代泛指远离中原京畿的南方或偏远荒僻之地，诗人常于贬谪或羁旅远方时自况。',
    ),
    // 李白《送族弟单父主簿凝》相关典故
    _GlossaryEntry(
      term: '青萍剑',
      keywords: <String>['青萍'],
      explanation: '战国时宋国名剑，见陈琳《答东阿王笺》“秉青萍干将之器”，诗中借以盛赞族弟才器锋利超群。',
    ),
    _GlossaryEntry(
      term: '操割',
      keywords: <String>['操割'],
      explanation: '执刀割裁，化用“操刀必割”与“庖丁解牛”之典，比喻从政理民游刃有余。',
    ),
    _GlossaryEntry(
      term: '岐路',
      keywords: <String>['岐路', '歧路'],
      explanation: '岔路，古人常于城外岔道口设宴践行，故“岐路”为送别诗中的核心离别意象。',
    ),
    // 释正觉《与充维那》相关禅宗典故
    _GlossaryEntry(
      term: '机梭',
      keywords: <String>['机梭'],
      explanation: '织布机之梭，禅宗常以“机梭未动”喻指一念未生、不落言筌的本真顿悟状态。',
    ),
    _GlossaryEntry(
      term: '虚灵',
      keywords: <String>['虚灵'],
      explanation: '心体空明澄澈而灵妙不昧，指纤尘不染的本心佛性。',
    ),
    _GlossaryEntry(
      term: '家山',
      keywords: <String>['家山'],
      explanation: '原指故乡的山林，禅诗中亦双关“本地风光”，即回归澄明自在的本来面目。',
    ),
    // 郑谷《九日偶怀寄左省张起居》相关典故
    _GlossaryEntry(
      term: '令节',
      keywords: <String>['令节'],
      explanation: '美好的传统佳节，如重阳、寒食、上巳等时令佳辰。',
    ),
    _GlossaryEntry(
      term: '金英菊',
      keywords: <String>['金英菊', '金英', '黄花'],
      explanation: '金英即金黄色的菊花瓣，古人重阳节有采菊枝浮于酒杯饮菊花酒以祈福辟邪之雅俗。',
    ),
    _GlossaryEntry(
      term: '南陂',
      keywords: <String>['南陂'],
      explanation: '陂（bēi），池岸、山坡。南陂指城南水泽山坡一带的郊游胜处。',
    ),
    // 通用高频古典诗词意象与典故
    _GlossaryEntry(
      term: '蓬莱',
      keywords: <String>['蓬莱'],
      explanation: '传说中的海上仙山，东汉亦称藏书之东观为“蓬莱山”，诗中常喻仙境或文苑秘阁。',
    ),
    _GlossaryEntry(
      term: '建安骨',
      keywords: <String>['建安'],
      explanation: '建安风骨，指汉末建安时期刚健俊爽、慷慨悲凉的诗歌风范。',
    ),
    _GlossaryEntry(
      term: '扁舟',
      keywords: <String>['扁舟', '孤舟', '兰舟'],
      explanation: '小船。自范蠡泛舟五湖后，“扁舟”成为古典诗词中超脱尘网、逍遥江湖的象征。',
    ),
    _GlossaryEntry(
      term: '云汉 / 星河',
      keywords: <String>['云汉', '星河', '银汉', '天河'],
      explanation: '即天上的银河，古人常借璀璨星汉寄托渺远高洁的宇宙遐思。',
    ),
    _GlossaryEntry(
      term: '婵娟',
      keywords: <String>['婵娟'],
      explanation: '姿态曼妙美好，诗词中多指代皎洁圆满的明月或远方佳人。',
    ),
    _GlossaryEntry(
      term: '杜鹃 / 子规',
      keywords: <String>['杜鹃', '子规', '蜀魄'],
      explanation: '相传古蜀王杜宇化为杜鹃鸟，春暮啼声若“不如归去”，常借以寄托深切思乡与悲切之情。',
    ),
    _GlossaryEntry(
      term: '鸿雁 / 雁书',
      keywords: <String>['鸿雁', '归雁', '秋雁', '雁字', '雁书', '锦书'],
      explanation: '化用“鸿雁传书”之典，大雁随春秋迁徙，古人常借归雁寄托游子思乡与亲友尺素相思。',
    ),
    _GlossaryEntry(
      term: '杨柳 / 折柳',
      keywords: <String>['杨柳', '垂柳', '折柳', '柳色'],
      explanation: '“柳”谐音“留”，汉唐以来长安灞桥送别有折柳相赠之俗，遂成惜别怀远之典型意象。',
    ),
    _GlossaryEntry(
      term: '阳关 / 渭城',
      keywords: <String>['阳关', '渭城'],
      explanation: '指王维《送元二使安西》所谱《阳关三叠》送别曲，亦指通往西域的边塞关隘。',
    ),
    _GlossaryEntry(
      term: '东篱',
      keywords: <String>['东篱'],
      explanation: '化用陶渊明《饮酒》“采菊东篱下，悠然见南山”，象征隐逸高洁、恬淡自适的田园胸襟。',
    ),
    _GlossaryEntry(
      term: '沧浪',
      keywords: <String>['沧浪'],
      explanation: '出自《楚辞·渔父》“沧浪之水清兮，可以濯吾缨”，象征顺应自然、清白自守的处世哲学。',
    ),
    _GlossaryEntry(
      term: '乾坤',
      keywords: <String>['乾坤'],
      explanation: '《周易》以乾为天、坤为地，诗中指代苍茫天地与宇宙江山。',
    ),
    _GlossaryEntry(
      term: '华发 / 白发',
      keywords: <String>['华发', '白发', '白髪', '霜鬓'],
      explanation: '花白或雪白的鬓发，古人常于揽镜自照时借白发感叹流年易逝与壮志未酬。',
    ),
    _GlossaryEntry(
      term: '空山 / 幽篁',
      keywords: <String>['空山', '幽篁', '深林', '清泉'],
      explanation: '幽静空灵的山林泉石意象，以自然之澄明映照诗人超然物外的禅悦心境。',
    ),
    _GlossaryEntry(
      term: '明月意象',
      keywords: <String>['明月', '孤月', '寒月', '秋月', '月色', '月光'],
      explanation: '古典诗词核心意象之一，常借皎洁月色寄托高洁志趣、宇宙永恒之思或千里怀远之情。',
    ),
    _GlossaryEntry(
      term: '白云意象',
      keywords: <String>['白云', '孤云', '浮云', '暮云', '彩云'],
      explanation: '白云舒卷无心、来去自由，诗中常以浮云喻游子行踪，以白云喻隐逸高洁之志。',
    ),
    _GlossaryEntry(
      term: '西风 / 秋风',
      keywords: <String>['西风', '秋风', '朔风'],
      explanation: '金秋时节自西而来的萧瑟秋风，常触发诗人对时序流转、万物盛衰与身世飘零的感怀。',
    ),
    _GlossaryEntry(
      term: '春风意象',
      keywords: <String>['春风', '东风'],
      explanation: '复苏万物的和煦春风，象征生机勃发、仕途顺遂或江南明媚春光。',
    ),
    _GlossaryEntry(
      term: '把酒 / 独酌',
      keywords: <String>['把酒', '独酌', '举杯', '浊酒', '美酒', '醉后'],
      explanation: '古典诗酒文化意象，诗人借杯中醇酒消解块垒、激扬豪情或寄托知己难逢之慨。',
    ),
  ];
}

enum _CharRole {
  noun,
  verb,
  adjective,
  predicate,
  general,
}

class _GlossaryEntry {
  const _GlossaryEntry({
    required this.term,
    required this.keywords,
    required this.explanation,
  });

  final String term;
  final List<String> keywords;
  final String explanation;

  bool matches(String rawCorpus, String normalizedCorpus) {
    for (final String kw in keywords) {
      if (rawCorpus.contains(kw) || normalizedCorpus.contains(kw)) {
        return true;
      }
    }
    return false;
  }
}
