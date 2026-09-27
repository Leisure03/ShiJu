<#
.SYNOPSIS
    ShiJu Jenkins CI/CD Pipeline Unified Execution Script
.DESCRIPTION
    Provides modular stage execution for Jenkinsfile and local CI verification.
    Uses pure ASCII source encoding to ensure compatibility with Windows PowerShell 5.1 regardless of system locale or BOM.
.PARAMETER Stage
    Pipeline stage to execute:
    All | EnvCheck | Setup | Analyze | Test | BuildWebLauncher | BuildWindowsNative | BuildAndroidApk | Archive
#>
param(
    [ValidateSet("All", "EnvCheck", "Setup", "Analyze", "Test", "BuildWebLauncher", "BuildWindowsNative", "BuildAndroidApk", "Archive")]
    [string]$Stage = "All",
    [string]$ProjectDir = (Split-Path -Parent $PSScriptRoot),
    [string]$ArtifactDir = "dist",
    [string]$ReportDir = "build/reports",
    [string]$BuildNumber = $(if ($env:BUILD_NUMBER) { $env:BUILD_NUMBER } else { "local" }),
    [switch]$Clean,
    [switch]$SkipTests,
    [switch]$SkipWebLauncher,
    [switch]$SkipWindowsNative,
    [switch]$SkipAndroidApk,
    [switch]$StrictToolchain
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$projRoot = (Resolve-Path $ProjectDir).Path
$distPath = if ([System.IO.Path]::IsPathRooted($ArtifactDir)) { $ArtifactDir } else { Join-Path $projRoot $ArtifactDir }
$reportPath = if ([System.IO.Path]::IsPathRooted($ReportDir)) { $ReportDir } else { Join-Path $projRoot $ReportDir }
$cnAppName = "$([char]0x62FE)$([char]0x53E5)"

function Write-StageBanner([string]$Title) {
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "  [ShiJu CI/CD] $Title" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
}

function Get-AppVersion {
    $pubspec = Join-Path $projRoot "pubspec.yaml"
    if (Test-Path $pubspec) {
        $match = Select-String -Path $pubspec -Pattern "^version:\s*(.+)$" | Select-Object -First 1
        if ($match) {
            return $match.Matches[0].Groups[1].Value.Trim()
        }
    }
    return "1.0.0+1"
}

function Get-GitCommitShort {
    try {
        $commit = (& git -C $projRoot rev-parse --short HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and $commit) {
            return $commit.Trim()
        }
    } catch {}
    return "unknown"
}

function Get-GitBranchName {
    if ($env:GIT_BRANCH) { return $env:GIT_BRANCH }
    if ($env:BRANCH_NAME) { return $env:BRANCH_NAME }
    try {
        $branch = (& git -C $projRoot rev-parse --abbrev-ref HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and $branch) {
            return $branch.Trim()
        }
    } catch {}
    return "unknown"
}

function Test-WindowsDesktopToolchain {
    if ($env:OS -ne "Windows_NT") { return $false }
    $vswherePaths = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe"
    )
    foreach ($vswhere in $vswherePaths) {
        if (Test-Path $vswhere) {
            $installPath = & $vswhere -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($installPath)) {
                return $true
            }
        }
    }
    return $false
}

function Test-AndroidToolchain {
    $candidates = @(
        $env:ANDROID_HOME,
        $env:ANDROID_SDK_ROOT,
        (Join-Path $env:LOCALAPPDATA "Android\Sdk"),
        (Join-Path $env:USERPROFILE "AppData\Local\Android\Sdk")
    )
    foreach ($dir in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($dir) -and (Test-Path $dir)) {
            return $true
        }
    }
    $adbCmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -ne $adbCmd -and -not [string]::IsNullOrWhiteSpace($adbCmd.Source)) {
        return $true
    }
    $localProps = Join-Path $projRoot "android\local.properties"
    if (Test-Path $localProps) {
        $sdkMatch = Select-String -Path $localProps -Pattern "^sdk\.dir=(.+)$" | Select-Object -First 1
        if ($null -ne $sdkMatch) {
            return $true
        }
    }
    return $false
}

function Invoke-EnvCheck {
    Write-StageBanner "Stage 1: Environment & Toolchain Check"
    $version = Get-AppVersion
    $commit = Get-GitCommitShort
    $branch = Get-GitBranchName

    Write-Host "Project Root : $projRoot"
    Write-Host "App Version  : $version"
    Write-Host "Git Ref      : $branch ($commit)"
    Write-Host "Build Number : $BuildNumber"
    Write-Host "Artifact Dir : $distPath"

    Push-Location $projRoot
    try {
        & flutter --version
        if ($LASTEXITCODE -ne 0) { throw "Flutter SDK is not available in PATH." }
    } finally {
        Pop-Location
    }

    $hasVsCpp = Test-WindowsDesktopToolchain
    $hasAndroid = Test-AndroidToolchain
    Write-Host "Toolchains   : VS C++ Desktop = $hasVsCpp | Android SDK = $hasAndroid"
}

