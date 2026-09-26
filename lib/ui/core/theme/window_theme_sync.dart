import 'package:flutter/material.dart';
import 'window_theme_sync_stub.dart'
    if (dart.library.js_interop) 'window_theme_sync_web.dart' as impl;

/// 同步系统窗口顶栏背景色，使其与当前诗词的中国传统色无缝融合
void syncWindowThemeColor(Color backgroundColor, {required bool isDark}) {
  impl.syncWindowThemeColorImpl(backgroundColor, isDark: isDark);
}
