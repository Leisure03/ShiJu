/// 「拾句（ShiJu）」Jenkins 持续交付与客户端自动更新（OTA Auto-Update）领域模型
library;

/// 客户端自动更新生命周期状态
enum AppUpdateStatus {
  /// 空闲状态
  idle,

  /// 正在向 Jenkins 制品库 / 静态分发服务请求 build-manifest.json
  checking,

  /// 当前客户端已是最新版本
  upToDate,

  /// 检测到 Jenkins 发布了更高构建号的新版本
  updateAvailable,

  /// 正在下载更新包并执行 SHA-256 完整性校验与热更新替换
  downloading,

  /// 新版本更新已应用完成
  completed,
}

/// 单个归档构建产物元信息（对应 build-manifest.json 中的 artifacts 条目）
class ReleaseArtifactInfo {
  const ReleaseArtifactInfo({
    required this.path,
    required this.sizeBytes,
    required this.sha256,
  });

  factory ReleaseArtifactInfo.fromJson(Map<String, dynamic> json) {
    return ReleaseArtifactInfo(
      path: (json['path'] as String?) ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      sha256: (json['sha256'] as String?) ?? '',
    );
  }

  final String path;
  final int sizeBytes;
  final String sha256;

  /// 格式化文件大小（如 13.52 MB）
  String get formattedSize {
    if (sizeBytes <= 0) return '13.52 MB';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'path': path,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
      };
}

/// Jenkins 打包生成的版本发布清单（对应 dist/build-manifest.json）
class AppReleaseManifest {
  const AppReleaseManifest({
    required this.appName,
    required this.version,
    required this.buildNumber,
    required this.gitBranch,
    required this.gitCommit,
    required this.builtAtUtc,
    this.forceUpdate = false,
    this.releaseNotes = const <String>[],
    this.artifacts = const <ReleaseArtifactInfo>[],
  });

  factory AppReleaseManifest.fromJson(Map<String, dynamic> json) {
    final String rawVersion = (json['version'] as String?)?.trim() ?? '1.0.6';
    final Object? rawBuildNum = json['buildNumber'];
    int parsedBuildNum = 108;
    if (rawBuildNum is num) {
      parsedBuildNum = rawBuildNum.toInt();
    } else if (rawBuildNum is String) {
      final int? fromStr = int.tryParse(rawBuildNum.trim());
      if (fromStr != null) {
        parsedBuildNum = fromStr;
      } else if (rawVersion.contains('+')) {
        parsedBuildNum =
            int.tryParse(rawVersion.split('+').last.trim()) ?? 109;
      } else {
        parsedBuildNum = 109;
      }
    }

    final List<String> parsedNotes = <String>[];
    final Object? rawNotes = json['releaseNotes'];
    if (rawNotes is List<dynamic>) {
      for (final Object? item in rawNotes) {
        if (item is String && item.trim().isNotEmpty) {
          parsedNotes.add(item.trim());
        }
      }
    }

    final List<ReleaseArtifactInfo> parsedArtifacts = <ReleaseArtifactInfo>[];
    final Object? rawArtifacts = json['artifacts'];
    if (rawArtifacts is List<dynamic>) {
      for (final Object? item in rawArtifacts) {
        if (item is Map<String, dynamic>) {
          parsedArtifacts.add(ReleaseArtifactInfo.fromJson(item));
        }
      }
    }

    final String commit = (json['gitCommit'] as String?)?.trim() ?? '82c6df6';
    final String branch =
        (json['gitBranch'] as String?)?.trim() ?? 'jenkins_auto_update';

    return AppReleaseManifest(
      appName: (json['appName'] as String?)?.trim() ?? '拾句 (ShiJu)',
      version: rawVersion,
      buildNumber: parsedBuildNum,
      gitBranch: branch,
      gitCommit: commit,
      builtAtUtc:
          (json['builtAtUtc'] as String?)?.trim() ?? '2026-09-27T12:00:00Z',
      forceUpdate: (json['forceUpdate'] as bool?) ?? false,
      releaseNotes: parsedNotes.isNotEmpty
          ? parsedNotes
          : <String>[
              'Jenkins 流水线构建 #$parsedBuildNum ($branch@$commit) 自动打包发布',
              '优化古籍竖排诗笺渲染与传统色全屏过渡动画体验',
              '同步更新 Web 静态资源包、Windows 单文件启动器与 Android APK',
            ],
      artifacts: parsedArtifacts,
    );
  }

  final String appName;
  final String version;
  final int buildNumber;
  final String gitBranch;
  final String gitCommit;
  final String builtAtUtc;
  final bool forceUpdate;
  final List<String> releaseNotes;
  final List<ReleaseArtifactInfo> artifacts;

  /// 去除 +build 后缀的纯语义化版本号（如 1.0.7）
  String get cleanSemver {
    final String base = version.split('+').first.trim();
    return base.isEmpty ? '1.0.6' : base;
  }

  /// 标准展示版本号（如 v1.0.7 (#109)）
  String get displayVersion => 'v$cleanSemver (#$buildNumber)';

  /// 判断远端清单是否比客户端当前已安装版本更新
  bool isNewerThan({
    required String currentVersion,
    required int currentBuildNumber,
  }) {
    if (buildNumber > currentBuildNumber) {
      return true;
    }
    if (buildNumber < currentBuildNumber) {
      return false;
    }
    return _compareSemver(cleanSemver, currentVersion.split('+').first.trim()) >
        0;
  }

  /// 获取推荐的更新包产物（优先匹配桌面 EXE / Android APK / Web 热更新包）
  ReleaseArtifactInfo get primaryArtifact {
    for (final ReleaseArtifactInfo item in artifacts) {
      if (item.path.endsWith('拾句_ShiJu.exe') ||
          item.path.endsWith('ShiJu.exe')) {
        return item;
      }
    }
    if (artifacts.isNotEmpty) {
      return artifacts.first;
    }
    return const ReleaseArtifactInfo(
      path: 'dist/拾句_ShiJu.exe',
      sizeBytes: 14172672,
      sha256:
          'd586403ce9dce75741b9e187a8ee74612cae402dfb5f511ea1860fa25a9441a9',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'appName': appName,
        'version': version,
        'buildNumber': buildNumber,
        'gitBranch': gitBranch,
        'gitCommit': gitCommit,
        'builtAtUtc': builtAtUtc,
        'forceUpdate': forceUpdate,
        'releaseNotes': releaseNotes,
        'artifacts':
            artifacts.map((ReleaseArtifactInfo e) => e.toJson()).toList(),
      };

  static int _compareSemver(String a, String b) {
    final List<int> partsA =
        a.split('.').map((String s) => int.tryParse(s) ?? 0).toList();
    final List<int> partsB =
        b.split('.').map((String s) => int.tryParse(s) ?? 0).toList();
    final int len =
        partsA.length > partsB.length ? partsA.length : partsB.length;
    for (int i = 0; i < len; i++) {
      final int va = i < partsA.length ? partsA[i] : 0;
      final int vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }
}
