import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/services/app_update_service.dart';
import '../../../../domain/models/app_update_model.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/traditional_palette.dart';
import '../../../core/widgets/cinnabar_seal.dart';
import '../../../core/widgets/xuan_paper_card.dart';
import '../../shiju_view_model.dart';
import '../utils/artifact_downloader.dart';

/// 流水线阶段执行状态
enum PipelineStageStatus {
  success,
  running,
  pending,
  skipped,
}

/// 单个 Jenkins 流水线阶段数据模型
class PipelineStageInfo {
  const PipelineStageInfo({
    required this.id,
    required this.titleCn,
    required this.stageKey,
    required this.commandPreview,
    required this.durationText,
    required this.status,
    required this.logs,
  });

  final String id;
  final String titleCn;
  final String stageKey;
  final String commandPreview;
  final String durationText;
  final PipelineStageStatus status;
  final List<String> logs;

  PipelineStageInfo copyWith({
    String? durationText,
    PipelineStageStatus? status,
    List<String>? logs,
  }) {
    return PipelineStageInfo(
      id: id,
      titleCn: titleCn,
      stageKey: stageKey,
      commandPreview: commandPreview,
      durationText: durationText ?? this.durationText,
      status: status ?? this.status,
      logs: logs ?? this.logs,
    );
  }
}

/// 归档产物条目模型
class PipelineArtifactItem {
  const PipelineArtifactItem({
    required this.path,
    required this.category,
    required this.sizeText,
    required this.sha256,
    required this.enabled,
  });

  final String path;
  final String category;
  final String sizeText;
  final String sha256;
  final bool enabled;
}

/// 「拾句（ShiJu）」Jenkins 持续集成流水线可视化中心视图
class JenkinsPipelineView extends StatefulWidget {
  const JenkinsPipelineView({
    super.key,
    required this.viewModel,
  });

  final ShiJuViewModel viewModel;

  @override
  State<JenkinsPipelineView> createState() => _JenkinsPipelineViewState();
}

class _JenkinsPipelineViewState extends State<JenkinsPipelineView> {
  // 参数化构建开关（对应 Jenkinsfile parameters）
  bool _paramRunTests = true;
  bool _paramBuildWebAndLauncher = true;
  bool _paramBuildWindowsNative = true;
  bool _paramBuildAndroidApk = true;
  bool _paramCleanBuild = false;
  bool _paramStrictToolchain = false;

  bool _isRunningPipeline = false;
  int _buildNumber = 108;
  int _selectedStageIndex = 0;
  int _activeDetailTab = 0; // 0: 归档产物, 1: JUnit 测试报告, 2: 控制台日志与 Jenkinsfile
  Timer? _pipelineTimer;

  late List<PipelineStageInfo> _stages;

  @override
  void initState() {
    super.initState();
    final int currentInstalled = widget.viewModel.currentBuildNumber;
    final int latestKnown =
        widget.viewModel.latestManifest?.buildNumber ?? currentInstalled;
    _buildNumber = latestKnown > 108 ? latestKnown : 108;
    _stages = _buildInitialStages();
  }

  @override
  void dispose() {
    _pipelineTimer?.cancel();
    super.dispose();
  }

