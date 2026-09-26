param(
    [string]$ProjectDir = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDir = "",
    [switch]$SkipFlutterWebBuild
)

$ErrorActionPreference = "Stop"

$projDir = (Resolve-Path $ProjectDir).Path
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $outDir = Join-Path $projDir "dist"
} else {
    $outDir = $OutputDir
}
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$outDir = (Resolve-Path $outDir).Path

# Locate Android SDK
$sdkDir = $null
$sdkCandidates = @(
    $env:ANDROID_HOME,
    $env:ANDROID_SDK_ROOT,
    "D:\asSDK",
    (Join-Path $env:LOCALAPPDATA "Android\Sdk")
)
foreach ($c in $sdkCandidates) {
    if (-not [string]::IsNullOrWhiteSpace($c) -and (Test-Path $c)) {
        $sdkDir = $c
        break
    }
}
if (-not $sdkDir) {
    $adbCmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbCmd) {
        $sdkDir = Split-Path -Parent (Split-Path -Parent $adbCmd.Source)
    }
}
if (-not $sdkDir -or -not (Test-Path $sdkDir)) {
    throw "Android SDK directory not found."
}

$buildToolsDir = Get-ChildItem (Join-Path $sdkDir "build-tools") -Directory | Where-Object { Test-Path (Join-Path $_.FullName "aapt.exe") } | Sort-Object Name -Descending | Select-Object -First 1
$platformDir = Get-ChildItem (Join-Path $sdkDir "platforms") -Directory | Where-Object { Test-Path (Join-Path $_.FullName "android.jar") } | Sort-Object Name -Descending | Select-Object -First 1
if (-not $buildToolsDir -or -not $platformDir) {
    throw "Android SDK build-tools or platforms (with android.jar) not found in $sdkDir"
}

$aapt = Join-Path $buildToolsDir.FullName "aapt.exe"
$d8 = Join-Path $buildToolsDir.FullName "d8.bat"
$zipalign = Join-Path $buildToolsDir.FullName "zipalign.exe"
$apksigner = Join-Path $buildToolsDir.FullName "apksigner.bat"
$androidJar = Join-Path $platformDir.FullName "android.jar"

