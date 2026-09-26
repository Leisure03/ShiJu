import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

void syncWindowThemeColorImpl(Color backgroundColor, {required bool isDark}) {
  try {
    final int r = (backgroundColor.r * 255.0).round().clamp(0, 255);
    final int g = (backgroundColor.g * 255.0).round().clamp(0, 255);
    final int b = (backgroundColor.b * 255.0).round().clamp(0, 255);
    final String hex =
        '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';

    // 1. 同步更新 <meta name="theme-color">，使桌面端 --app 窗口标题栏与当前诗词传统色完全融为一体
    web.Element? meta =
        web.document.querySelector('meta[name="theme-color"]');
    if (meta == null) {
      meta = web.document.createElement('meta');
      meta.setAttribute('name', 'theme-color');
      web.document.head?.appendChild(meta);
    }
    meta.setAttribute('content', hex);

    // 2. 同步 body 背景色
    web.document.body?.style.backgroundColor = hex;

    // 3. 在 iOS/移动端保持标题为「拾句」便于添加到主屏幕，桌面端 --app 窗口使用零宽字符保持留白
    final String ua = web.window.navigator.userAgent.toLowerCase();
    final bool isMobileDevice = ua.contains('iphone') ||
        ua.contains('ipad') ||
        ua.contains('ipod') ||
        ua.contains('android');
    final String targetTitle = isMobileDevice ? '拾句' : '\u200B';
    if (web.document.title != targetTitle) {
      web.document.title = targetTitle;
    }
  } catch (_) {}
}