  List<PipelineStageInfo> _buildInitialStages() {
    return <PipelineStageInfo>[
      const PipelineStageInfo(
        id: 'env_check',
        titleCn: '环境与工具链自检',
        stageKey: 'Checkout & Env Check',
        commandPreview: 'ci/run_pipeline.ps1 -Stage EnvCheck',
        durationText: '1.2s',
        status: PipelineStageStatus.success,
        logs: <String>[
          '[ShiJu CI/CD] Stage 1: Environment & Toolchain Check',
          'Project Root : C:\\jenkins\\workspace\\shiju-pipeline',
          'App Version  : 1.0.0+1',
          'Git Ref      : extend_jenkins_pipeline (35f7adb)',
          'Flutter 3.44.9 • channel stable • Dart 3.12.2 (windows_x64)',
          'Toolchains   : .NET csc.exe = Ready | Chrome Web = Ready | Android SDK = Ready',
        ],
      ),
      PipelineStageInfo(
        id: 'setup',
        titleCn: '依赖获取与初始化',
        stageKey: 'Install Dependencies',
        commandPreview: _paramCleanBuild
            ? 'ci/run_pipeline.ps1 -Stage Setup -Clean'
            : 'ci/run_pipeline.ps1 -Stage Setup',
        durationText: '2.4s',
        status: PipelineStageStatus.success,
        logs: <String>[
          '[ShiJu CI/CD] Stage 2: Setup & Install Dependencies',
          if (_paramCleanBuild) 'Running flutter clean... Done.',
          'Running flutter pub get...',
          'Resolving dependencies in pubspec.yaml...',
          'Got dependencies! Workspace dist/ and build/reports/ initialized.',
        ],
      ),
      PipelineStageInfo(
        id: 'analyze',
        titleCn: '静态代码分析',
        stageKey: 'Static Analysis',
        commandPreview: 'ci/run_pipeline.ps1 -Stage Analyze',
        durationText: _paramRunTests ? '1.3s' : '0.0s',
        status: _paramRunTests
            ? PipelineStageStatus.success
            : PipelineStageStatus.skipped,
        logs: <String>[
          '[ShiJu CI/CD] Stage 3: Dart & Flutter Static Analysis',
          'Executing: flutter analyze --no-fatal-infos',
          'Analyzing shiju (lib/, test/, ci/)...',
          'No issues found! (ran in 1.3s)',
          '[OK] Static analysis passed.',
        ],
      ),
      PipelineStageInfo(
        id: 'test',
        titleCn: '单元测试与 JUnit 报告',
        stageKey: 'Unit & Widget Tests',
        commandPreview: 'ci/run_pipeline.ps1 -Stage Test',
        durationText: _paramRunTests ? '1.6s' : '0.0s',
        status: _paramRunTests
            ? PipelineStageStatus.success
            : PipelineStageStatus.skipped,
        logs: <String>[
          '[ShiJu CI/CD] Stage 4: Unit & Widget Tests + Coverage + JUnit Report',
          'Executing: flutter test --coverage --file-reporter=json:build/reports/test-results.json',
          '00:00 +6: All tests passed! (6 test cases in test/widget_test.dart)',
          '[JUnit Converter] 已生成 JUnit XML 报告: build/reports/junit-report.xml (共 6 个用例, 失败 0)',
          '[Coverage] 已生成覆盖率报告: coverage/lcov.info (18,547 bytes)',
        ],
      ),
      PipelineStageInfo(
        id: 'web_launcher',
        titleCn: 'Web 与单文件 EXE 打包',
        stageKey: 'Build Web & Single-File EXE',
        commandPreview: 'ci/run_pipeline.ps1 -Stage BuildWebLauncher',
        durationText: _paramBuildWebAndLauncher ? '19.0s' : '0.0s',
        status: _paramBuildWebAndLauncher
            ? PipelineStageStatus.success
            : PipelineStageStatus.skipped,
        logs: <String>[
          '[ShiJu CI/CD] Stage 5: Build Flutter Web & Windows Single-File Launcher EXE',
          '1. Icons updated (transparent favicon + Cinnabar Seal app icons).',
          'Compiling lib/main.dart for the Web... 19.0s (√ Built build/web)',
          '2. Embedded bundle created: launcher/web_bundle.zip',
          '3. Compiled standalone executables: dist/拾句_ShiJu.exe & dist/ShiJu.exe (14.17 MB)',
          '[OK] Packaged Web release bundle: dist/shiju-web-release.zip (14.16 MB)',
        ],
      ),
      PipelineStageInfo(
        id: 'windows_native',
        titleCn: 'Windows 原生桌面端',
        stageKey: 'Build Windows Native',
        commandPreview: 'ci/run_pipeline.ps1 -Stage BuildWindowsNative',
        durationText: _paramBuildWindowsNative ? '14.5s' : '0.0s',
        status: _paramBuildWindowsNative
            ? PipelineStageStatus.success
            : PipelineStageStatus.skipped,
        logs: <String>[
          '[ShiJu CI/CD] Stage 6: Build Windows Native Desktop App (flutter build windows)',
          'Toolchain detection: Visual Studio C++ Desktop workload verified.',
          'Building Windows application (x64 Release)...',
          '[OK] Packaged Windows native desktop bundle: dist/shiju-windows-native-x64.zip',
        ],
      ),
      PipelineStageInfo(
        id: 'android_apk',
        titleCn: 'Android APK 安装包',
        stageKey: 'Build Android APK',
        commandPreview: 'ci/run_pipeline.ps1 -Stage BuildAndroidApk',
        durationText: _paramBuildAndroidApk ? '26.8s' : '0.0s',
        status: _paramBuildAndroidApk
            ? PipelineStageStatus.success
            : PipelineStageStatus.skipped,
        logs: <String>[
          '[ShiJu CI/CD] Stage 7: Build Android Release APK (flutter build apk)',
          'Android SDK (36.1.0) detected at D:\\asSDK',
          'Running Gradle task assembleRelease...',
          '√ Built build/app/outputs/flutter-apk/app-release.apk',
          '[OK] Packaged Android release APK: dist/shiju-android-release.apk',
        ],
      ),
      const PipelineStageInfo(
        id: 'archive',
        titleCn: '产物归档与 SHA-256 校验',
        stageKey: 'Package & Checksums',
        commandPreview: 'ci/run_pipeline.ps1 -Stage Archive',
        durationText: '0.8s',
        status: PipelineStageStatus.success,
        logs: <String>[
          '[ShiJu CI/CD] Stage 8: Generate Build Manifest & SHA-256 Checksums',
          'Computed SHA-256 hashes for all artifacts in dist/ -> dist/SHA256SUMS.txt',
          'Generated metadata manifest -> dist/build-manifest.json',
          'Jenkins post.always: archiveArtifacts(artifacts: "dist/**/*, coverage/lcov.info", fingerprint: true)',
          '✅ [ShiJu CI/CD] 拾句 Jenkins 流水线执行成功，产物已归档至 dist/ 目录！',
        ],
      ),
    ];
  }