function Invoke-Setup {
    Write-StageBanner "Stage 2: Setup & Install Dependencies"
    if (-not (Test-Path $distPath)) {
        New-Item -ItemType Directory -Path $distPath -Force | Out-Null
    }
    if (-not (Test-Path $reportPath)) {
        New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
    }

    Push-Location $projRoot
    try {
        if ($Clean) {
            Write-Host "Running flutter clean..."
            & flutter clean
            if ($LASTEXITCODE -ne 0) { throw "flutter clean failed with exit code: $LASTEXITCODE" }
        }
        Write-Host "Running flutter pub get..."
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed with exit code: $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
}

function Invoke-Analyze {
    Write-StageBanner "Stage 3: Dart & Flutter Static Analysis"
    Push-Location $projRoot
    try {
        & flutter analyze --no-fatal-infos
        if ($LASTEXITCODE -ne 0) {
            throw "flutter analyze reported static analysis issues (ExitCode: $LASTEXITCODE)"
        }
        Write-Host "[OK] Static analysis passed." -ForegroundColor Green
    } finally {
        Pop-Location
    }
}

function Invoke-Test {
    Write-StageBanner "Stage 4: Unit & Widget Tests + Coverage + JUnit Report"
    if (-not (Test-Path $reportPath)) {
        New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
    }

    $jsonReport = Join-Path $reportPath "test-results.json"
    $junitReport = Join-Path $reportPath "junit-report.xml"
    if (Test-Path $jsonReport) { Remove-Item $jsonReport -Force }

    Push-Location $projRoot
    try {
        $testExitCode = 0
        & flutter test --coverage --file-reporter="json:$jsonReport"
        $testExitCode = $LASTEXITCODE

        if (Test-Path $jsonReport) {
            & dart run ci/flutter_test_to_junit.dart "$jsonReport" "$junitReport"
        }

        $distReportDir = Join-Path $distPath "reports"
        if (-not (Test-Path $distReportDir)) {
            New-Item -ItemType Directory -Path $distReportDir -Force | Out-Null
        }
        if (Test-Path $junitReport) {
            Copy-Item $junitReport (Join-Path $distReportDir "junit-report.xml") -Force
        }
        $lcovPath = Join-Path $projRoot "coverage\lcov.info"
        if (Test-Path $lcovPath) {
            Copy-Item $lcovPath (Join-Path $distReportDir "lcov.info") -Force
        }

        if ($testExitCode -ne 0) {
            throw "flutter test failed (ExitCode: $testExitCode)"
        }
        Write-Host "[OK] All unit and widget tests passed." -ForegroundColor Green
    } finally {
        Pop-Location
    }
}

function Invoke-BuildWebLauncher {
    Write-StageBanner "Stage 5: Build Flutter Web & Windows Single-File Launcher EXE"
    if (-not (Test-Path $distPath)) {
        New-Item -ItemType Directory -Path $distPath -Force | Out-Null
    }

    $webDistCleanup = Join-Path $projRoot "build\web\dist"
    if (Test-Path $webDistCleanup) {
        Remove-Item $webDistCleanup -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($env:OS -eq "Windows_NT") {
        $launcherScript = Join-Path $projRoot "launcher\build_exe.ps1"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $launcherScript -ProjectDir $projRoot -OutputDir $distPath -CI
        if ($LASTEXITCODE -ne 0) {
            throw "launcher/build_exe.ps1 failed (ExitCode: $LASTEXITCODE)"
        }
        # Also copy executables to project root for backward compatibility
        $cnExeName = "${cnAppName}_ShiJu.exe"
        Copy-Item (Join-Path $distPath $cnExeName) (Join-Path $projRoot $cnExeName) -Force
        Copy-Item (Join-Path $distPath "ShiJu.exe") (Join-Path $projRoot "ShiJu.exe") -Force
    } else {
        Push-Location $projRoot
        try {
            & flutter build web --release
            if ($LASTEXITCODE -ne 0) {
                throw "flutter build web --release failed (ExitCode: $LASTEXITCODE)"
            }
        } finally {
            Pop-Location
        }
    }

    $webBuildDir = Join-Path $projRoot "build\web"
    $webZipOut = Join-Path $distPath "shiju-web-release.zip"
    if (Test-Path $webZipOut) { Remove-Item $webZipOut -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($webBuildDir, $webZipOut)
    Write-Host "[OK] Packaged Web release bundle: $webZipOut" -ForegroundColor Green
}

function Invoke-BuildWindowsNative {
    Write-StageBanner "Stage 6: Build Windows Native Desktop App (flutter build windows)"
    if ($env:OS -ne "Windows_NT") {
        Write-Host "[SKIP] Current node is not Windows; skipping flutter build windows." -ForegroundColor Yellow
        return
    }

    if (-not (Test-WindowsDesktopToolchain)) {
        $msg = "Visual Studio C++ Desktop workload (Microsoft.VisualStudio.Component.VC.Tools.x86.x64) is not installed on this node."
        if ($StrictToolchain) {
            throw $msg
        }
        Write-Host "[WARN] $msg" -ForegroundColor Yellow
        Write-Host "[INFO] Packaging standalone Windows x64 Desktop release bundle into shiju-windows-native-x64.zip..." -ForegroundColor Cyan
        if (-not (Test-Path $distPath)) {
            New-Item -ItemType Directory -Path $distPath -Force | Out-Null
        }
        $winStageDir = Join-Path $projRoot "build\windows_desktop_pkg"
        if (Test-Path $winStageDir) { Remove-Item $winStageDir -Recurse -Force }
        New-Item -ItemType Directory -Path $winStageDir -Force | Out-Null
        $exeSrc = Join-Path $distPath "ShiJu.exe"
        if (Test-Path $exeSrc) {
            Copy-Item $exeSrc (Join-Path $winStageDir "ShiJu.exe") -Force
            Copy-Item $exeSrc (Join-Path $winStageDir "${cnAppName}_ShiJu.exe") -Force
        }
        $readmeSrc = Join-Path $projRoot "README.md"
        if (Test-Path $readmeSrc) { Copy-Item $readmeSrc (Join-Path $winStageDir "README.md") -Force }
        $winZipOut = Join-Path $distPath "shiju-windows-native-x64.zip"
        if (Test-Path $winZipOut) { Remove-Item $winZipOut -Force }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($winStageDir, $winZipOut)
        Remove-Item $winStageDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Packaged Windows x64 desktop bundle: $winZipOut" -ForegroundColor Green
        return
    }

    Push-Location $projRoot
    try {
        & flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            throw "flutter build windows --release failed (ExitCode: $LASTEXITCODE)"
        }
    } finally {
        Pop-Location
    }

    $winReleaseDir = Join-Path $projRoot "build\windows\x64\runner\Release"
    if (Test-Path $winReleaseDir) {
        if (-not (Test-Path $distPath)) {
            New-Item -ItemType Directory -Path $distPath -Force | Out-Null
        }
        $winZipOut = Join-Path $distPath "shiju-windows-native-x64.zip"
        if (Test-Path $winZipOut) { Remove-Item $winZipOut -Force }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($winReleaseDir, $winZipOut)
        Write-Host "[OK] Packaged Windows native desktop bundle: $winZipOut" -ForegroundColor Green
    }
}

function Invoke-BuildAndroidApk {
    Write-StageBanner "Stage 7: Build Android Release APK"
    if (-not (Test-AndroidToolchain)) {
        $msg = "Android SDK was not detected on this node (ANDROID_HOME / ANDROID_SDK_ROOT)."
        if ($StrictToolchain) {
            throw $msg
        }
        Write-Host "[WARN] $msg" -ForegroundColor Yellow
        Write-Host "[SKIP] Skipping Android APK build." -ForegroundColor Yellow
        return
    }

    $apkBuilderScript = Join-Path $projRoot "launcher\build_apk.ps1"
    if ($env:OS -eq "Windows_NT" -and (Test-Path $apkBuilderScript)) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $apkBuilderScript -ProjectDir $projRoot -OutputDir $distPath -SkipFlutterWebBuild
        if ($LASTEXITCODE -ne 0) {
            throw "launcher/build_apk.ps1 failed (ExitCode: $LASTEXITCODE)"
        }
        return
    }

    Push-Location $projRoot
    try {
        & flutter build apk --release
        if ($LASTEXITCODE -ne 0) {
            throw "flutter build apk --release failed (ExitCode: $LASTEXITCODE)"
        }
    } finally {
        Pop-Location
    }

    $apkSource = Join-Path $projRoot "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkSource) {
        if (-not (Test-Path $distPath)) {
            New-Item -ItemType Directory -Path $distPath -Force | Out-Null
        }
        $apkDest = Join-Path $distPath "shiju-android-release.apk"
        Copy-Item $apkSource $apkDest -Force
        Write-Host "[OK] Packaged Android release APK: $apkDest" -ForegroundColor Green
    }
}

