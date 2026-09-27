param(
    [int]$Port = 8080,
    [switch]$Rebuild
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

if ($Rebuild -or -not (Test-Path "build\web\main.dart.js")) {
    Write-Host "[1/2] Building ShiJu iOS / iPhone 17 PWA web bundle..." -ForegroundColor Cyan
    flutter build web --release
}

Write-Host "[2/2] Starting LAN PWA server (Port: $Port)..." -ForegroundColor Green
dart run launcher\serve_pwa.dart $Port
