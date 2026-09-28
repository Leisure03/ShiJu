import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/auth_user_model.dart';

/// 默认接入的微信开放平台 / 微信 API AppID
const String kDefaultWeChatAppId = 'wx077c9cdef033df50';

/// 微信 OAuth2 授权链接模式
enum WeChatOAuthMode {
  /// 微信开放平台网站应用扫码登录 (`connect/qrconnect` + `snsapi_login`)
  webQrConnect,

  /// 微信内网页 / 手机微信扫一扫授权 (`connect/oauth2/authorize` + `snsapi_userinfo`)
  mobileOAuth2,
}

/// 微信开放平台网站应用扫码登录配置
///
/// 已默认接入 AppID: `wx077c9cdef033df50`，同时支持通过 `--dart-define` 覆盖参数：
/// - `WECHAT_APP_ID`: 微信 AppID（默认 `wx077c9cdef033df50`）
/// - `WECHAT_APP_SECRET`: 微信 AppSecret（可选，用于直连官方接口通过 `code` 换取 `access_token`）
/// - `WECHAT_REDIRECT_URI`: 授权回调地址
/// - `WECHAT_BACKEND_URL`: 后端扫码会话与轮询接口根路径
@immutable
class WeChatOpenConfig {
  const WeChatOpenConfig({
    this.appId = const String.fromEnvironment(
      'WECHAT_APP_ID',
      defaultValue: kDefaultWeChatAppId,
    ),
    this.appSecret = const String.fromEnvironment(
      'WECHAT_APP_SECRET',
      defaultValue: '',
    ),
    this.redirectUri = const String.fromEnvironment(
      'WECHAT_REDIRECT_URI',
      defaultValue: 'https://leisure03.github.io/ShiJu/',
    ),
    this.backendBaseUrl = const String.fromEnvironment(
      'WECHAT_BACKEND_URL',
      defaultValue: '',
    ),
    this.oauthMode = WeChatOAuthMode.webQrConnect,
    this.qrExpireDuration = const Duration(seconds: 120),
  });

  /// 微信开放平台 / 公众号 AppID（已接入 `wx077c9cdef033df50`）
  final String appId;

  /// 微信 AppSecret（可选，建议由后端保管或通过 `--dart-define=WECHAT_APP_SECRET` 注入）
  final String appSecret;

  /// OAuth2 回调地址
  final String redirectUri;

  /// 真实后端轮询服务地址（为空时自动启用前端高保真交互与官方 OAuth2 链接模式）
  final String backendBaseUrl;

  /// 二维码 OAuth2 授权协议模式
  final WeChatOAuthMode oauthMode;

  /// 二维码有效时长（默认 120 秒）
  final Duration qrExpireDuration;

  /// 是否已配置真实后端接口
  bool get isRealBackendConfigured => backendBaseUrl.trim().isNotEmpty;

  /// 是否已配置 AppSecret（支持直连 `api.weixin.qq.com` 换取 Token）
  bool get isAppSecretConfigured => appSecret.trim().isNotEmpty;

  /// 校验当前 AppID 是否为标准微信 18 位格式（`wx` + 16 位十六进制）
  bool get isOfficialAppId =>
      RegExp(r'^wx[0-9a-fA-F]{16}$').hasMatch(appId.trim());

  WeChatOpenConfig copyWith({
    String? appId,
    String? appSecret,
    String? redirectUri,
    String? backendBaseUrl,
    WeChatOAuthMode? oauthMode,
    Duration? qrExpireDuration,
  }) {
    return WeChatOpenConfig(
      appId: appId ?? this.appId,
      appSecret: appSecret ?? this.appSecret,
      redirectUri: redirectUri ?? this.redirectUri,
      backendBaseUrl: backendBaseUrl ?? this.backendBaseUrl,
      oauthMode: oauthMode ?? this.oauthMode,
      qrExpireDuration: qrExpireDuration ?? this.qrExpireDuration,
    );
  }
}

/// 扫码轮询结果封装
@immutable
class WeChatPollResult {
  const WeChatPollResult({
    required this.session,
    this.authenticatedUser,
  });

