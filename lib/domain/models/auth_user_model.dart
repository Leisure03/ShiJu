import 'package:flutter/foundation.dart';
import '../../ui/core/theme/traditional_palette.dart';

/// 微信扫码登录状态枚举
enum WeChatQrStatus {
  /// 正在向微信开放平台请求生成二维码凭证
  generating,

  /// 二维码已生成，等待使用手机微信扫一扫
  waitingForScan,

  /// 手机微信已扫码成功，等待在手机端点击「确认登录」
  scannedWaitingConfirm,

  /// 已确认授权，正在拉取雅士信息并同步藏书阁
  authorized,

  /// 二维码已过期（需点击刷新）
  expired,

  /// 网络或接口异常
  error,
}

/// 微信扫码登录会话模型
@immutable
class WeChatQrSession {
  const WeChatQrSession({
    required this.uuid,
    required this.qrCodeUrl,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.scannedUserPreview,
    this.errorMessage,
  });

  /// 微信扫码会话唯一票据
  final String uuid;

  /// 二维码编码内容（微信开放平台标准 OAuth2 URL）
  final String qrCodeUrl;

  /// 会话创建时间
  final DateTime createdAt;

  /// 二维码过期时间
  final DateTime expiresAt;

  /// 当前扫码状态
  final WeChatQrStatus status;

  /// 已扫码待确认时的微信昵称预览
  final String? scannedUserPreview;

  /// 异常错误提示
  final String? errorMessage;

  /// 剩余有效秒数
  int remainingSeconds(DateTime now) {
    final int diff = expiresAt.difference(now).inSeconds;
    return diff > 0 ? diff : 0;
  }

