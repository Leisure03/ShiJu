import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/auth_user_model.dart';

/// 微信开放平台网站应用扫码登录配置
///
/// 支持通过 `--dart-define` 注入真实微信开放平台参数与后端接口地址：
/// - `WECHAT_APP_ID`: 微信开放平台网站应用 AppID（如 `wx8888888888888888`）
/// - `WECHAT_REDIRECT_URI`: 授权回调地址
/// - `WECHAT_BACKEND_URL`: 后端扫码会话与轮询接口根路径
@immutable
class WeChatOpenConfig {
  const WeChatOpenConfig({
    this.appId = const String.fromEnvironment(
      'WECHAT_APP_ID',
      defaultValue: 'wx_shiju_oriental_poetry',
    ),
    this.redirectUri = const String.fromEnvironment(
      'WECHAT_REDIRECT_URI',
      defaultValue: 'https://shiju.poetry.app/auth/wechat/callback',
    ),
    this.backendBaseUrl = const String.fromEnvironment(
      'WECHAT_BACKEND_URL',
      defaultValue: '',
    ),
    this.qrExpireDuration = const Duration(seconds: 120),
  });

  /// 微信开放平台 AppID
  final String appId;

  /// OAuth2 回调地址
  final String redirectUri;

  /// 真实后端轮询服务地址（为空时自动启用前端高保真交互模拟模式）
  final String backendBaseUrl;

  /// 二维码有效时长（默认 120 秒）
  final Duration qrExpireDuration;

  /// 是否已配置真实后端接口
  bool get isRealBackendConfigured => backendBaseUrl.trim().isNotEmpty;
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

/// 微信扫码认证服务（支持真实后端接口调用与纯前端交互式模拟降级）
class WeChatAuthService {
  WeChatAuthService({
    this.config = const WeChatOpenConfig(),
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final WeChatOpenConfig config;
  final http.Client _httpClient;
  final Random _random = Random();

  /// 生成新的微信扫码登录会话与二维码凭证
  Future<WeChatQrSession> createQrSession({DateTime? now}) async {
    final DateTime currentTime = now ?? DateTime.now();

    if (config.isRealBackendConfigured) {
      try {
        final Uri uri = Uri.parse('${config.backendBaseUrl}/wechat/qr-session');
        final http.Response response = await _httpClient
            .post(uri)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final Object? decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final String uuid =
                (decoded['uuid'] as String?) ?? _generateUuid();
            final String qrUrl = (decoded['qrCodeUrl'] as String?) ??
                _buildStandardWeChatQrUrl(uuid);
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
    final String qrUrl = _buildStandardWeChatQrUrl(uuid);

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
          '${config.backendBaseUrl}/wechat/qr-status?uuid=${Uri.encodeComponent(currentSession.uuid)}',
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

  /// 构建符合微信开放平台 OAuth2 网站应用规范的扫码链接
  String _buildStandardWeChatQrUrl(String uuid) {
    final String encodedRedirect = Uri.encodeComponent(config.redirectUri);
    return 'https://open.weixin.qq.com/connect/qrconnect'
        '?appid=${config.appId}'
        '&redirect_uri=$encodedRedirect'
        '&response_type=code'
        '&scope=snsapi_login'
        '&state=$uuid#wechat_redirect';
  }

  /// 生成 16 位高熵随机微信扫码会话票据（如 041a8f9c2e7b104d）
  String _generateUuid() {
    const String hexChars = '0123456789abcdef';
    final StringBuffer buffer = StringBuffer('wx_qr_');
    for (int i = 0; i < 16; i++) {
      buffer.write(hexChars[_random.nextInt(hexChars.length)]);
    }
    return buffer.toString();
  }
}
