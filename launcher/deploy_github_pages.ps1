param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

if (-not $SkipBuild -or -not (Test-Path "build\web\main.dart.js")) {
    Write-Host "[1/3] Building ShiJu Web PWA for GitHub Pages (/ShiJu/)..." -ForegroundColor Cyan
    flutter build web --release --base-href "/ShiJu/" --no-web-resources-cdn
    New-Item -Path "build\web\.nojekyll" -ItemType File -Force | Out-Null
    Copy-Item "build\web\index.html" "build\web\404.html" -Force
}

Write-Host "[2/3] Publishing build/web to origin/gh-pages branch..." -ForegroundColor Cyan
$TempGitDir = Join-Path $env:TEMP ("shiju_gh_pages_" + [guid]::NewGuid().ToString("N"))
New-Item -Path $TempGitDir -ItemType Directory -Force | Out-Null

try {
    Copy-Item -Path "build\web\*" -Destination $TempGitDir -Recurse -Force
    New-Item -Path (Join-Path $TempGitDir ".nojekyll") -ItemType File -Force | Out-Null

    Push-Location $TempGitDir
    git init -b gh-pages
    git config user.name "Leisure03"
    git config user.email "leisure03@users.noreply.github.com"
    git add -A
    git commit -m "Deploy ShiJu PWA for iPhone 17 to GitHub Pages"
    git remote add origin https://github.com/Leisure03/ShiJu.git
    git push -f origin gh-pages:gh-pages
    Pop-Location
    Write-Host "  -> Pushed to origin/gh-pages successfully!" -ForegroundColor Green
} finally {
    if (Test-Path $TempGitDir) {
        Remove-Item -Path $TempGitDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "[3/3] Checking / Activating GitHub Pages site via API..." -ForegroundColor Cyan
try {
    $tmp = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmp, "protocol=https`nhost=github.com`n`n")
    $credOutput = cmd /c "git credential fill < `"$tmp`""
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    $tokenLine = $credOutput | Where-Object { $_ -match "^password=" } | Select-Object -First 1
    if ($tokenLine) {
        $token = $tokenLine.Substring("password=".Length).Trim()
        $headers = @{
            "Authorization"        = "Bearer $token"
            "Accept"               = "application/vnd.github+json"
            "X-GitHub-Api-Version" = "2022-11-28"
            "User-Agent"           = "ShiJu-Deploy-Script"
        }
        $body = '{"source":{"branch":"gh-pages","path":"/"}}'
        try {
            $resp = Invoke-RestMethod -Uri "https://api.github.com/repos/Leisure03/ShiJu/pages" -Method Post -Headers $headers -Body $body -ContentType "application/json"
            Write-Host "  -> GitHub Pages enabled automatically: $($resp.html_url)" -ForegroundColor Green
        } catch {
            try {
                $resp = Invoke-RestMethod -Uri "https://api.github.com/repos/Leisure03/ShiJu/pages" -Method Get -Headers $headers
                Write-Host "  -> GitHub Pages is active: $($resp.html_url) (status: $($resp.status))" -ForegroundColor Green
            } catch {
                Write-Host "  -> Note: Please select 'gh-pages' branch in GitHub Settings -> Pages if not yet enabled." -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "  -> Skipped API activation check." -ForegroundColor Yellow
}

Write-Host "============================================================" -ForegroundColor Green
Write-Host "  ShiJu GitHub Pages PWA Deployment Complete!" -ForegroundColor Green
Write-Host "  iPhone 17 URL: https://leisure03.github.io/ShiJu/" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Green