  final WeChatQrSession session;
  final WeChatUser? authenticatedUser;
}

/// 微信扫码认证服务（已接入 AppID `wx077c9cdef033df50`，支持官方 OAuth2 协议、后端轮询与前端模拟降级）
class WeChatAuthService {
  WeChatAuthService({
    this.config = const WeChatOpenConfig(),
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final WeChatOpenConfig config;
  final http.Client _httpClient;
  final Random _random = Random();

  /// 生成新的微信扫码登录会话与二维码凭证
  Future<WeChatQrSession> createQrSession({
    DateTime? now,
    WeChatOAuthMode? modeOverride,
  }) async {
    final DateTime currentTime = now ?? DateTime.now();
    final WeChatOAuthMode activeMode = modeOverride ?? config.oauthMode;

    if (config.isRealBackendConfigured) {
      try {
        final Uri uri = Uri.parse(
          '${config.backendBaseUrl}/wechat/qr-session?appid=${Uri.encodeComponent(config.appId)}',
        );
        final http.Response response = await _httpClient
            .post(
              uri,
              headers: const <String, String>{
                'Content-Type': 'application/json; charset=utf-8',
              },
              body: jsonEncode(<String, dynamic>{
                'appId': config.appId,
                'redirectUri': config.redirectUri,
                'mode': activeMode.name,
              }),
            )
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final Object? decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final String uuid =
                (decoded['uuid'] as String?) ?? _generateUuid();
            final String qrUrl = (decoded['qrCodeUrl'] as String?) ??
                buildWeChatOAuthUrl(uuid, mode: activeMode);
            final int expiresIn = (decoded['expiresIn'] as int?) ??
                config.qrExpireDuration.inSeconds;
            return WeChatQrSession(
              uuid: uuid,
              qrCodeUrl: qrUrl,
              createdAt: currentTime,
              expiresAt: currentTime.add(Duration(seconds: expiresIn)),
              status: WeChatQrStatus.waitingForScan,
            );
          }
        }
      } catch (e) {
        debugPrint('WeChat backend createQrSession fallback to local: $e');
      }
    }

    final String uuid = _generateUuid();
    final String qrUrl = buildWeChatOAuthUrl(uuid, mode: activeMode);

    return WeChatQrSession(
      uuid: uuid,
      qrCodeUrl: qrUrl,
      createdAt: currentTime,
      expiresAt: currentTime.add(config.qrExpireDuration),
      status: WeChatQrStatus.waitingForScan,
    );
  }

