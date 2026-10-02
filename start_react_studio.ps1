# =============================================================================
# start_react_studio.ps1 -- PowerShell Launcher for R-TRCE React Studio (Windows)
# =============================================================================
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================

param (
    [string]$Port = "8084",
    [string]$Host = "127.0.0.1"
)

$Host.UI.RawUI.WindowTitle = "R-TRCE React Studio"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  R-TRCE Code Assistant -- React Studio (PowerShell)" -ForegroundColor Cyan
Write-Host "  Asterov Labs (c) 2026" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# 1. Locate Rscript
$RscriptCmd = Get-Command "Rscript.exe" -ErrorAction SilentlyContinue
$RscriptBin = if ($RscriptCmd) { $RscriptCmd.Source } else { $null }

if (-not $RscriptBin) {
    $Candidates = Get-ChildItem -Path "$env:ProgramFiles\R" -Filter "R-*" -Directory -ErrorAction SilentlyContinue
    foreach ($cand in $Candidates) {
        $binPath = Join-Path $cand.FullName "bin\Rscript.exe"
        if (Test-Path $binPath) {
            $RscriptBin = $binPath
            break
        }
    }
}

if (-not $RscriptBin) {
    Write-Error "Rscript.exe not found. Please install R from https://cran.r-project.org/"
    exit 1
}
Write-Host "[OK] Found R: $RscriptBin" -ForegroundColor Green

# 2. Locate Node.js
$NodeCmd = Get-Command "node.exe" -ErrorAction SilentlyContinue
if (-not $NodeCmd) {
    Write-Host "==================================================================" -ForegroundColor Yellow
    Write-Host "  [i] Note: Node.js was not detected on this machine." -ForegroundColor Yellow
    Write-Host "  Launching interactive Shiny Studio workspace instead..." -ForegroundColor Yellow
    Write-Host "  (Install Node.js v18+ from https://nodejs.org to use React Studio)" -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Yellow
    & (Join-Path $ScriptDir "start_studio.bat")
    exit $LASTEXITCODE
}
Write-Host "[OK] Found Node: $($NodeCmd.Source)" -ForegroundColor Green

# 3. Ensure backend dependencies
$ServerModules = Join-Path $ScriptDir "studio\server\node_modules"
if (-not (Test-Path $ServerModules)) {
    Write-Host "[*] Installing backend dependencies..." -ForegroundColor Yellow
    Push-Location (Join-Path $ScriptDir "studio\server")
    npm install --silent
    Pop-Location
}

# 4. Ensure client build
$ClientDist = Join-Path $ScriptDir "studio\client\dist"
if (-not (Test-Path $ClientDist)) {
    Write-Host "[*] Building React frontend client..." -ForegroundColor Yellow
    Push-Location (Join-Path $ScriptDir "studio\client")
    npm install --silent
    npm run build
    Pop-Location
}

# 5. Launch Native Desktop IDE or Standalone App Window
$Url = "http://$Host`:$Port"
$ElectronBin = Join-Path $ScriptDir "studio\server\node_modules\.bin\electron.cmd"

$env:RSCRIPT_BIN = $RscriptBin
$env:PORT = $Port
$env:HOST = $Host

if (Test-Path $ElectronBin) {
    Write-Host "[*] Launching R-TRCE Code Assistant Native Desktop IDE..." -ForegroundColor Green
    & $ElectronBin (Join-Path $ScriptDir "studio\server\electron-main.js")
    exit $LASTEXITCODE
}

# Standalone App Window Fallback
if (Get-Command msedge.exe -ErrorAction SilentlyContinue) {
    Start-Process msedge.exe -ArgumentList "--app=$Url"
} elseif (Get-Command chrome.exe -ErrorAction SilentlyContinue) {
    Start-Process chrome.exe -ArgumentList "--app=$Url"
} else {
    Start-Process $Url
}

Push-Location (Join-Path $ScriptDir "studio\server")
& node.exe "server.js"
Pop-Location