  WeChatQrSession copyWith({
    String? uuid,
    String? qrCodeUrl,
    DateTime? createdAt,
    DateTime? expiresAt,
    WeChatQrStatus? status,
    String? scannedUserPreview,
    String? errorMessage,
  }) {
    return WeChatQrSession(
      uuid: uuid ?? this.uuid,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      scannedUserPreview: scannedUserPreview ?? this.scannedUserPreview,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 微信登录雅士用户模型
@immutable
class WeChatUser {
  const WeChatUser({
    required this.id,
    required this.openId,
    required this.nickname,
    required this.poeticTitle,
    required this.sealText,
    required this.avatarTheme,
    required this.loginTime,
    this.unionId,
    this.avatarUrl,
    this.lastSyncTime,
  });

  /// 本地/系统用户 ID
  final String id;

  /// 微信 OpenID
  final String openId;

  /// 微信 UnionID（可选）
  final String? unionId;

  /// 微信昵称 / 拾句雅号（如：竹林听雪）
  final String nickname;

  /// 雅士斋号/头衔（如：松窗词客）
  final String poeticTitle;

  /// 专属朱砂闲章文字（2~4 字，如：听雪、清欢）
  final String sealText;

  /// 东方水墨头像传统色主题
  final PaletteType avatarTheme;

  /// 真实微信头像 URL（若来自真实微信接口则优先渲染网络头像）
  final String? avatarUrl;

  /// 本次登录时间
  final DateTime loginTime;

  /// 藏书阁云端最后同步时间
  final DateTime? lastSyncTime;

  /// 取昵称首字作为水墨头像核心字
  String get avatarMonogram {
    final String trimmed = nickname.trim();
    if (trimmed.isEmpty) return '雅';
    return trimmed.firstCharOrFallback;
  }

  WeChatUser copyWith({
    String? id,
    String? openId,
    String? unionId,
    String? nickname,
    String? poeticTitle,
    String? sealText,
    PaletteType? avatarTheme,
    String? avatarUrl,
    DateTime? loginTime,
    DateTime? lastSyncTime,
  }) {
    return WeChatUser(
      id: id ?? this.id,
      openId: openId ?? this.openId,
      unionId: unionId ?? this.unionId,
      nickname: nickname ?? this.nickname,
      poeticTitle: poeticTitle ?? this.poeticTitle,
      sealText: sealText ?? this.sealText,
      avatarTheme: avatarTheme ?? this.avatarTheme,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      loginTime: loginTime ?? this.loginTime,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'openId': openId,
      'unionId': unionId,
      'nickname': nickname,
      'poeticTitle': poeticTitle,
      'sealText': sealText,
      'avatarTheme': avatarTheme.name,
      'avatarUrl': avatarUrl,
      'loginTime': loginTime.toIso8601String(),
      'lastSyncTime': lastSyncTime?.toIso8601String(),
    };
  }

  factory WeChatUser.fromJson(Map<String, dynamic> json) {
    final String themeName =
        (json['avatarTheme'] as String?) ?? PaletteType.tianShuiBi.name;
    final PaletteType resolvedTheme = PaletteType.values.firstWhere(
      (PaletteType e) => e.name == themeName,
      orElse: () => PaletteType.tianShuiBi,
    );

    final String? loginTimeStr = json['loginTime'] as String?;
    final String? syncTimeStr = json['lastSyncTime'] as String?;

    return WeChatUser(
      id: (json['id'] as String?) ?? 'wx_user_default',
      openId: (json['openId'] as String?) ?? 'oShiJu_WeChat_001',
      unionId: json['unionId'] as String?,
      nickname: (json['nickname'] as String?) ?? '竹林听雪',
      poeticTitle: (json['poeticTitle'] as String?) ?? '松窗词客',
      sealText: (json['sealText'] as String?) ?? '清欢',
      avatarTheme: resolvedTheme,
      avatarUrl: json['avatarUrl'] as String?,
      loginTime: loginTimeStr != null
          ? (DateTime.tryParse(loginTimeStr) ?? DateTime.now())
          : DateTime.now(),
      lastSyncTime:
          syncTimeStr != null ? DateTime.tryParse(syncTimeStr) : null,
    );
  }
}

extension _StringFirstCharExtension on String {
  String get firstCharOrFallback {
    if (isEmpty) return '雅';
    return String.fromCharCode(runes.first);
  }
}

/// 预设微信雅士体验账号模板
@immutable
class WeChatPresetAccount {
  const WeChatPresetAccount({
    required this.id,
    required this.openId,
    required this.nickname,
    required this.poeticTitle,
    required this.sealText,
    required this.avatarTheme,
    required this.defaultFavorites,
  });

  final String id;
  final String openId;
  final String nickname;
  final String poeticTitle;
  final String sealText;
  final PaletteType avatarTheme;
  final List<String> defaultFavorites;

  WeChatUser toWeChatUser({DateTime? now}) {
    final DateTime timestamp = now ?? DateTime.now();
    return WeChatUser(
      id: id,
      openId: openId,
      unionId: 'u_${openId}_shiju',
      nickname: nickname,
      poeticTitle: poeticTitle,
      sealText: sealText,
      avatarTheme: avatarTheme,
      loginTime: timestamp,
      lastSyncTime: timestamp,
    );
  }

  static const List<WeChatPresetAccount> presets = <WeChatPresetAccount>[
    WeChatPresetAccount(
      id: 'wx_shiju_01',
      openId: 'oShiJu_8a92f1c03b_01',
      nickname: '竹林听雪',
      poeticTitle: '松窗词客',
      sealText: '听雪',
      avatarTheme: PaletteType.tianShuiBi,
      defaultFavorites: <String>['poem_01', 'poem_02'],
    ),
    WeChatPresetAccount(
      id: 'wx_shiju_02',
      openId: 'oShiJu_7c31e8d42a_02',
      nickname: '松风煮茗',
      poeticTitle: '东坡门下客',
      sealText: '清欢',
      avatarTheme: PaletteType.songHuaHuang,
      defaultFavorites: <String>['poem_02', 'poem_03'],
    ),
    WeChatPresetAccount(
      id: 'wx_shiju_03',
      openId: 'oShiJu_5b19a4f60e_03',
      nickname: '沧浪散人',
      poeticTitle: '江湖夜雨人',
      sealText: '卧云',
      avatarTheme: PaletteType.muShanZi,
      defaultFavorites: <String>['poem_01', 'poem_05'],
    ),
  ];
}