# Locate JDK (javac & keytool & jar)
$jdkBin = $null
$jdkCandidates = @(
    "D:\as\jbr\bin",
    "C:\Program Files\Android\Android Studio\jbr\bin",
    $(if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin" } else { $null })
)
foreach ($jc in $jdkCandidates) {
    if (-not [string]::IsNullOrWhiteSpace($jc) -and (Test-Path (Join-Path $jc "javac.exe"))) {
        $jdkBin = $jc
        break
    }
}
if (-not $jdkBin) {
    $javacCmd = Get-Command javac -ErrorAction SilentlyContinue
    if ($javacCmd) { $jdkBin = Split-Path -Parent $javacCmd.Source }
}
if (-not $jdkBin) {
    throw "JDK bin directory (javac.exe) not found."
}

$env:JAVA_HOME = Split-Path -Parent $jdkBin
$env:PATH = "$jdkBin;$env:PATH"
$javac = Join-Path $jdkBin "javac.exe"
$jarExe = Join-Path $jdkBin "jar.exe"
$keytool = Join-Path $jdkBin "keytool.exe"

$webBuildDir = Join-Path $projDir "build\web"
if (-not $SkipFlutterWebBuild -or -not (Test-Path (Join-Path $webBuildDir "main.dart.js"))) {
    Push-Location $projDir
    try {
        flutter build web --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build web failed." }
    } finally {
        Pop-Location
    }
}

$workDir = Join-Path $projDir "build\android_apk_work"
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
$srcDir = Join-Path $workDir "src\com\leisure03\shiju"
$classesDir = Join-Path $workDir "classes"
$resDir = Join-Path $workDir "res\mipmap-xxhdpi"
$assetsWwwDir = Join-Path $workDir "assets\www"
New-Item -ItemType Directory -Path $srcDir, $classesDir, $resDir, $assetsWwwDir -Force | Out-Null

# Copy icon
$iconSrc = Join-Path $projDir "web\icons\Icon-192.png"
if (Test-Path $iconSrc) {
    Copy-Item $iconSrc (Join-Path $resDir "ic_launcher.png") -Force
}

# Copy web build assets (exclude any nested dist folder to keep APK lean)
Get-ChildItem -Path $webBuildDir | Where-Object { $_.Name -ne "dist" } | ForEach-Object {
    Copy-Item $_.FullName -Destination $assetsWwwDir -Recurse -Force
}

$cnLabel = "$([char]0x62FE)$([char]0x53E5) (ShiJu)"
$manifestXml = @"
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.leisure03.shiju"
    android:versionCode="105"
    android:versionName="1.0.5">
    <uses-sdk android:minSdkVersion="24" android:targetSdkVersion="34" />
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:label="$cnLabel"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true"
        android:theme="@android:style/Theme.DeviceDefault.NoActionBar">
        <activity
            android:name="com.leisure03.shiju.MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
"@
$manifestPath = Join-Path $workDir "AndroidManifest.xml"
[System.IO.File]::WriteAllText($manifestPath, $manifestXml, (New-Object System.Text.UTF8Encoding($false)))

$javaCode = @"
package com.leisure03.shiju;

import android.app.Activity;
import android.content.res.AssetManager;
import android.os.Bundle;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;

public class MainActivity extends Activity {
    private WebView webView;
    private ServerSocket serverSocket;
    private int serverPort;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        startLocalAssetServer();
        webView = new WebView(this);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(true);
        webView.setWebViewClient(new WebViewClient());
        setContentView(webView);
        webView.loadUrl("http://127.0.0.1:" + serverPort + "/index.html");
    }

    private void startLocalAssetServer() {
        try {
            serverSocket = new ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"));
            serverPort = serverSocket.getLocalPort();
            final AssetManager assets = getAssets();
            Thread t = new Thread(new Runnable() {
                @Override
                public void run() {
                    while (!serverSocket.isClosed()) {
                        try {
                            final Socket client = serverSocket.accept();
                            handleClient(client, assets);
                        } catch (Exception ignored) {
                            break;
                        }
                    }
                }
            });
            t.setDaemon(true);
            t.start();
        } catch (Exception ignored) {
        }
    }

    private void handleClient(Socket client, AssetManager assets) {
        try {
            BufferedReader reader = new BufferedReader(new InputStreamReader(client.getInputStream()));
            String line = reader.readLine();
            if (line == null) { client.close(); return; }
            String[] parts = line.split(" ");
            String rawPath = parts.length > 1 ? parts[1] : "/index.html";
            int q = rawPath.indexOf('?');
            if (q >= 0) rawPath = rawPath.substring(0, q);
            if (rawPath.equals("/") || rawPath.isEmpty()) rawPath = "/index.html";
            String assetPath = "www" + rawPath;

            byte[] data;
            try {
                InputStream is = assets.open(assetPath);
                ByteArrayOutputStream buffer = new ByteArrayOutputStream();
                byte[] tmp = new byte[8192];
                int n;
                while ((n = is.read(tmp)) != -1) buffer.write(tmp, 0, n);
                is.close();
                data = buffer.toByteArray();
            } catch (Exception e) {
                InputStream is = assets.open("www/index.html");
                ByteArrayOutputStream buffer = new ByteArrayOutputStream();
                byte[] tmp = new byte[8192];
                int n;
                while ((n = is.read(tmp)) != -1) buffer.write(tmp, 0, n);
                is.close();
                data = buffer.toByteArray();
                assetPath = "www/index.html";
            }

            String mime = getMime(assetPath);
            OutputStream out = client.getOutputStream();
            String header = "HTTP/1.1 200 OK\r\nContent-Type: " + mime + "\r\nContent-Length: " + data.length + "\r\nConnection: close\r\n\r\n";
            out.write(header.getBytes("UTF-8"));
            out.write(data);
            out.flush();
            client.close();
        } catch (Exception ignored) {
            try { client.close(); } catch (Exception e) {}
        }
    }

    private String getMime(String p) {
        if (p.endsWith(".html")) return "text/html; charset=utf-8";
        if (p.endsWith(".js")) return "application/javascript; charset=utf-8";
        if (p.endsWith(".json")) return "application/json; charset=utf-8";
        if (p.endsWith(".wasm")) return "application/wasm";
        if (p.endsWith(".png")) return "image/png";
        if (p.endsWith(".ttf")) return "font/ttf";
        if (p.endsWith(".otf")) return "font/otf";
        return "application/octet-stream";
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }
}
"@
$javaPath = Join-Path $srcDir "MainActivity.java"
[System.IO.File]::WriteAllText($javaPath, $javaCode, (New-Object System.Text.UTF8Encoding($false)))

