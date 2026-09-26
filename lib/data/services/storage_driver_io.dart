import 'dart:convert';
import 'dart:io';
import 'storage_driver_stub.dart';

class IoStorageDriver implements StorageDriver {
  static final Map<String, String> _memoryCache = <String, String>{};
  static bool _loadedFromDisk = false;

  File get _storageFile {
    final String dirPath = Directory.systemTemp.path;
    return File('$dirPath${Platform.pathSeparator}shiju_local_storage.json');
  }

  Future<void> _ensureLoaded() async {
    if (_loadedFromDisk) return;
    _loadedFromDisk = true;
    try {
      final File file = _storageFile;
      if (await file.exists()) {
        final String content = await file.readAsString();
        final Object? decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((String k, dynamic v) {
            if (v is String) {
              _memoryCache[k] = v;
            }
          });
        }
      }
    } catch (_) {
      // 忽略沙盒或测试环境中的文件读取异常，使用内存缓存
    }
  }

  @override
  Future<String?> getItem(String key) async {
    await _ensureLoaded();
    return _memoryCache[key];
  }

  @override
  Future<void> setItem(String key, String value) async {
    await _ensureLoaded();
    _memoryCache[key] = value;
    try {
      final File file = _storageFile;
      await file.writeAsString(jsonEncode(_memoryCache));
    } catch (_) {
      // 忽略沙盒写入限制
    }
  }

  /// 供测试重置内存状态
  static void clearMemoryForTesting() {
    _memoryCache.clear();
    _loadedFromDisk = true;
  }
}

StorageDriver createStorageDriver() => IoStorageDriver();
