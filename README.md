# 拾句 (ShiJu) · 东方极简古诗词推荐与深度赏析 App

> **“醉后不知天在水，满船清梦压星河。”**  
> 以句入诗，由诗及人 —— 融合新中式极简留白美学与中国传统色动态主题的古诗词漫游与深度赏析应用。

---

## 核心特性

### 1. 东方美学视觉规范 (Design System)
- **中国传统色动态主题（700ms 丝滑过渡）**：每首诗词绑定专属中国传统色，随诗词切换平滑渐变：
  - **宣纸白** (`#F7F4ED`) · **天水碧** (`#D4E5E3`) · **松花黄** (`#F4F0D6`) · **暮山紫** (`#E4DFEC`) · **胭脂粉** (`#F2DFE1`) · **玄青色**（夜间模式 `#1A1C1E`）
- **宋刻书眉与朱砂印章**：内置阳文印与阴文印篆刻组件（`#C03F3C` 朱砂红）、宣纸双栏内框及四角折角暗纹。
- **古籍竖排 (`vertical-rl`) 与现代横排一键切换**：支持自右向左分列、乌丝栏细线与古籍竖排标点适配。

### 2. 三大核心功能模块
- **首页 · 名句卡片流**：
  - 十二时辰自动推算与应景导语（如「戌时 · 夜阑」）；
  - 居中呈现单句精选诗笺卡片，支持点击平滑展开进入全诗详情页；
  - 支持「偶遇下一句」、左右滑动手势、键盘 **空格键 (`Space`)** 随机漫游及方向键切换。
- **诗词详情页 · 全诗与作者**：
  - 完整诗词全文展示，自动将首页推荐名句以 **朱砂红底纹 + 下划线 +「拾句」印章** 高亮标记；
  - **【译文与注释】** 与 **【创作背景与赏析】** 多维标签页；
  - **作者生平小传与作品聚合**：展示诗人字号、生卒年与生平简介，并支持一键切换品读该作者收录的全部其他作品。
- **寻章摘句、我的藏书阁与诗笺海报**：
  - 实时关键词搜索（诗句/诗名/作者）与十大意境标签（`#咏月` `#思乡` `#豪放` `#婉约` `#山水` `#送别` `#哲理` `#星空` `#旷达`）筛选；
  - 本地持久化保存「收藏列表」、「阅读历史」、「横竖排偏好」与「夜间模式」；
  - 内置竖版新中式「诗笺海报」预览弹窗。

---

## 快速运行与打包

```powershell
# 1. 获取依赖
flutter pub get

# 2. 运行自动化测试
flutter test

# 3. 在浏览器或桌面端启动调试
flutter run -d chrome

# 4. 一键打包生成 Windows 单文件可双击运行的 拾句_ShiJu.exe
powershell -ExecutionPolicy Bypass -File .\launcher\build_exe.ps1

# 5. 一键启动 iPhone 17 局域网 PWA 独立全屏服务（手机 Safari 添加到主屏幕）
powershell -ExecutionPolicy Bypass -File .\launcher\serve_iphone.ps1 -Port 8080
```

---

## 持续集成与 Jenkins 流水线 (CI/CD)

项目根目录已内置声明式流水线 [`Jenkinsfile`](Jenkinsfile) 与模块化 CI 执行引擎 [`ci/run_pipeline.ps1`](ci/run_pipeline.ps1)（同时提供 Linux/macOS 兼容脚本 [`ci/run_pipeline.sh`](ci/run_pipeline.sh)）。

### 1. 流水线阶段 (Pipeline Stages)
1. **Checkout & Env Check (`EnvCheck`)**：检出代码、提取版本与 Git 元信息、探测 Flutter SDK 与原生编译工具链（VS C++ / Android SDK）。
2. **Install Dependencies (`Setup`)**：支持可选 `flutter clean` 并执行 `flutter pub get`。
3. **Static Analysis (`Analyze`)**：执行 `flutter analyze --no-fatal-infos` 静态代码质量门禁。
4. **Unit & Widget Tests (`Test`)**：执行 `flutter test --coverage`，通过 [`ci/flutter_test_to_junit.dart`](ci/flutter_test_to_junit.dart) 自动生成 Jenkins 标准 `build/reports/junit-report.xml` 测试报告与 `coverage/lcov.info` 覆盖率文件。
5. **Build Web & Single-File EXE (`BuildWebLauncher`)**：调用 [`launcher/build_exe.ps1`](launcher/build_exe.ps1) 生成 `拾句_ShiJu.exe`、`ShiJu.exe` 单文件启动器及 `dist/shiju-web-release.zip` 静态资源包。
6. **Build Windows Native (`BuildWindowsNative`)**：构建 `flutter build windows --release` 并打包为 `dist/shiju-windows-native-x64.zip`。
7. **Build Android APK (`BuildAndroidApk`)**：构建 `flutter build apk --release` 并归档为 `dist/shiju-android-release.apk`。
8. **Package & Checksums (`Archive`)**：汇总所有构建产物至 `dist/`，生成 `dist/build-manifest.json` 与 `dist/SHA256SUMS.txt`，并通过 Jenkins `archiveArtifacts` 与 `junit` 插件完成归档。

### 2. 本地模拟运行流水线

```powershell
# 运行完整流水线（自动检测当前节点可用工具链并归档至 dist/）
powershell -NoProfile -ExecutionPolicy Bypass -File .\ci\run_pipeline.ps1 -Stage All

# 仅运行代码分析 + 单元测试 + Web 与 Windows 单文件 EXE 打包 + 归档校验
powershell -NoProfile -ExecutionPolicy Bypass -File .\ci\run_pipeline.ps1 -Stage All -SkipWindowsNative -SkipAndroidApk

# 单独执行某一阶段（EnvCheck | Setup | Analyze | Test | BuildWebLauncher | BuildWindowsNative | BuildAndroidApk | Archive）
powershell -NoProfile -ExecutionPolicy Bypass -File .\ci\run_pipeline.ps1 -Stage Test
```

