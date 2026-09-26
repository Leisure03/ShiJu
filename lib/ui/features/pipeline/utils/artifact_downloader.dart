import 'artifact_downloader_stub.dart'
    if (dart.library.js_interop) 'artifact_downloader_web.dart' as impl;

/// 触发浏览器或桌面端下载指定的 Jenkins 归档产物文件（如 dist/shiju-android-release.apk）
void triggerArtifactDownload(String artifactRelativePath) {
  impl.triggerArtifactDownloadImpl(artifactRelativePath);
}

/// 在本地桌面端通过内置服务唤起系统资源管理器并定位到该构建产物文件
Future<bool> revealArtifactInExplorer(String artifactRelativePath) {
  return impl.revealArtifactInExplorerImpl(artifactRelativePath);
}
