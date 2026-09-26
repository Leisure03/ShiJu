// =============================================================================
// 拾句 (ShiJu) · Jenkins CI/CD 声明式流水线 (Declarative Pipeline)
//
// 核心能力:
// 1. 以 Windows 节点为主（同时自动兼容 Linux / macOS 节点）
// 2. 静态代码分析 (flutter analyze) + 自动化测试与覆盖率 + JUnit 测试报告转换
// 3. 多端产物构建:
//    - Web 静态资源包 (shiju-web-release.zip) + Windows 单文件启动器 (拾句_ShiJu.exe / ShiJu.exe)
//    - Windows 原生桌面客户端 (flutter build windows -> shiju-windows-native-x64.zip)
//    - Android Release 安装包 (flutter build apk -> shiju-android-release.apk)
// 4. 自动生成 SHA256SUMS.txt 与 build-manifest.json，并通过 archiveArtifacts 归档
// =============================================================================

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '10'))
    }

    parameters {
        booleanParam(
            name: 'RUN_TESTS',
            defaultValue: true,
            description: '执行 Flutter 静态代码分析 (flutter analyze) 与自动化测试/覆盖率收集 (flutter test)'
        )
        booleanParam(
            name: 'BUILD_WEB_AND_LAUNCHER',
            defaultValue: true,
            description: '构建 Flutter Web 静态资源包与 Windows 单文件启动器 (拾句_ShiJu.exe / ShiJu.exe)'
        )
        booleanParam(
            name: 'BUILD_WINDOWS_NATIVE',
            defaultValue: true,
            description: '构建 Windows 原生桌面应用 (flutter build windows --release)'
        )
        booleanParam(
            name: 'BUILD_ANDROID_APK',
            defaultValue: true,
            description: '构建 Android 安装包 (flutter build apk --release)'
        )
        booleanParam(
            name: 'CLEAN_BUILD',
            defaultValue: false,
            description: '构建前执行 flutter clean 清理历史构建缓存'
        )
        booleanParam(
            name: 'STRICT_TOOLCHAIN',
            defaultValue: false,
            description: '严格工具链检查：若节点缺少 VS C++ 或 Android SDK 则直接失败而非跳过对应平台'
        )
    }

    environment {
        CI                       = 'true'
        PUB_HOSTED_URL           = 'https://pub.flutter-io.cn'
        FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
        DIST_DIR                 = 'dist'
        REPORT_DIR               = 'build/reports'
    }

    stages {
        stage('Checkout & Env Check') {
            steps {
                checkout scm
                script {
                    runCiStage('EnvCheck')
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                script {
                    runCiStage('Setup')
                }
            }
        }

        stage('Static Analysis') {
            when {
                expression { return params.RUN_TESTS }
            }
            steps {
                script {
                    runCiStage('Analyze')
                }
            }
        }

        stage('Unit & Widget Tests') {
            when {
                expression { return params.RUN_TESTS }
            }
            steps {
                script {
                    runCiStage('Test')
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'build/reports/junit-report.xml'
                }
            }
        }

        stage('Build Web & Single-File EXE') {
            when {
                expression { return params.BUILD_WEB_AND_LAUNCHER }
            }
            steps {
                script {
                    runCiStage('BuildWebLauncher')
                }
            }
        }

        stage('Build Windows Native') {
            when {
                expression { return params.BUILD_WINDOWS_NATIVE }
            }
            steps {
                script {
                    runCiStage('BuildWindowsNative')
                }
            }
        }

        stage('Build Android APK') {
            when {
                expression { return params.BUILD_ANDROID_APK }
            }
            steps {
                script {
                    runCiStage('BuildAndroidApk')
                }
            }
        }

        stage('Package & Checksums') {
            steps {
                script {
                    runCiStage('Archive')
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts(
                artifacts: 'dist/**/*, coverage/lcov.info',
                allowEmptyArchive: true,
                fingerprint: true
            )
        }
        success {
            echo '✅ [ShiJu CI/CD] 拾句 Jenkins 流水线执行成功，产物已归档至 dist/ 目录！'
        }
        failure {
            echo '❌ [ShiJu CI/CD] 拾句 Jenkins 流水线执行失败，请检查阶段日志与测试报告。'
        }
    }
}

/**
 * 跨平台调用 ci/ 目录下的统一流水线阶段脚本（优先支持 Windows PowerShell，同时兼容 Linux/macOS 节点）
 */
void runCiStage(String stageName) {
    List<String> psFlags = ["-Stage ${stageName}"]
    List<String> shFlags = [stageName]

    if (params.CLEAN_BUILD && stageName == 'Setup') {
        psFlags.add('-Clean')
        shFlags.add('--clean')
    }
    if (params.STRICT_TOOLCHAIN) {
        psFlags.add('-StrictToolchain')
        shFlags.add('--strict-toolchain')
    }

    if (isUnix()) {
        sh "chmod +x ci/run_pipeline.sh && ./ci/run_pipeline.sh ${shFlags.join(' ')}"
    } else {
        powershell "powershell -NoProfile -ExecutionPolicy Bypass -File .\\ci\\run_pipeline.ps1 ${psFlags.join(' ')}"
    }
}