  /// 点击「触发流水线构建」模拟完整 8 阶段动态流水线执行过程，并在归档完成后自动推送新版本更新提示
  void _triggerPipelineRun() {
    if (_isRunningPipeline) return;
    _pipelineTimer?.cancel();

    final List<PipelineStageInfo> template = _buildInitialStages();
    final List<bool> shouldRun = <bool>[
      true,
      true,
      _paramRunTests,
      _paramRunTests,
      _paramBuildWebAndLauncher,
      _paramBuildWindowsNative,
      _paramBuildAndroidApk,
      true,
    ];

    setState(() {
      _isRunningPipeline = true;
      _buildNumber += 1;
      _selectedStageIndex = 0;
      _stages = List<PipelineStageInfo>.generate(template.length, (int i) {
        return template[i].copyWith(
          status: i == 0
              ? PipelineStageStatus.running
              : (shouldRun[i]
                  ? PipelineStageStatus.pending
                  : PipelineStageStatus.skipped),
        );
      });
    });

    int currentIdx = 0;
    _pipelineTimer = Timer.periodic(const Duration(milliseconds: 380), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _stages[currentIdx] = template[currentIdx].copyWith(
          status: shouldRun[currentIdx]
              ? PipelineStageStatus.success
              : PipelineStageStatus.skipped,
        );

        currentIdx += 1;
        while (currentIdx < _stages.length && !shouldRun[currentIdx]) {
          _stages[currentIdx] = template[currentIdx].copyWith(
            status: PipelineStageStatus.skipped,
            durationText: '0.0s',
          );
          currentIdx += 1;
        }

        if (currentIdx < _stages.length) {
          _selectedStageIndex = currentIdx;
          _stages[currentIdx] = template[currentIdx].copyWith(
            status: PipelineStageStatus.running,
          );
        } else {
          _isRunningPipeline = false;
          _selectedStageIndex = _stages.length - 1;
          timer.cancel();

          // Stage 8 归档完成：生成新的 dist/build-manifest.json 并触发客户端新版本自动弹窗
          final AppReleaseManifest manifest =
              AppUpdateService.createManifestForBuild(
            buildNumber: _buildNumber,
          );
          unawaited(
            widget.viewModel.publishJenkinsBuildManifest(
              manifest,
              autoPopup: true,
            ),
          );
        }
      });
    });
  }

  /// 一键模拟「Jenkins 打包完成 -> 用户再次进入软件首页 -> 自动弹出更新提示」完整闭环
  Future<void> _simulatePackAndReenterApp() async {
    _pipelineTimer?.cancel();
    final int nextBuild = (_buildNumber > widget.viewModel.currentBuildNumber
            ? _buildNumber
            : widget.viewModel.currentBuildNumber) +
        1;
    setState(() {
      _isRunningPipeline = false;
      _buildNumber = nextBuild;
      _stages = _buildInitialStages();
      _selectedStageIndex = _stages.length - 1;
    });

    final AppReleaseManifest manifest = AppUpdateService.createManifestForBuild(
      buildNumber: nextBuild,
    );
    await widget.viewModel.publishJenkinsBuildManifest(
      manifest,
      autoPopup: true,
    );
    // 切换回「拾句」首页，还原用户重新打开进入软件自动弹出更新提示的场景
    widget.viewModel.setActiveTab(ShiJuNavTab.home);
  }

  void _copyText(String text, String toastLabel) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final TraditionalPalette palette = widget.viewModel.activePalette;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已复制：$toastLabel',
          style: AppTypography.label(palette.onCinnabar, fontSize: 13),
        ),
        backgroundColor: palette.cinnabarRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _downloadArtifact(PipelineArtifactItem item) {
    triggerArtifactDownload(item.path);
    if (!mounted) return;
    final TraditionalPalette palette = widget.viewModel.activePalette;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '正在下载构建产物：${item.path}',
          style: AppTypography.label(palette.onCinnabar, fontSize: 13),
        ),
        backgroundColor: palette.cinnabarRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _revealArtifact(PipelineArtifactItem item) async {
    final bool opened = await revealArtifactInExplorer(item.path);
    if (!mounted) return;
    if (!opened) {
      _downloadArtifact(item);
      return;
    }
    final TraditionalPalette palette = widget.viewModel.activePalette;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已在资源管理器中定位：${item.path}',
          style: AppTypography.label(palette.onCinnabar, fontSize: 13),
        ),
        backgroundColor: palette.cinnabarRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<PipelineArtifactItem> get _artifacts => <PipelineArtifactItem>[
        PipelineArtifactItem(
          path: 'dist/拾句_ShiJu.exe',
          category: 'Windows 单文件启动器 (中文名)',
          sizeText: '13.52 MB (14,172,672 B)',
          sha256: 'd586403ce9dce75741b9e187a8ee74612cae402dfb5f511ea1860fa25a9441a9',
          enabled: _paramBuildWebAndLauncher,
        ),
        PipelineArtifactItem(
          path: 'dist/ShiJu.exe',
          category: 'Windows 单文件启动器 (英文名)',
          sizeText: '13.52 MB (14,172,672 B)',
          sha256: 'd586403ce9dce75741b9e187a8ee74612cae402dfb5f511ea1860fa25a9441a9',
          enabled: _paramBuildWebAndLauncher,
        ),
        PipelineArtifactItem(
          path: 'dist/shiju-web-release.zip',
          category: 'Flutter Web 静态资源发布包',
          sizeText: '13.50 MB (14,159,470 B)',
          sha256: 'dd69ef70a849470b9196de36d6ef7e9dc3be92e209a8b28bc936e9077f558a34',
          enabled: _paramBuildWebAndLauncher,
        ),
        PipelineArtifactItem(
          path: 'dist/shiju-windows-native-x64.zip',
          category: 'Windows 原生桌面应用包 (x64)',
          sizeText: '18.40 MB (19,293,798 B)',
          sha256: '8f4c2109b7e34a19d82c6509f1e28a4bc721094e8a1b5c3d902184ef7a6b3102',
          enabled: _paramBuildWindowsNative,
        ),
        PipelineArtifactItem(
          path: 'dist/shiju-android-release.apk',
          category: 'Android Release 安装包 (APK)',
          sizeText: '21.85 MB (22,911,385 B)',
          sha256: '4a91e83c72b019f45e62d810c39a7b612e5094f81a2c3d4e5f60718293a4b5c6',
          enabled: _paramBuildAndroidApk,
        ),
        PipelineArtifactItem(
          path: 'dist/reports/junit-report.xml',
          category: 'Jenkins JUnit 标准测试报告',
          sizeText: '1.51 KB (1,543 B)',
          sha256: '2b44dc6e30f88066f32fcd1a4fc973d6a9f50c14ae73601d6e7cfa17a181fbd8',
          enabled: _paramRunTests,
        ),
        PipelineArtifactItem(
          path: 'dist/reports/lcov.info',
          category: 'LCOV 单元测试覆盖率报告',
          sizeText: '18.11 KB (18,547 B)',
          sha256: '3cdbc057b772d0608be6d21dba70a4d4ab52795ac0cf9f8f8e4a5d6142a6b347',
          enabled: _paramRunTests,
        ),
        const PipelineArtifactItem(
          path: 'dist/build-manifest.json',
          category: '构建元数据与指纹清单',
          sizeText: '1.54 KB (1,573 B)',
          sha256: '9e17b34c82d10a56f9012e34b56c78d9012a34b56c78d9012e34a56b78c9012d',
          enabled: true,
        ),
        const PipelineArtifactItem(
          path: 'dist/SHA256SUMS.txt',
          category: '全量产物 SHA-256 校验和清单',
          sizeText: '427 B',
          sha256: 'f0123a45b67c89d0123e45f67a89b0123c45d67e89f0123a45b67c89d0123e45',
          enabled: true,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final TraditionalPalette palette = widget.viewModel.activePalette;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 1. 顶部概览与触发构建卡片
              _buildPipelineHeaderCard(palette),
              const SizedBox(height: 18),

              // 2. 参数化构建配置面板 (Build with Parameters)
              _buildParametersCard(palette),
              const SizedBox(height: 18),

              // 3. 8 阶段流水线全景拓扑图 (Blue Ocean 风格)
              _buildStageGraphCard(palette),
              const SizedBox(height: 18),

              // 4. 多维详情面板：归档产物 / JUnit 报告 / 控制台与 Jenkinsfile
              _buildDetailTabsCard(palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPipelineHeaderCard(TraditionalPalette palette) {
    final int passedStages = _stages
        .where((PipelineStageInfo s) => s.status == PipelineStageStatus.success)
        .length;

    return XuanPaperCard(
      palette: palette,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CinnabarSeal(
                    text: '天工',
                    style: SealStyle.yin,
                    fontSize: 12,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Jenkins 持续集成流水线 · 拾句 (ShiJu)',
                          style: AppTypography.sectionHeading(
                            palette.inkText,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Declarative Pipeline (Jenkinsfile) · 打包归档后客户端自动检测并弹窗热更新',
                          style: AppTypography.attribution(
                            palette.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 触发构建与模拟客户端热更新弹窗按钮组
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  InkWell(
                    key: const Key('simulate_jenkins_ota_update_button'),
                    onTap: _simulatePackAndReenterApp,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9.5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.cinnabarRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: palette.cinnabarRed,
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.system_update_alt_rounded,
                            size: 16,
                            color: palette.cinnabarRed,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '打包并模拟重进软件弹更新窗',
                            style: AppTypography.label(
                              palette.cinnabarRed,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    key: const Key('trigger_jenkins_build_button'),
                    onTap: _isRunningPipeline ? null : _triggerPipelineRun,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _isRunningPipeline
                            ? palette.themeAccent.withValues(alpha: 0.5)
                            : palette.cinnabarRed,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _isRunningPipeline
                                ? Icons.sync_rounded
                                : Icons.play_arrow_rounded,
                            size: 17,
                            color: palette.onCinnabar,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isRunningPipeline
                                ? '流水线构建中 (#$_buildNumber)...'
                                : '立即构建 (Build Now)',
                            style: AppTypography.label(
                              palette.onCinnabar,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          Container(height: 0.6, color: palette.borderLine),
          const SizedBox(height: 14),

          // 元信息指标栏
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: <Widget>[
              _buildMetaBadge(
                palette: palette,
                icon: Icons.verified_outlined,
                label: '构建状态',
                value: _isRunningPipeline
                    ? '#$_buildNumber RUNNING'
                    : '#$_buildNumber SUCCESS ($passedStages/${_stages.length} 阶段)',
                highlight: true,
              ),
              _buildMetaBadge(
                palette: palette,
                icon: Icons.devices_other_rounded,
                label: '客户端已装版本',
                value: widget.viewModel.currentDisplayVersion,
              ),
              _buildMetaBadge(
                palette: palette,
                icon: Icons.commit_rounded,
                label: 'Git 分支与提交',
                value: 'jenkins_auto_update (82c6df6)',
              ),
              _buildMetaBadge(
                palette: palette,
                icon: Icons.inventory_2_outlined,
                label: '自动更新清单',
                value: 'dist/build-manifest.json',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaBadge({
    required TraditionalPalette palette,
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: 15,
          color: highlight ? palette.cinnabarRed : palette.mutedText,
        ),
        const SizedBox(width: 6),
        Text(
          '$label：',
          style: AppTypography.label(palette.mutedText, fontSize: 12.5),
        ),
        Text(
          value,
          style: AppTypography.label(
            highlight ? palette.cinnabarRed : palette.inkText,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildParametersCard(TraditionalPalette palette) {
    return XuanPaperCard(
      palette: palette,
      padding: const EdgeInsets.all(20),
      showCornerOrnaments: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: palette.cinnabarRed,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '参数化构建配置 (Jenkinsfile Parameters)',
                    style: AppTypography.sectionHeading(
                      palette.inkText,
                      fontSize: 15.5,
                    ),
                  ),
                ],
              ),
              Text(
                '勾选后点击上方「立即构建」生效',
                style: AppTypography.label(palette.mutedText, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _buildParamToggleChip(
                key: const Key('param_chip_run_tests'),
                palette: palette,
                title: 'RUN_TESTS',
                subtitle: '静态分析 + 单元测试与 JUnit 报告',
                value: _paramRunTests,
                onChanged: (bool val) => setState(() {
                  _paramRunTests = val;
                  _stages = _buildInitialStages();
                }),
              ),
              _buildParamToggleChip(
                key: const Key('param_chip_build_web_exe'),
                palette: palette,
                title: 'BUILD_WEB_AND_LAUNCHER',
                subtitle: 'Web 静态包 + 拾句_ShiJu.exe 单文件版',
                value: _paramBuildWebAndLauncher,
                onChanged: (bool val) => setState(() {
                  _paramBuildWebAndLauncher = val;
                  _stages = _buildInitialStages();
                }),
              ),
              _buildParamToggleChip(
                key: const Key('param_chip_build_win_native'),
                palette: palette,
                title: 'BUILD_WINDOWS_NATIVE',
                subtitle: 'Windows 原生桌面应用 (x64)',
                value: _paramBuildWindowsNative,
                onChanged: (bool val) => setState(() {
                  _paramBuildWindowsNative = val;
                  _stages = _buildInitialStages();
                }),
              ),
              _buildParamToggleChip(
                key: const Key('param_chip_build_android_apk'),
                palette: palette,
                title: 'BUILD_ANDROID_APK',
                subtitle: 'Android 安装包 (app-release.apk)',
                value: _paramBuildAndroidApk,
                onChanged: (bool val) => setState(() {
                  _paramBuildAndroidApk = val;
                  _stages = _buildInitialStages();
                }),
              ),
              _buildParamToggleChip(
                key: const Key('param_chip_clean_build'),
                palette: palette,
                title: 'CLEAN_BUILD',
                subtitle: '构建前执行 flutter clean',
                value: _paramCleanBuild,
                onChanged: (bool val) => setState(() {
                  _paramCleanBuild = val;
                  _stages = _buildInitialStages();
                }),
              ),
              _buildParamToggleChip(
                key: const Key('param_chip_strict_toolchain'),
                palette: palette,
                title: 'STRICT_TOOLCHAIN',
                subtitle: '严格原生工具链检查',
                value: _paramStrictToolchain,
                onChanged: (bool val) => setState(() {
                  _paramStrictToolchain = val;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParamToggleChip({
    required Key key,
    required TraditionalPalette palette,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      key: key,
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value
              ? palette.cinnabarRed.withValues(alpha: 0.12)
              : palette.elevatedSurface.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: value ? palette.cinnabarRed : palette.borderLine,
            width: value ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              value
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 16,
              color: value ? palette.cinnabarRed : palette.mutedText,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTypography.label(
                    palette.inkText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.label(
                    palette.secondaryText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageGraphCard(TraditionalPalette palette) {
    final PipelineStageInfo selectedStage = _stages[_selectedStageIndex];

    return XuanPaperCard(
      palette: palette,
      padding: const EdgeInsets.all(22),
      showCornerOrnaments: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.account_tree_outlined,
                size: 16,
                color: palette.cinnabarRed,
              ),
              const SizedBox(width: 8),
              Text(
                '流水线阶段拓扑 (Pipeline Stage View · 点击节点查看日志)',
                style: AppTypography.sectionHeading(
                  palette.inkText,
                  fontSize: 15.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 8 个阶段节点矩阵
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List<Widget>.generate(_stages.length, (int idx) {
              final PipelineStageInfo stage = _stages[idx];
              final bool isSelected = idx == _selectedStageIndex;

              return InkWell(
                key: Key('pipeline_stage_node_${stage.id}'),
                onTap: () => setState(() {
                  _selectedStageIndex = idx;
                }),
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 210,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? palette.cinnabarRed.withValues(alpha: 0.14)
                        : palette.elevatedSurface.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? palette.cinnabarRed
                          : palette.borderLine,
                      width: isSelected ? 1.4 : 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _buildStageStatusIcon(stage.status, palette),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${idx + 1}. ${stage.titleCn}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label(
                                palette.inkText,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stage.stageKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label(
                          palette.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            _statusLabel(stage.status),
                            style: AppTypography.label(
                              stage.status == PipelineStageStatus.skipped
                                  ? palette.mutedText
                                  : palette.cinnabarRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            stage.durationText,
                            style: AppTypography.label(
                              palette.mutedText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),
          // 当前选中阶段的快捷日志预览盒
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.background.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: palette.borderLine, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      '当前阶段：${selectedStage.stageKey} (${selectedStage.titleCn})',
                      style: AppTypography.label(
                        palette.inkText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      selectedStage.commandPreview,
                      style: AppTypography.label(
                        palette.mutedText,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...selectedStage.logs.map(
                  (String line) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '> $line',
                      style: AppTypography.label(
                        palette.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageStatusIcon(
    PipelineStageStatus status,
    TraditionalPalette palette,
  ) {
    switch (status) {
      case PipelineStageStatus.success:
        return Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: palette.cinnabarRed,
        );
      case PipelineStageStatus.running:
        return Icon(
          Icons.timelapse_rounded,
          size: 16,
          color: palette.cinnabarRed,
        );
      case PipelineStageStatus.pending:
        return Icon(
          Icons.schedule_rounded,
          size: 16,
          color: palette.mutedText,
        );
      case PipelineStageStatus.skipped:
        return Icon(
          Icons.remove_circle_outline_rounded,
          size: 16,
          color: palette.mutedText,
        );
    }
  }

  String _statusLabel(PipelineStageStatus status) {
    switch (status) {
      case PipelineStageStatus.success:
        return 'PASSED';
      case PipelineStageStatus.running:
        return 'RUNNING';
      case PipelineStageStatus.pending:
        return 'PENDING';
      case PipelineStageStatus.skipped:
        return 'SKIPPED';
    }
  }

  Widget _buildDetailTabsCard(TraditionalPalette palette) {
    return XuanPaperCard(
      palette: palette,
      padding: const EdgeInsets.all(22),
      showCornerOrnaments: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 顶部 Tab 切换栏
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: <Widget>[
              _buildDetailTabButton(
                key: const Key('pipeline_tab_artifacts'),
                index: 0,
                label: '构建归档产物 (dist/)',
                icon: Icons.folder_zip_outlined,
                palette: palette,
              ),
              _buildDetailTabButton(
                key: const Key('pipeline_tab_junit'),
                index: 1,
                label: 'JUnit 测试与覆盖率报告 (6/6)',
                icon: Icons.fact_check_outlined,
                palette: palette,
              ),
              _buildDetailTabButton(
                key: const Key('pipeline_tab_jenkinsfile'),
                index: 2,
                label: 'Jenkinsfile 与本地流水线命令',
                icon: Icons.terminal_rounded,
                palette: palette,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 0.6, color: palette.borderLine),
          const SizedBox(height: 16),

          if (_activeDetailTab == 0) _buildArtifactsTabContent(palette),
          if (_activeDetailTab == 1) _buildJunitTabContent(palette),
          if (_activeDetailTab == 2) _buildJenkinsfileTabContent(palette),
        ],
      ),
    );
  }

  Widget _buildDetailTabButton({
    required Key key,
    required int index,
    required String label,
    required IconData icon,
    required TraditionalPalette palette,
  }) {
    final bool selected = _activeDetailTab == index;
    return InkWell(
      key: key,
      onTap: () => setState(() {
        _activeDetailTab = index;
      }),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? palette.cinnabarRed
              : palette.elevatedSurface.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 15,
              color: selected ? palette.onCinnabar : palette.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.label(
                selected ? palette.onCinnabar : palette.inkText,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtifactsTabContent(TraditionalPalette palette) {
    final List<PipelineArtifactItem> activeItems = _artifacts
        .where((PipelineArtifactItem item) => item.enabled)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Jenkins archiveArtifacts 已归档产物清单（点击「下载」或条目可直接下载安装包）：',
          style: AppTypography.label(
            palette.secondaryText,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        ...activeItems.map((PipelineArtifactItem item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              key: Key('artifact_row_${item.path}'),
              onTap: () => _downloadArtifact(item),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.elevatedSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: palette.borderLine, width: 0.8),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 18,
                      color: palette.cinnabarRed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              Text(
                                item.path,
                                style: AppTypography.label(
                                  palette.inkText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                item.category,
                                style: AppTypography.label(
                                  palette.secondaryText,
                                  fontSize: 11.5,
                                ),
                              ),
                              Text(
                                item.sizeText,
                                style: AppTypography.label(
                                  palette.mutedText,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SHA256: ${item.sha256}',
                            style: AppTypography.label(
                              palette.mutedText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 下载按钮
                    InkWell(
                      key: Key('download_btn_${item.path}'),
                      onTap: () => _downloadArtifact(item),
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: palette.cinnabarRed,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.download_rounded,
                              size: 14,
                              color: palette.onCinnabar,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '下载',
                              style: AppTypography.label(
                                palette.onCinnabar,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: '在资源管理器中显示文件',
                      onPressed: () => _revealArtifact(item),
                      icon: Icon(
                        Icons.folder_open_rounded,
                        size: 16,
                        color: palette.secondaryText,
                      ),
                    ),
                    IconButton(
                      tooltip: '复制 SHA-256 校验值',
                      onPressed: () =>
                          _copyText(item.sha256, '${item.path} SHA256'),
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: palette.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildJunitTabContent(TraditionalPalette palette) {
    const List<Map<String, String>> testCases = <Map<String, String>>[
      <String, String>{
        'name': '拾句 (ShiJu) 核心领域与工具测试 · 十二时辰计算器能准确映射古代时辰与应景导语',
        'time': '0.012s',
      },
      <String, String>{
        'name': '拾句 (ShiJu) 核心领域与工具测试 · 奶雾蔷薇与雾灰藕紫双生色板解析准确',
        'time': '0.003s',
      },
      <String, String>{
        'name': '拾句 (ShiJu) 核心领域与工具测试 · LocalStorageService 持久化保存收藏列表、阅读历史与横竖排偏好',
        'time': '0.005s',
      },
      <String, String>{
        'name': '拾句 (ShiJu) UI 与三大模块交互测试 · 模块一：首页名句卡片展示、横竖排切换、漫游切换与空格快捷键',
        'time': '0.651s',
      },
      <String, String>{
        'name': '拾句 (ShiJu) UI 与三大模块交互测试 · 模块二：点击名句卡片展开详情页、名句朱砂高亮、赏析Tab切换与同作者作品聚合',
        'time': '0.257s',
      },
      <String, String>{
        'name': '拾句 (ShiJu) UI 与三大模块交互测试 · 模块三：寻章摘句实时搜索、意境标签筛选、藏书阁收藏移除与诗笺海报弹窗',
        'time': '0.650s',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'JUnit 测试套件报告 (build/reports/junit-report.xml) · 共 6 项通过，0 失败，静态分析 0 Issues：',
          style: AppTypography.label(
            palette.secondaryText,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        ...testCases.map((Map<String, String> tc) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.elevatedSurface.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: palette.borderLine, width: 0.8),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: palette.cinnabarRed,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tc['name']!,
                    style: AppTypography.label(
                      palette.inkText,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Text(
                  tc['time']!,
                  style: AppTypography.label(
                    palette.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildJenkinsfileTabContent(TraditionalPalette palette) {
    const String localCmd =
        'powershell -NoProfile -ExecutionPolicy Bypass -File .\\ci\\run_pipeline.ps1 -Stage All';
    const String jenkinsfileSnippet = '''pipeline {
    agent any
    parameters {
        booleanParam(name: 'RUN_TESTS', defaultValue: true)
        booleanParam(name: 'BUILD_WEB_AND_LAUNCHER', defaultValue: true)
        booleanParam(name: 'BUILD_WINDOWS_NATIVE', defaultValue: true)
        booleanParam(name: 'BUILD_ANDROID_APK', defaultValue: true)
    }
    stages {
        stage('Checkout & Env Check')     { steps { script { runCiStage('EnvCheck') } } }
        stage('Install Dependencies')     { steps { script { runCiStage('Setup') } } }
        stage('Static Analysis')          { steps { script { runCiStage('Analyze') } } }
        stage('Unit & Widget Tests')      { steps { script { runCiStage('Test') } } }
        stage('Build Web & Single EXE')   { steps { script { runCiStage('BuildWebLauncher') } } }
        stage('Build Windows Native')     { steps { script { runCiStage('BuildWindowsNative') } } }
        stage('Build Android APK')        { steps { script { runCiStage('BuildAndroidApk') } } }
        stage('Package & Checksums')      { steps { script { runCiStage('Archive') } } }
    }
}''';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '1. 本地一键执行完整 Jenkins 流水线命令：',
              style: AppTypography.label(
                palette.inkText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _copyText(localCmd, '本地流水线命令'),
              icon: Icon(Icons.copy_rounded, size: 14, color: palette.cinnabarRed),
              label: Text(
                '复制命令',
                style: AppTypography.label(palette.cinnabarRed, fontSize: 12),
              ),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.background.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: palette.borderLine, width: 0.8),
          ),
          child: SelectableText(
            localCmd,
            style: AppTypography.label(palette.inkText, fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Text(
              '2. 项目根目录 Jenkinsfile 声明式流水线核心结构：',
              style: AppTypography.label(
                palette.inkText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _copyText(jenkinsfileSnippet, 'Jenkinsfile 配置'),
              icon: Icon(Icons.copy_rounded, size: 14, color: palette.cinnabarRed),
              label: Text(
                '复制配置',
                style: AppTypography.label(palette.cinnabarRed, fontSize: 12),
              ),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.background.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: palette.borderLine, width: 0.8),
          ),
          child: SelectableText(
            jenkinsfileSnippet,
            style: AppTypography.label(palette.secondaryText, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