# 1. Compile Java -> .class -> classes.jar -> classes.dex
& $javac -encoding UTF-8 -source 1.8 -target 1.8 -Xlint:-options -cp "$androidJar" -d "$classesDir" "$javaPath"
if ($LASTEXITCODE -ne 0) { throw "javac failed." }

$classesJar = Join-Path $workDir "classes.jar"
& $jarExe cf "$classesJar" -C "$classesDir" .
if ($LASTEXITCODE -ne 0) { throw "jar failed." }

& $d8 --release --lib "$androidJar" --output "$workDir" "$classesJar"
if ($LASTEXITCODE -ne 0) { throw "d8 failed." }

# 2. Package resources & assets into unaligned APK
$unalignedApk = Join-Path $workDir "unaligned.apk"
& $aapt package -f -M "$manifestPath" -S (Join-Path $workDir "res") -A (Join-Path $workDir "assets") -I "$androidJar" -F "$unalignedApk"
if ($LASTEXITCODE -ne 0) { throw "aapt package failed." }

# Add classes.dex into unaligned.apk
Push-Location $workDir
try {
    & $aapt add "$unalignedApk" "classes.dex" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "aapt add classes.dex failed." }
} finally {
    Pop-Location
}

# 3. Zipalign
$alignedApk = Join-Path $workDir "aligned.apk"
& $zipalign -f 4 "$unalignedApk" "$alignedApk"
if ($LASTEXITCODE -ne 0) { throw "zipalign failed." }

# 4. Sign APK with debug/release keystore
$keystorePath = Join-Path $workDir "shiju_release.jks"
$prevErrPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& $keytool -genkeypair -keystore "$keystorePath" -alias shiju -keyalg RSA -keysize 2048 -validity 10000 -storepass shiju123 -keypass shiju123 -dname "CN=ShiJu, OU=Mobile, O=Leisure03, L=Beijing, S=Beijing, C=CN" *> $null
$ErrorActionPreference = $prevErrPref
$finalApk = Join-Path $outDir "shiju-android-release.apk"
& $apksigner sign --ks "$keystorePath" --ks-pass pass:shiju123 --key-pass pass:shiju123 --out "$finalApk" "$alignedApk"
if ($LASTEXITCODE -ne 0) { throw "apksigner failed." }

# Also copy to standard Flutter APK output path for full compatibility
$flutterApkDir = Join-Path $projDir "build\app\outputs\flutter-apk"
New-Item -ItemType Directory -Path $flutterApkDir -Force | Out-Null
Copy-Item $finalApk (Join-Path $flutterApkDir "app-release.apk") -Force

Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[OK] Built and signed Android APK: $finalApk" -ForegroundColor Green
Get-Item $finalApk | Select-Object FullName, Length, LastWriteTime
