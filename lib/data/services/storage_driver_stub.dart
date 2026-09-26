/// 跨平台键值存储驱动抽象接口
abstract class StorageDriver {
  Future<String?> getItem(String key);
  Future<void> setItem(String key, String value);
}

StorageDriver createStorageDriver() =>
    throw UnsupportedError('Cannot create StorageDriver without platform implementation.');
