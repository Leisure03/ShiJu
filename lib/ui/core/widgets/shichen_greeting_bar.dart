import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../theme/traditional_palette.dart';

/// 古代十二时辰信息数据类
@immutable
class ShichenInfo {
  const ShichenInfo({
    required this.name,
    required this.alias,
    required this.greeting,
    required this.timeRange,
  });

  /// 时辰名（如：戌时）
  final String name;

  /// 古称雅号（如：夜阑 / 黄昏）
  final String alias;

  /// 应景诗意导语
  final String greeting;

  /// 现代时间区间说明
  final String timeRange;

  /// 组合标题（如：戌时 · 夜阑）
  String get fullTitle => '$name · $alias';

  /// 根据给定时间计算对应的古代时辰与导语
  static ShichenInfo fromDateTime(DateTime dateTime) {
    final int hour = dateTime.hour;
    if (hour == 23 || hour == 0) {
      return const ShichenInfo(
        name: '子时',
        alias: '夜半',
        greeting: '万籁俱寂，星汉低垂，唯清梦与诗心相伴',
        timeRange: '23:00 - 01:00',
      );
    } else if (hour >= 1 && hour < 3) {
      return const ShichenInfo(
        name: '丑时',
        alias: '鸡鸣',
        greeting: '夜深露重，残灯微明，天地蓄养晨光',
        timeRange: '01:00 - 03:00',
      );
    } else if (hour >= 3 && hour < 5) {
      return const ShichenInfo(
        name: '寅时',
        alias: '平旦',
        greeting: '夜与昼交，东方既白，万物悄然苏醒',
        timeRange: '03:00 - 05:00',
      );
    } else if (hour >= 5 && hour < 7) {
      return const ShichenInfo(
        name: '卯时',
        alias: '日出',
        greeting: '晨露未晞，旭日初升，宜诵清词以启新朝',
        timeRange: '05:00 - 07:00',
      );
    } else if (hour >= 7 && hour < 9) {
      return const ShichenInfo(
        name: '辰时',
        alias: '食时',
        greeting: '朝雾散尽，春风满怀，人间烟火正清明',
        timeRange: '07:00 - 09:00',
      );
    } else if (hour >= 9 && hour < 11) {
      return const ShichenInfo(
        name: '巳时',
        alias: '隅中',
        greeting: '日暖风恬，茶烟轻飏，展卷偶遇千古知音',
        timeRange: '09:00 - 11:00',
      );
    } else if (hour >= 11 && hour < 13) {
      return const ShichenInfo(
        name: '午时',
        alias: '日中',
        greeting: '日丽中天，浮生偷闲，片刻清静胜却人间无数',
        timeRange: '11:00 - 13:00',
      );
    } else if (hour >= 13 && hour < 15) {
      return const ShichenInfo(
        name: '未时',
        alias: '日昳',
        greeting: '日影微斜，竹影婆娑，最宜闲敲棋子落灯花',
        timeRange: '13:00 - 15:00',
      );
    } else if (hour >= 15 && hour < 17) {
      return const ShichenInfo(
        name: '申时',
        alias: '哺时',
        greeting: '斜阳晚照，清风徐来，且将心事寄予青山绿水',
        timeRange: '15:00 - 17:00',
      );
    } else if (hour >= 17 && hour < 19) {
      return const ShichenInfo(
        name: '酉时',
        alias: '日入',
        greeting: '落霞孤鹜，暮山凝紫，倦鸟归林而诗意方浓',
        timeRange: '17:00 - 19:00',
      );
    } else if (hour >= 19 && hour < 21) {
      return const ShichenInfo(
        name: '戌时',
        alias: '夜阑',
        greeting: '暮色四合，明月入户，宜微吟浅酌、静拾佳句',
        timeRange: '19:00 - 21:00',
      );
    } else {
      return const ShichenInfo(
        name: '亥时',
        alias: '人定',
        greeting: '夜阑风静，星河清浅，一卷古诗伴君安眠',
        timeRange: '21:00 - 23:00',
      );
    }
  }
}

/// 顶部时辰与应景导语展示栏（新中式极简书眉版式，无厚重边框）
class ShichenGreetingBar extends StatelessWidget {
  const ShichenGreetingBar({
    super.key,
    required this.palette,
    this.dateTime,
  });

  final TraditionalPalette palette;
  final DateTime? dateTime;

  @override
  Widget build(BuildContext context) {
    final ShichenInfo info =
        ShichenInfo.fromDateTime(dateTime ?? DateTime.now());

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: palette.cinnabarRed.withValues(alpha: 0.85),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          info.fullTitle,
          style: AppTypography.label(
            palette.secondaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ).copyWith(letterSpacing: 1.2),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '·',
            style: AppTypography.label(
              palette.mutedText.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ),
        Flexible(
          child: Text(
            info.greeting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.attribution(
              palette.mutedText,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}
