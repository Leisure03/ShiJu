import 'package:flutter/material.dart';
import 'ui/core/theme/app_typography.dart';
import 'ui/core/theme/traditional_palette.dart';
import 'ui/features/shiju_app_shell.dart';
import 'ui/features/shiju_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 异步从 CDN 预加载开源中文字体（思源宋体 / 霞鹜文楷），不阻塞首屏渲染
  AppTypography.preloadCdnFonts();

  final ShiJuViewModel viewModel = ShiJuViewModel();
  viewModel.initialize();

  runApp(ShiJuApp(viewModel: viewModel));
}

/// 「拾句（ShiJu）」古诗词推荐与深度赏析 App 根组件
class ShiJuApp extends StatefulWidget {
  const ShiJuApp({
    super.key,
    this.viewModel,
  });

  final ShiJuViewModel? viewModel;

  @override
  State<ShiJuApp> createState() => _ShiJuAppState();
}

class _ShiJuAppState extends State<ShiJuApp> {
  late final ShiJuViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
      _ownsViewModel = false;
      if (!_viewModel.isInitialized) {
        _viewModel.initialize();
      }
    } else {
      _viewModel = ShiJuViewModel()..initialize();
      _ownsViewModel = true;
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, _) {
        final TraditionalPalette palette = _viewModel.activePalette;

        return MaterialApp(
          title: '\u200B',
          debugShowCheckedModeBanner: false,
          themeMode: palette.isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: AppTypography.primaryFontFamily,
            fontFamilyFallback: AppTypography.chineseSerifFallback,
            scaffoldBackgroundColor: palette.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: palette.themeAccent,
              brightness:
                  palette.isDark ? Brightness.dark : Brightness.light,
              surface: palette.cardSurface,
            ),
          ),
          home: ShiJuAppShell(viewModel: _viewModel),
        );
      },
    );
  }
}