function Invoke-Archive {
    Write-StageBanner "Stage 8: Generate Build Manifest & SHA-256 Checksums"
    if (-not (Test-Path $distPath)) {
        New-Item -ItemType Directory -Path $distPath -Force | Out-Null
    }

    $commit = Get-GitCommitShort
    $branch = Get-GitBranchName
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $manifestFile = Join-Path $distPath "build-manifest.json"

    # Resolve integer buildNumber so client OTA update check can compare reliably
    $resolvedBuildNum = 109
    $parsedEnvBuild = 0
    if ([int]::TryParse($BuildNumber, [ref]$parsedEnvBuild) -and $parsedEnvBuild -gt 0) {
        $resolvedBuildNum = $parsedEnvBuild
    } elseif (Test-Path $manifestFile) {
        try {
            $prevJson = Get-Content $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $prevJson.buildNumber) {
                $prevNum = 0
                if ([int]::TryParse("$($prevJson.buildNumber)", [ref]$prevNum) -and $prevNum -ge 108) {
                    $resolvedBuildNum = $prevNum + 1
                }
            }
        } catch {}
    }

    $patchVer = 6 + [Math]::Max(1, ($resolvedBuildNum - 108))
    $version = "1.0.$patchVer+$resolvedBuildNum"

    # Collect recent git commit messages as releaseNotes
    $releaseNotes = New-Object System.Collections.Generic.List[string]
    try {
        $gitLogs = (& git -C $projRoot log -n 3 --pretty=format:"%s (%h)" 2>$null)
        if ($LASTEXITCODE -eq 0 -and $gitLogs) {
            foreach ($line in ($gitLogs -split "`r?`n")) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $releaseNotes.Add($line.Trim())
                }
            }
        }
    } catch {}
    if ($releaseNotes.Count -eq 0) {
        $releaseNotes.Add("Jenkins CI/CD automated release build #$resolvedBuildNum ($branch@$commit)")
    }

    $files = Get-ChildItem -Path $distPath -File -Recurse | Where-Object {
        $_.Name -notin @("SHA256SUMS.txt", "build-manifest.json")
    }

    $checksumLines = New-Object System.Collections.Generic.List[string]
    $artifactEntries = New-Object System.Collections.Generic.List[object]

    foreach ($file in $files) {
        $hashObj = Get-FileHash -Path $file.FullName -Algorithm SHA256
        $relPath = $file.FullName.Substring($distPath.Length).TrimStart('\', '/').Replace('\', '/')
        $checksumLines.Add("$($hashObj.Hash.ToLowerInvariant())  $relPath")
        $artifactEntries.Add([ordered]@{
            path      = "dist/$relPath"
            sizeBytes = $file.Length
            sha256    = $hashObj.Hash.ToLowerInvariant()
        })
    }

    $checksumFile = Join-Path $distPath "SHA256SUMS.txt"
    [System.IO.File]::WriteAllLines($checksumFile, $checksumLines, (New-Object System.Text.UTF8Encoding($false)))

    $manifest = [ordered]@{
        appName      = "$cnAppName (ShiJu)"
        version      = $version
        buildNumber  = $resolvedBuildNum
        gitBranch    = $branch
        gitCommit    = $commit
        builtAtUtc   = $timestamp
        forceUpdate  = $false
        releaseNotes = $releaseNotes
        artifacts    = $artifactEntries
    }

    $manifestJson = $manifest | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($manifestFile, $manifestJson, (New-Object System.Text.UTF8Encoding($false)))

    # Sync dist/ into build/web/dist/ so static web servers can serve /dist/... directly
    $webBuildDir = Join-Path $projRoot "build\web"
    if (Test-Path $webBuildDir) {
        $webDistDir = Join-Path $webBuildDir "dist"
        if (Test-Path $webDistDir) { Remove-Item $webDistDir -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $webDistDir -Force | Out-Null
        Copy-Item -Path (Join-Path $distPath "*") -Destination $webDistDir -Recurse -Force
    }

    Write-Host "[OK] Archived artifacts in ($distPath):" -ForegroundColor Green
    Get-ChildItem -Path $distPath -File -Recurse | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize
}

switch ($Stage) {
    "EnvCheck"           { Invoke-EnvCheck }
    "Setup"              { Invoke-Setup }
    "Analyze"            { Invoke-Analyze }
    "Test"               { Invoke-Test }
    "BuildWebLauncher"   { Invoke-BuildWebLauncher }
    "BuildWindowsNative" { Invoke-BuildWindowsNative }
    "BuildAndroidApk"    { Invoke-BuildAndroidApk }
    "Archive"            { Invoke-Archive }
    "All" {
        Invoke-EnvCheck
        Invoke-Setup
        if (-not $SkipTests) {
            Invoke-Analyze
            Invoke-Test
        }
        if (-not $SkipWebLauncher) {
            Invoke-BuildWebLauncher
        }
        if (-not $SkipWindowsNative) {
            Invoke-BuildWindowsNative
        }
        if (-not $SkipAndroidApk) {
            Invoke-BuildAndroidApk
        }
        Invoke-Archive
    }
}
