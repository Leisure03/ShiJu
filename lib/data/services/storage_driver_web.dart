import 'package:web/web.dart' as web;
import 'storage_driver_stub.dart';

class WebStorageDriver implements StorageDriver {
  @override
  Future<String?> getItem(String key) async {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setItem(String key, String value) async {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {
      // 忽略隐私模式或配额异常
    }
  }
}

StorageDriver createStorageDriver() => WebStorageDriver();
