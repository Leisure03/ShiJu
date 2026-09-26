import 'dart:convert';
import '../../domain/models/auth_user_model.dart';
import 'storage_driver_stub.dart';
import 'storage_driver_stub.dart'
    if (dart.library.js_interop) 'storage_driver_web.dart'
    if (dart.library.io) 'storage_driver_io.dart' as driver_factory;

/// 本地持久化服务（Web 端底层使用 window.localStorage，原生端使用本地持久化文件）
class LocalStorageService {
  LocalStorageService({StorageDriver? driver})
      : _driver = driver ?? driver_factory.createStorageDriver();

  final StorageDriver _driver;

  static const String kFavoritesKey = 'shiju_favorites';
  static const String kHistoryKey = 'shiju_history';
  static const String kVerticalLayoutKey = 'shiju_is_vertical_layout';
  static const String kDarkModeKey = 'shiju_is_dark_mode';
  static const String kAuthUserKey = 'shiju_wechat_auth_user';

  /// 获取收藏诗词 ID 列表
  Future<List<String>> getFavoriteIds() async {
    final String? raw = await _driver.getItem(kFavoritesKey);
    if (raw == null || raw.isEmpty) {
      return <String>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {}
    return <String>[];
  }

  /// 保存收藏诗词 ID 列表
  Future<void> saveFavoriteIds(List<String> ids) async {
    await _driver.setItem(kFavoritesKey, jsonEncode(ids));
  }

  /// 获取阅读历史诗词 ID 列表（按最近浏览排序）
  Future<List<String>> getHistoryIds() async {
    final String? raw = await _driver.getItem(kHistoryKey);
    if (raw == null || raw.isEmpty) {
      return <String>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {}
    return <String>[];
  }

  /// 保存阅读历史诗词 ID 列表
  Future<void> saveHistoryIds(List<String> ids) async {
    await _driver.setItem(kHistoryKey, jsonEncode(ids));
  }

  /// 获取排版偏好（true = 古籍竖排 vertical-rl，false = 现代横排居中）
  /// 默认开启极具中式韵味的古籍竖排或横排（此处默认 false 现代横排或 true 竖排，可根据用户切换持久化）
  Future<bool> getIsVerticalLayout({bool defaultValue = true}) async {
    final String? raw = await _driver.getItem(kVerticalLayoutKey);
    if (raw == null) return defaultValue;
    return raw == 'true';
  }

  /// 保存排版偏好
  Future<void> saveIsVerticalLayout(bool isVertical) async {
    await _driver.setItem(kVerticalLayoutKey, isVertical.toString());
  }

  /// 获取夜间模式（玄青色 #1A1C1E）偏好
  Future<bool> getIsDarkMode({bool defaultValue = false}) async {
    final String? raw = await _driver.getItem(kDarkModeKey);
    if (raw == null) return defaultValue;
    return raw == 'true';
  }

  /// 保存夜间模式偏好
  Future<void> saveIsDarkMode(bool isDark) async {
    await _driver.setItem(kDarkModeKey, isDark.toString());
  }

  /// 获取已登录的微信雅士用户信息（未登录返回 null）
  Future<WeChatUser?> getAuthUser() async {
    final String? raw = await _driver.getItem(kAuthUserKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return WeChatUser.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// 保存或清除微信登录用户信息（传入 null 表示退出登录）
  Future<void> saveAuthUser(WeChatUser? user) async {
    if (user == null) {
      await _driver.setItem(kAuthUserKey, '');
    } else {
      await _driver.setItem(kAuthUserKey, jsonEncode(user.toJson()));
    }
  }
}
