#!/usr/bin/env bash
# ==============================================================================
# 拾句 (ShiJu) Jenkins CI/CD 流水线统一执行脚本 (Linux / macOS 节点兼容版)
# 用法:
#   bash ci/run_pipeline.sh <Stage> [--clean] [--strict-toolchain]
#   Stage: All | EnvCheck | Setup | Analyze | Test | BuildWebLauncher | BuildWindowsNative | BuildAndroidApk | Archive
# ==============================================================================
set -euo pipefail

STAGE="${1:-All}"
shift || true

CLEAN_BUILD="false"
STRICT_TOOLCHAIN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean) CLEAN_BUILD="true" ;;
    --strict-toolchain) STRICT_TOOLCHAIN="true" ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${PROJ_ROOT}/dist"
REPORT_DIR="${PROJ_ROOT}/build/reports"
BUILD_NUM="${BUILD_NUMBER:-local}"

banner() {
  echo ""
  echo "=================================================================="
  echo "  [ShiJu CI/CD] $1"
  echo "=================================================================="
}

get_version() {
  grep -E '^version:' "${PROJ_ROOT}/pubspec.yaml" | head -n1 | sed 's/version:[[:space:]]*//' | tr -d '\r'
}

get_commit() {
  git -C "${PROJ_ROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown"
}

get_branch() {
  echo "${GIT_BRANCH:-${BRANCH_NAME:-$(git -C "${PROJ_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")}}"
}

stage_env_check() {
  banner "Stage 1: 环境与工具链自检 (Environment Check)"
  echo "项目根目录   : ${PROJ_ROOT}"
  echo "应用版本号   : $(get_version)"
  echo "Git 分支/提交: $(get_branch) ($(get_commit))"
  echo "构建编号     : ${BUILD_NUM}"
  cd "${PROJ_ROOT}"
  flutter --version
}

stage_setup() {
  banner "Stage 2: 依赖获取与工作区准备 (Setup & Dependencies)"
  mkdir -p "${DIST_DIR}" "${REPORT_DIR}"
  cd "${PROJ_ROOT}"
  if [[ "${CLEAN_BUILD}" == "true" ]]; then
    flutter clean
  fi
  flutter pub get
}

stage_analyze() {
  banner "Stage 3: 静态代码分析 (Static Analysis)"
  cd "${PROJ_ROOT}"
  flutter analyze --no-fatal-infos
}

stage_test() {
  banner "Stage 4: 自动化测试与覆盖率收集 (Unit & Widget Tests)"
  mkdir -p "${REPORT_DIR}" "${DIST_DIR}/reports"
  local json_report="${REPORT_DIR}/test-results.json"
  local junit_report="${REPORT_DIR}/junit-report.xml"
  rm -f "${json_report}"

  cd "${PROJ_ROOT}"
  set +e
  flutter test --coverage --file-reporter="json:${json_report}"
  local test_exit=$?
  set -e

  if [[ -f "${json_report}" ]]; then
    dart run ci/flutter_test_to_junit.dart "${json_report}" "${junit_report}"
  fi
  [[ -f "${junit_report}" ]] && cp -f "${junit_report}" "${DIST_DIR}/reports/junit-report.xml"
  [[ -f "${PROJ_ROOT}/coverage/lcov.info" ]] && cp -f "${PROJ_ROOT}/coverage/lcov.info" "${DIST_DIR}/reports/lcov.info"

  if [[ ${test_exit} -ne 0 ]]; then
    echo "flutter test 存在失败用例 (ExitCode: ${test_exit})" >&2
    exit "${test_exit}"
  fi
}

stage_build_web_launcher() {
  banner "Stage 5: 构建 Web 静态资源包"
  mkdir -p "${DIST_DIR}"
  cd "${PROJ_ROOT}"
  flutter build web --release
  if command -v zip >/dev/null 2>&1; then
    (cd "${PROJ_ROOT}/build/web" && zip -qr "${DIST_DIR}/shiju-web-release.zip" .)
  else
    tar -czf "${DIST_DIR}/shiju-web-release.tar.gz" -C "${PROJ_ROOT}/build/web" .
  fi
  echo "[INFO] 非 Windows 节点仅生成 Web 静态资源包，跳过 Windows 单文件 .exe 启动器编译。"
}

stage_build_windows_native() {
  banner "Stage 6: 构建 Windows 原生桌面客户端 (flutter build windows)"
  echo "[SKIP] 当前节点为 Unix/Linux/macOS 系统，跳过 Windows 桌面构建。"
}

stage_build_android_apk() {
  banner "Stage 7: 构建 Android Release APK (flutter build apk)"
  if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" ]]; then
    if [[ "${STRICT_TOOLCHAIN}" == "true" ]]; then
      echo "[ERROR] 未检测到 ANDROID_HOME / ANDROID_SDK_ROOT" >&2
      exit 1
    fi
    echo "[WARN] 未检测到 Android SDK 环境变量，跳过 flutter build apk。"
    return 0
  fi
  cd "${PROJ_ROOT}"
  flutter build apk --release
  mkdir -p "${DIST_DIR}"
  cp -f "${PROJ_ROOT}/build/app/outputs/flutter-apk/app-release.apk" "${DIST_DIR}/shiju-android-release.apk"
}

stage_archive() {
  banner "Stage 8: 生成构建清单与 SHA-256 校验和 (Archive & Manifest)"
  mkdir -p "${DIST_DIR}"
  cd "${DIST_DIR}"
  rm -f SHA256SUMS.txt
  if command -v sha256sum >/dev/null 2>&1; then
    find . -type f ! -name "SHA256SUMS.txt" ! -name "build-manifest.json" -exec sha256sum {} + > SHA256SUMS.txt || true
  elif command -v shasum >/dev/null 2>&1; then
    find . -type f ! -name "SHA256SUMS.txt" ! -name "build-manifest.json" -exec shasum -a 256 {} + > SHA256SUMS.txt || true
  fi
  ls -lh "${DIST_DIR}"
}

case "${STAGE}" in
  EnvCheck)           stage_env_check ;;
  Setup)              stage_setup ;;
  Analyze)            stage_analyze ;;
  Test)               stage_test ;;
  BuildWebLauncher)   stage_build_web_launcher ;;
  BuildWindowsNative) stage_build_windows_native ;;
  BuildAndroidApk)    stage_build_android_apk ;;
  Archive)            stage_archive ;;
  All)
    stage_env_check
    stage_setup
    stage_analyze
    stage_test
    stage_build_web_launcher
    stage_build_windows_native
    stage_build_android_apk
    stage_archive
    ;;
  *)
    echo "未知阶段: ${STAGE}" >&2
    exit 1
    ;;
esac
