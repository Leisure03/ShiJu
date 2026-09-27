param(
    [string]$ProjectDir = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDir = "",
    [switch]$SkipFlutterBuild,
    [switch]$CI
)

$ErrorActionPreference = "Stop"

$projDir = (Resolve-Path $ProjectDir).Path
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $outDir = $projDir
} else {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    $outDir = (Resolve-Path $OutputDir).Path
}

$launcherDir = Join-Path $projDir "launcher"
$webDir = Join-Path $projDir "web"
$webBuildDir = Join-Path $projDir "build\web"
$zipPath = Join-Path $launcherDir "web_bundle.zip"
$icoPath = Join-Path $launcherDir "shiju.ico"
$csPath = Join-Path $launcherDir "ShiJuLauncher.cs"
$cnName = "$([char]0x62FE)$([char]0x53E5)_ShiJu.exe"
$exeOutPath = Join-Path $outDir $cnName
$enExePath = Join-Path $outDir "ShiJu.exe"

Add-Type -AssemblyName System.Drawing

# 1. Generate Transparent 32x32 favicon.png so the --app window title bar has NO ugly Flutter icon on the top-left
$favBmp = New-Object System.Drawing.Bitmap(32, 32)
$favG = [System.Drawing.Graphics]::FromImage($favBmp)
$favG.Clear([System.Drawing.Color]::Transparent)
$favG.Dispose()
$favPath = Join-Path $webDir "favicon.png"
$favBmp.Save($favPath, [System.Drawing.Imaging.ImageFormat]::Png)
$favBmp.Dispose()

# 2. Generate Cinnabar Seal Icon (shiju.ico & web/icons/*.png)
$bmp = New-Object System.Drawing.Bitmap(192, 192)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$cinnabarBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 161, 152, 168))
$xuanPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 248, 205, 237), 6.0)
$xuanBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 248, 205, 237))

$g.FillRectangle($cinnabarBrush, 6, 6, 180, 180)
$g.DrawRectangle($xuanPen, 18, 18, 156, 156)

$font = New-Object System.Drawing.Font("SimSun", 58, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center

$rectTop = New-Object System.Drawing.RectangleF(0, 24, 192, 76)
$rectBottom = New-Object System.Drawing.RectangleF(0, 92, 192, 76)
$charShi = "$([char]0x62FE)"
$charJu = "$([char]0x53E5)"
$g.DrawString($charShi, $font, $xuanBrush, $rectTop, $sf)
$g.DrawString($charJu, $font, $xuanBrush, $rectBottom, $sf)
$g.Dispose()

# Save to web/icons/* to replace all default blue Flutter icons
$iconsDir = Join-Path $webDir "icons"
if (Test-Path $iconsDir) {
    $bmp.Save((Join-Path $iconsDir "Icon-192.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Save((Join-Path $iconsDir "Icon-512.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Save((Join-Path $iconsDir "Icon-maskable-192.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Save((Join-Path $iconsDir "Icon-maskable-512.png"), [System.Drawing.Imaging.ImageFormat]::Png)
}

# Create 64x64 ICO for exe file
$icoBmp = New-Object System.Drawing.Bitmap($bmp, 64, 64)
$msPng = New-Object System.IO.MemoryStream
$icoBmp.Save($msPng, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $msPng.ToArray()
$msPng.Dispose()
$icoBmp.Dispose()
$bmp.Dispose()

$fsIco = [System.IO.File]::Create($icoPath)
$bw = New-Object System.IO.BinaryWriter($fsIco)
$bw.Write([UInt16]0)
$bw.Write([UInt16]1)
$bw.Write([UInt16]1)
$bw.Write([Byte]64)
$bw.Write([Byte]64)
$bw.Write([Byte]0)
$bw.Write([Byte]0)
$bw.Write([UInt16]1)
$bw.Write([UInt16]32)
$bw.Write([UInt32]$pngBytes.Length)
$bw.Write([UInt32]22)
$bw.Write($pngBytes)
$bw.Flush()
$bw.Dispose()
$fsIco.Dispose()

Write-Host "1. Icons updated (transparent favicon + Cinnabar Seal app icons)."

# 3. Build Flutter Web Release
if (-not $SkipFlutterBuild -or -not (Test-Path (Join-Path $webBuildDir "index.html"))) {
    Push-Location $projDir
    try {
        flutter build web --release --no-web-resources-cdn
        if ($LASTEXITCODE -ne 0) {
            throw "flutter build web --release failed with exit code: $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "Skipping flutter build web --release (reusing existing $webBuildDir)."
}

# 4. Pack build\web into web_bundle.zip
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($webBuildDir, $zipPath)
Write-Host "2. Embedded bundle created: $zipPath"

# Stop running instances if any so we can overwrite the exe
if (-not $CI) {
    Get-Process | Where-Object { $_.ProcessName -like "*ShiJu*" } | Stop-Process -Force -ErrorAction SilentlyContinue
}

# 5. Compile ShiJuLauncher.cs into standalone Windows executable
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
& $csc /nologo /utf8output /target:winexe /optimize+ `
    "/out:$exeOutPath" `
    "/win32icon:$icoPath" `
    "/resource:$zipPath,web_bundle.zip" `
    /r:System.dll `
    /r:System.Core.dll `
    /r:System.Drawing.dll `
    /r:System.Windows.Forms.dll `
    /r:System.IO.Compression.dll `
    "$csPath"

if ($LASTEXITCODE -ne 0) {
    throw "csc.exe failed with exit code: $LASTEXITCODE"
}

Copy-Item $exeOutPath $enExePath -Force

if (Test-Path "D:\antigravity_proj") {
    Copy-Item $exeOutPath (Join-Path "D:\antigravity_proj" $cnName) -Force -ErrorAction SilentlyContinue
    Copy-Item $enExePath (Join-Path "D:\antigravity_proj" "ShiJu.exe") -Force -ErrorAction SilentlyContinue
}

Write-Host "3. Build succeeded!"
Get-Item $exeOutPath, $enExePath | Select-Object FullName, Length, LastWriteTime
