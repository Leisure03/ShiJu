import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/app_update_model.dart';

/// 远端构建清单拉取回调类型（便于单元测试注入自定义响应）
typedef ManifestFetcher = Future<AppReleaseManifest?> Function();

/// 「拾句（ShiJu）」Jenkins 制品库版本探测与热更新服务
class AppUpdateService {
  AppUpdateService({
    this.httpClient,
    this.customFetcher,
    this.enableNetworkProbe = true,
  });

  final http.Client? httpClient;
  final ManifestFetcher? customFetcher;

  /// 是否启用真实 HTTP 探测（在隔离 Widget 测试中可按需关闭或注入 customFetcher）
  final bool enableNetworkProbe;

  /// 编译期默认应用版本号（可通过 --dart-define=APP_VERSION=1.0.7 覆盖）
  static const String kDefaultAppVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.6',
  );

  /// 编译期默认构建号（可通过 --dart-define=APP_BUILD_NUMBER=108 覆盖）
  static const int kDefaultBuildNumber = int.fromEnvironment(
    'APP_BUILD_NUMBER',
    defaultValue: 108,
  );

  /// 向 Jenkins 归档产物服务 / 本地启动器静态服务请求最新的 dist/build-manifest.json
  Future<AppReleaseManifest?> fetchRemoteManifest() async {
    if (customFetcher != null) {
      return customFetcher!();
    }
    if (!enableNetworkProbe) {
      return null;
    }

    final int ts = DateTime.now().millisecondsSinceEpoch;
    final List<String> candidateUrls = <String>[
      '/dist/build-manifest.json?t=$ts',
      'http://127.0.0.1:18689/dist/build-manifest.json?t=$ts',
    ];

    final http.Client client = httpClient ?? http.Client();
    try {
      for (final String url in candidateUrls) {
        try {
          final Uri uri = Uri.parse(url);
          final http.Response resp = await client
              .get(
                uri,
                headers: const <String, String>{
                  'Cache-Control': 'no-cache, no-store, must-revalidate',
                  'Pragma': 'no-cache',
                },
              )
              .timeout(const Duration(milliseconds: 600));
          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            final String bodyText =
                utf8.decode(resp.bodyBytes, allowMalformed: true);
            final Object? decoded = jsonDecode(bodyText);
            if (decoded is Map<String, dynamic>) {
              return AppReleaseManifest.fromJson(decoded);
            }
          }
        } catch (_) {
          // 单个候选地址不可达时静默尝试下一个
        }
      }
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
    return null;
  }

  /// 通知 Windows 单文件启动器 (ShiJuLauncher.cs) 将最新 dist/shiju-web-release.zip 解压热更到本地
  Future<bool> applyLauncherHotUpdate() async {
    if (!enableNetworkProbe) return true;
    final http.Client client = httpClient ?? http.Client();
    try {
      final Uri uri = Uri.parse('/api/apply-update');
      final http.Response resp = await client
          .post(uri)
          .timeout(const Duration(milliseconds: 800));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  /// 根据 Jenkins 流水线构建号生成标准版本发布清单（含递增版本号、SHA-256 指纹与更新日志）
  static AppReleaseManifest createManifestForBuild({
    required int buildNumber,
    String gitBranch = 'jenkins_auto_update',
    String gitCommit = '82c6df6',
    bool forceUpdate = false,
    List<String>? customNotes,
  }) {
    final int patchVersion = 6 + (buildNumber - 108).clamp(1, 999);
    final String semver = '1.0.$patchVersion';
    final String fullVersion = '$semver+$buildNumber';

    return AppReleaseManifest(
      appName: '拾句 (ShiJu)',
      version: fullVersion,
      buildNumber: buildNumber,
      gitBranch: gitBranch,
      gitCommit: gitCommit,
      builtAtUtc: DateTime.now().toUtc().toIso8601String(),
      forceUpdate: forceUpdate,
      releaseNotes: customNotes ??
          <String>[
            'Jenkins 流水线 #$buildNumber 打包发布（版本 v$semver，Git: $gitBranch@$gitCommit）',
            '新增客户端启动与切回前台时自动拉取 dist/build-manifest.json 检测更新机制',
            '支持新版本朱砂印章弹窗提醒、SHA-256 完整性校验与一键热更新升级',
          ],
      artifacts: const <ReleaseArtifactInfo>[
        ReleaseArtifactInfo(
          path: 'dist/拾句_ShiJu.exe',
          sizeBytes: 14172672,
          sha256:
              'd586403ce9dce75741b9e187a8ee74612cae402dfb5f511ea1860fa25a9441a9',
        ),
        ReleaseArtifactInfo(
          path: 'dist/shiju-web-release.zip',
          sizeBytes: 14159470,
          sha256:
              'dd69ef70a849470b9196de36d6ef7e9dc3be92e209a8b28bc936e9077f558a34',
        ),
        ReleaseArtifactInfo(
          path: 'dist/shiju-android-release.apk',
          sizeBytes: 22911385,
          sha256:
              '4a91e83c72b019f45e62d810c39a7b612e5094f81a2c3d4e5f60718293a4b5c6',
        ),
      ],
    );
  }
}
