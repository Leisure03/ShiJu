param(
    [int]$Port = 8090,
    [string]$JenkinsRoot = "D:\jenkins",
    [string]$JavaExe = "D:\as\jbr\bin\java.exe",
    [string]$ProjectDir = "D:\antigravity_proj",
    [switch]$OpenBrowser
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $JavaExe)) {
    $cmdJava = Get-Command java -ErrorAction SilentlyContinue
    if ($cmdJava) {
        $JavaExe = $cmdJava.Source
    } else {
        throw "Java runtime not found at $JavaExe and not in PATH."
    }
}

$warPath = Join-Path $JenkinsRoot "jenkins.war"
$jenkinsHome = Join-Path $JenkinsRoot "data"
New-Item -ItemType Directory -Path $jenkinsHome -Force | Out-Null

if (-not (Test-Path $warPath) -or (Get-Item $warPath).Length -lt 50000000) {
    Write-Host "[Jenkins] Downloading jenkins.war from Tsinghua mirror..." -ForegroundColor Cyan
    curl.exe -L --retry 3 -o $warPath "https://mirrors.tuna.tsinghua.edu.cn/jenkins/war-stable/latest/jenkins.war"
}

# Pre-create out-of-the-box parameterized ShiJu CI/CD job in Jenkins
$jobDir = Join-Path $jenkinsHome "jobs\ShiJu-CI-CD"
New-Item -ItemType Directory -Path $jobDir -Force | Out-Null
$jobConfigPath = Join-Path $jobDir "config.xml"

$cnShiJu = "$([char]0x62FE)$([char]0x53E5)"
$configXml = @"
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <description>ShiJu ($cnShiJu) Multi-Platform CI/CD Pipeline - Automated Static Analysis, Widget Tests, Web Bundle, Windows Single-File EXE, and Signed Android APK Packaging.</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.BooleanParameterDefinition>
          <name>RUN_TESTS</name>
          <description>Run Flutter static analysis (flutter analyze) and unit/widget tests (flutter test)</description>
          <defaultValue>true</defaultValue>
        </hudson.model.BooleanParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>BUILD_WEB_AND_LAUNCHER</name>
          <description>Build Flutter Web release bundle and Windows single-file EXE launcher (ShiJu.exe)</description>
          <defaultValue>true</defaultValue>
        </hudson.model.BooleanParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>BUILD_WINDOWS_NATIVE</name>
          <description>Build Windows native C++ desktop bundle (flutter build windows --release)</description>
          <defaultValue>false</defaultValue>
        </hudson.model.BooleanParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>BUILD_ANDROID_APK</name>
          <description>Build signed Android release APK (dist/shiju-android-release.apk)</description>
          <defaultValue>true</defaultValue>
        </hudson.model.BooleanParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>CLEAN_BUILD</name>
          <description>Run flutter clean before building</description>
          <defaultValue>false</defaultValue>
        </hudson.model.BooleanParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>STRICT_TOOLCHAIN</name>
          <description>Fail immediately if optional C++ or Android SDK toolchains are missing</description>
          <defaultValue>false</defaultValue>
        </hudson.model.BooleanParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <scm class="hudson.scm.NullSCM"/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers/>
  <concurrentBuild>false</concurrentBuild>
  <customWorkspace>$ProjectDir</customWorkspace>
  <builders>
    <hudson.tasks.BatchFile>
      <command>@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "&amp; { `$flags = @('-Stage', 'All'); if (`$env:RUN_TESTS -eq 'false') { `$flags += '-SkipTests' }; if (`$env:BUILD_WEB_AND_LAUNCHER -eq 'false') { `$flags += '-SkipWebLauncher' }; if (`$env:BUILD_WINDOWS_NATIVE -eq 'false') { `$flags += '-SkipWindowsNative' }; if (`$env:BUILD_ANDROID_APK -eq 'false') { `$flags += '-SkipAndroidApk' }; if (`$env:CLEAN_BUILD -eq 'true') { `$flags += '-Clean' }; if (`$env:STRICT_TOOLCHAIN -eq 'true') { `$flags += '-StrictToolchain' }; &amp; '$ProjectDir\ci\run_pipeline.ps1' @flags }"</command>
      <configuredLocalRules/>
    </hudson.tasks.BatchFile>
  </builders>
  <publishers>
    <hudson.tasks.ArtifactArchiver>
      <artifacts>dist/**/*,build/reports/**/*</artifacts>
      <allowEmptyArchive>true</allowEmptyArchive>
      <onlyIfSuccessful>false</onlyIfSuccessful>
      <fingerprint>true</fingerprint>
      <defaultExcludes>true</defaultExcludes>
      <caseSensitive>true</caseSensitive>
      <followSymlinks>true</followSymlinks>
    </hudson.tasks.ArtifactArchiver>
  </publishers>
  <buildWrappers/>
</project>
"@
[System.IO.File]::WriteAllText($jobConfigPath, $configXml, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[Jenkins] Pre-configured job 'ShiJu-CI-CD' at $jobConfigPath" -ForegroundColor Green

# Configure domestic mirror for Jenkins update center
$updateCenterFile = Join-Path $jenkinsHome "hudson.model.UpdateCenter.xml"
$ucXml = @"
<?xml version='1.1' encoding='UTF-8'?>
<sites>
  <site>
    <id>default</id>
    <url>https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/current/update-center.json</url>
  </site>
</sites>
"@
[System.IO.File]::WriteAllText($updateCenterFile, $ucXml, (New-Object System.Text.UTF8Encoding($false)))

$env:JENKINS_HOME = $jenkinsHome
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Starting Jenkins Server on http://localhost:$Port" -ForegroundColor Green
Write-Host "  JENKINS_HOME : $jenkinsHome" -ForegroundColor Gray
Write-Host "  JAVA_EXE     : $JavaExe" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Cyan

if ($OpenBrowser) {
    Start-Process "http://localhost:$Port/job/ShiJu-CI-CD/"
}

& $JavaExe `
    "-Dhudson.model.DownloadService.noSignatureCheck=true" `
    "-Djenkins.install.runSetupWizard=false" `
    "-Dfile.encoding=UTF-8" `
    -jar $warPath `
    "--httpPort=$Port"