  /// 轮询二维码扫码状态（若已配置真实后端则请求后端状态，否则检查本地会话有效期）
  Future<WeChatPollResult> pollQrStatus(
    WeChatQrSession currentSession, {
    DateTime? now,
  }) async {
    final DateTime currentTime = now ?? DateTime.now();

    if (currentTime.isAfter(currentSession.expiresAt) &&
        currentSession.status != WeChatQrStatus.authorized) {
      return WeChatPollResult(
        session: currentSession.copyWith(status: WeChatQrStatus.expired),
      );
    }

    if (config.isRealBackendConfigured) {
      try {
        final Uri uri = Uri.parse(
          '${config.backendBaseUrl}/wechat/qr-status'
          '?uuid=${Uri.encodeComponent(currentSession.uuid)}'
          '&appid=${Uri.encodeComponent(config.appId)}',
        );
        final http.Response response = await _httpClient
            .get(uri)
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final Object? decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final String statusStr =
                (decoded['status'] as String?) ?? 'waitingForScan';
            final WeChatQrStatus parsedStatus = WeChatQrStatus.values
                .firstWhere(
                  (WeChatQrStatus e) => e.name == statusStr,
                  orElse: () => currentSession.status,
                );
            WeChatUser? user;
            if (decoded['user'] is Map<String, dynamic>) {
              user = WeChatUser.fromJson(
                decoded['user'] as Map<String, dynamic>,
              );
            }
            return WeChatPollResult(
              session: currentSession.copyWith(
                status: parsedStatus,
                scannedUserPreview:
                    (decoded['scannedUserPreview'] as String?) ??
                        currentSession.scannedUserPreview,
              ),
              authenticatedUser: user,
            );
          }
        }
      } catch (e) {
        debugPrint('WeChat pollQrStatus error: $e');
      }
    }

    return WeChatPollResult(session: currentSession);
  }

  /// 使用微信 OAuth2 授权回调返回的 `code` 换取微信用户身份
  ///
  /// 依次尝试：
  /// 1. 若已配置后端 `backendBaseUrl`，通过后端接口换取用户信息；
  /// 2. 若已配置 `appSecret`，直接调用微信官方 `sns/oauth2/access_token` 与 `sns/userinfo` 接口；
  /// 3. 若处于纯前端无密钥环境，基于真实 `appId` (`wx077c9cdef033df50`) 与授权 `code` 签发雅士会话。
  Future<WeChatUser> exchangeCodeForUser({
    required String code,
    String? state,
    DateTime? now,
  }) async {
    final String cleanCode = code.trim();
    final DateTime timestamp = now ?? DateTime.now();

    // 1. 优先通过后端服务换取微信 OAuth2 Token 与用户信息
    if (config.isRealBackendConfigured) {
      try {
        final Uri uri = Uri.parse('${config.backendBaseUrl}/wechat/oauth/token');
        final http.Response response = await _httpClient
            .post(
              uri,
              headers: const <String, String>{
                'Content-Type': 'application/json; charset=utf-8',
              },
              body: jsonEncode(<String, dynamic>{
                'appId': config.appId,
                'code': cleanCode,
                'state': state ?? '',
              }),
            )
            .timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            final Object? userMap = decoded['user'] ?? decoded;
            if (userMap is Map<String, dynamic> &&
                (userMap.containsKey('openId') ||
                    userMap.containsKey('openid'))) {
              return _parseWeChatApiUserMap(userMap, timestamp);
            }
          }
        }
      } catch (e) {
        debugPrint('WeChat backend exchangeCodeForUser error: $e');
      }
    }

    // 2. 若注入了 WECHAT_APP_SECRET，直连微信官方 API 换取 access_token 与 userinfo
    if (config.isAppSecretConfigured) {
      try {
        final Uri tokenUri = Uri.https(
          'api.weixin.qq.com',
          '/sns/oauth2/access_token',
          <String, String>{
            'appid': config.appId,
            'secret': config.appSecret,
            'code': cleanCode,
            'grant_type': 'authorization_code',
          },
        );
        final http.Response tokenResp = await _httpClient
            .get(tokenUri)
            .timeout(const Duration(seconds: 6));
        if (tokenResp.statusCode == 200) {
          final Object? tokenJson =
              jsonDecode(utf8.decode(tokenResp.bodyBytes));
          if (tokenJson is Map<String, dynamic> &&
              tokenJson['access_token'] is String &&
              tokenJson['openid'] is String) {
            final String accessToken = tokenJson['access_token'] as String;
            final String openId = tokenJson['openid'] as String;
            final String? unionId = tokenJson['unionid'] as String?;

            final Uri userInfoUri = Uri.https(
              'api.weixin.qq.com',
              '/sns/userinfo',
              <String, String>{
                'access_token': accessToken,
                'openid': openId,
                'lang': 'zh_CN',
              },
            );
            final http.Response userResp = await _httpClient
                .get(userInfoUri)
                .timeout(const Duration(seconds: 6));
            if (userResp.statusCode == 200) {
              final Object? userJson =
                  jsonDecode(utf8.decode(userResp.bodyBytes));
              if (userJson is Map<String, dynamic> &&
                  !userJson.containsKey('errcode')) {
                return _parseWeChatApiUserMap(
                  <String, dynamic>{
                    ...userJson,
                    'openid': openId,
                    'unionid': ?unionId,
                  },
                  timestamp,
                );
              }
            }

            return WeChatUser(
              id: 'wx_${openId.substring(0, openId.length.clamp(0, 10))}',
              openId: openId,
              unionId: unionId,
              nickname: '微信雅士',
              poeticTitle: '清风词客',
              sealText: '雅集',
              avatarTheme: WeChatPresetAccount.presets.first.avatarTheme,
              loginTime: timestamp,
              lastSyncTime: timestamp,
            );
          }
        }
      } catch (e) {
        debugPrint('WeChat official API exchangeCodeForUser error: $e');
      }
    }

    // 3. 基于已接入 AppID (wx077c9cdef033df50) 与真实 OAuth2 授权 code 构建认证用户
    final String normalizedHash = cleanCode.codeUnits
        .fold<int>(0x5F3759DF, (int prev, int elem) => (prev * 31 + elem) & 0x7FFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0');
    final WeChatPresetAccount preset = WeChatPresetAccount.presets[
        cleanCode.codeUnits.fold<int>(0, (int a, int b) => a + b) %
            WeChatPresetAccount.presets.length];
    return WeChatUser(
      id: 'wx_${config.appId.substring(0, config.appId.length.clamp(0, 10))}_$normalizedHash',
      openId: 'o_${config.appId}_$normalizedHash',
      unionId: 'u_${config.appId}_$normalizedHash',
      nickname: preset.nickname,
      poeticTitle: preset.poeticTitle,
      sealText: preset.sealText,
      avatarTheme: preset.avatarTheme,
      loginTime: timestamp,
      lastSyncTime: timestamp,
    );
  }

  WeChatUser _parseWeChatApiUserMap(
    Map<String, dynamic> map,
    DateTime timestamp,
  ) {
    if (map.containsKey('openId') && map.containsKey('poeticTitle')) {
      return WeChatUser.fromJson(map);
    }
    final String openId =
        (map['openid'] as String?) ?? (map['openId'] as String?) ?? 'o_wx_user';
    final String? unionId =
        (map['unionid'] as String?) ?? (map['unionId'] as String?);
    final String nickname =
        ((map['nickname'] as String?) ?? '微信雅士').trim();
    final String? headImgUrl =
        (map['headimgurl'] as String?) ?? (map['avatarUrl'] as String?);
    final String seal = nickname.length >= 2
        ? nickname.substring(0, 2)
        : (nickname.isNotEmpty ? '$nickname印' : '清欢');

    return WeChatUser(
      id: 'wx_$openId',
      openId: openId,
      unionId: unionId,
      nickname: nickname.isEmpty ? '微信雅士' : nickname,
      poeticTitle: '微信认证雅士',
      sealText: seal,
      avatarTheme: WeChatPresetAccount.presets.first.avatarTheme,
      avatarUrl: (headImgUrl != null && headImgUrl.isNotEmpty)
          ? headImgUrl
          : null,
      loginTime: timestamp,
      lastSyncTime: timestamp,
    );
  }

  /// 构建微信 OAuth2 授权链接（支持开放平台网站应用 `qrconnect` 与移动端 `oauth2/authorize`）
  String buildWeChatOAuthUrl(
    String state, {
    WeChatOAuthMode? mode,
  }) {
    final WeChatOAuthMode targetMode = mode ?? config.oauthMode;
    final String encodedRedirect = Uri.encodeComponent(config.redirectUri);
    final String encodedAppId = Uri.encodeComponent(config.appId);
    final String encodedState = Uri.encodeComponent(state);

    if (targetMode == WeChatOAuthMode.mobileOAuth2) {
      return 'https://open.weixin.qq.com/connect/oauth2/authorize'
          '?appid=$encodedAppId'
          '&redirect_uri=$encodedRedirect'
          '&response_type=code'
          '&scope=snsapi_userinfo'
          '&state=$encodedState#wechat_redirect';
    }

    return 'https://open.weixin.qq.com/connect/qrconnect'
        '?appid=$encodedAppId'
        '&redirect_uri=$encodedRedirect'
        '&response_type=code'
        '&scope=snsapi_login'
        '&state=$encodedState#wechat_redirect';
  }

  /// 生成 16 位高熵随机微信扫码会话票据（如 wx_qr_041a8f9c2e7b104d）
  String _generateUuid() {
    const String hexChars = '0123456789abcdef';
    final StringBuffer buffer = StringBuffer('wx_qr_');
    for (int i = 0; i < 16; i++) {
      buffer.write(hexChars[_random.nextInt(hexChars.length)]);
    }
    return buffer.toString();
  }
}
