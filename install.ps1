<#
.SYNOPSIS
    Cross-Platform Auto-Installer for R-TRCE Code Assistant on Windows 10 and Windows 11.
.DESCRIPTION
    Installs R-TRCE Code Assistant, configures user PATH environment variables, creates Windows
    cmd wrappers (rtrce.cmd and rtrce-studio.cmd, plus legacy r-trce aliases), verifies R dependencies,
    and sets up Desktop and Start Menu shortcuts.

    Copyright (c) 2026 Asterov Labs. All Rights Reserved.
    Licensed under the Asterov Labs Proprietary Software License.
    See LICENSE file in the project root for full license terms.
.EXAMPLE
    irm https://raw.githubusercontent.com/AsterovLabs/R-TRCE-Code-Assistant/main/install.ps1 | iex
.EXAMPLE
    .\install.ps1 -InstallDir "C:\Tools\R-TRCE-Code-Assistant"
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "$env:LOCALAPPDATA\R-TRCE-Code-Assistant"
)

$ErrorActionPreference = "Stop"

Write-Host @"
  ____        _____ ____   ____ _____ 
 |  _ \      |_   _|  _ \ / ___| ____|
 | |_) |____   | | | |_) | |   |  _|  
 |  _ <|____|  | | |  _ <| |___|  ___ 
 |_| \_\       |_| |_| \_\\____|_____|
"@ -ForegroundColor Cyan

Write-Host "R-TRCE Code Assistant: Architectural Comprehension & Student Tutor Suite" -ForegroundColor White
Write-Host "Target Installation Path: $InstallDir`n" -ForegroundColor Yellow

# 1. Locate R Installation on Windows
Write-Host "Checking for R / Rscript.exe on Windows... " -NoNewline
$rscriptBin = ""

# Check PATH
$cmdR = Get-Command "Rscript.exe" -ErrorAction SilentlyContinue
if ($cmdR) {
    $rscriptBin = $cmdR.Source
}

# Check Registry
if (-not $rscriptBin) {
    $regPaths = @(
        "HKLM:\SOFTWARE\R-core\R",
        "HKLM:\SOFTWARE\R-core\R64",
        "HKCU:\SOFTWARE\R-core\R",
        "HKCU:\SOFTWARE\R-core\R64"
    )
    foreach ($rp in $regPaths) {
        try {
            if (Test-Path $rp) {
                $installPath = (Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue).InstallPath
                if ($installPath -and (Test-Path "$installPath\bin\Rscript.exe")) {
                    $rscriptBin = "$installPath\bin\Rscript.exe"
                    break
                }
            }
        } catch {
            # Ignore registry access errors
        }
    }
}

# Check Program Files
if (-not $rscriptBin) {
    $searchPaths = @("C:\Program Files\R", "C:\Program Files (x86)\R")
    foreach ($sp in $searchPaths) {
        $progDirs = Get-ChildItem $sp -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        foreach ($pd in $progDirs) {
            $candidate = "$($pd.FullName)\bin\Rscript.exe"
            if (Test-Path $candidate) {
                $rscriptBin = $candidate
                break
            }
        }
        if ($rscriptBin) { break }
    }
}

if ($rscriptBin) {
    Write-Host "Found!" -ForegroundColor Green -NoNewline
    Write-Host " ($rscriptBin)"
} else {
    Write-Host "Not found." -ForegroundColor Yellow
    Write-Host "`n[!] R is required to run R-TRCE Code Assistant." -ForegroundColor Yellow
    
    # Try winget if available on Windows 10/11
    $wingetCmd = Get-Command "winget.exe" -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        $installR = Read-Host "Would you like to install R automatically using winget? (Y/n)"
        if ($installR -ne 'n' -and $installR -ne 'N') {
            Write-Host "Installing R via winget (RProject.R)..." -ForegroundColor Cyan
            try {
                Start-Process -FilePath "winget.exe" -ArgumentList "install --id RProject.R -e --accept-package-agreements --accept-source-agreements" -Wait -NoNewWindow
            } catch {
                Write-Host "[!] Winget installation failed: $_" -ForegroundColor Yellow
            }
            
            # Re-check Program Files
            $progDirs = Get-ChildItem "C:\Program Files\R" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
            if ($progDirs) {
                $candidate = "$($progDirs[0].FullName)\bin\Rscript.exe"
                if (Test-Path $candidate) {
                    $rscriptBin = $candidate
                }
            }
        }
    } else {
        Write-Host "Please download and install R from: https://cran.r-project.org/bin/windows/base/" -ForegroundColor Cyan
        try {
            Start-Process "https://cran.r-project.org/bin/windows/base/"
        } catch {
            # Browser launch failed, just continue
        }
        Read-Host "Press Enter after you have completed the R installation to continue..."
        
        # Re-check after user says they installed
        $cmdR = Get-Command "Rscript.exe" -ErrorAction SilentlyContinue
        if ($cmdR) {
            $rscriptBin = $cmdR.Source
        }
    }
    
    if (-not $rscriptBin) {
        Write-Host "[!] Warning: R not found. R-TRCE Code Assistant files will be installed, but commands won't work until R is available." -ForegroundColor Yellow
        $rscriptBin = "Rscript.exe"
    }
}

# 2. Download or Copy Files to Installation Directory
$binDir = "$InstallDir\bin"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

$currentScriptDir = $PSScriptRoot
$localInstall = $false
if ($currentScriptDir -and (Test-Path "$currentScriptDir\r_trce.R") -and (Test-Path "$currentScriptDir\R")) {
    Write-Host "Installing from local directory: $currentScriptDir"
    Copy-Item -Path "$currentScriptDir\*" -Destination $InstallDir -Recurse -Force
    $localInstall = $true
}

if (-not $localInstall) {
    Write-Host "Downloading R-TRCE Code Assistant from GitHub..." -ForegroundColor Cyan
    $zipUrl = "https://github.com/AsterovLabs/R-TRCE-Code-Assistant/archive/refs/heads/main.zip"
    $tempZip = Join-Path $env:TEMP "rtrce-code-assistant-$(Get-Date -Format 'yyyyMMddHHmmss').zip"
    
    try {
        # Use TLS 1.2+ for compatibility
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing
    } catch {
        Write-Host "[!] Error: Failed to download R-TRCE Code Assistant from GitHub." -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red
        Write-Host "    Please download manually from: https://github.com/AsterovLabs/R-TRCE-Code-Assistant/releases" -ForegroundColor Yellow
        exit 1
    }
    
    $tempExtract = Join-Path $env:TEMP "rtrce-code-assistant-extract-$(Get-Date -Format 'yyyyMMddHHmmss')"
    if (Test-Path $tempExtract) { Remove-Item -Recurse -Force $tempExtract }
    
    try {
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
        $subDir = Get-ChildItem $tempExtract -Directory | Select-Object -First 1
        if (-not $subDir) {
            throw "Archive extraction produced no directories"
        }
        Copy-Item -Path "$($subDir.FullName)\*" -Destination $InstallDir -Recurse -Force
    } catch {
        Write-Host "[!] Error: Failed to extract R-TRCE Code Assistant archive." -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red
        exit 1
    } finally {
        Remove-Item -Force $tempZip -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $tempExtract -ErrorAction SilentlyContinue
    }
}

# Verify critical files exist
if (-not (Test-Path "$InstallDir\r_trce.R")) {
    Write-Host "[!] Error: Installation appears incomplete (r_trce.R not found)." -ForegroundColor Red
    Write-Host "    Please try again or download from: https://github.com/AsterovLabs/R-TRCE-Code-Assistant/releases" -ForegroundColor Yellow
    exit 1
}

# 3. Verify and Install Missing R Packages
if ($rscriptBin -and ($rscriptBin -ne "Rscript.exe" -or (Get-Command $rscriptBin -ErrorAction SilentlyContinue))) {
    Write-Host "Checking required R packages (manifest: R/common.R)..." -NoNewline
    try {
        # The list lives in required_packages() in R/common.R, so this installer,
        # install.sh and `rtrce doctor` all agree on what is required.
        $env:RTRCE_HOME = $InstallDir
        $checkScript = "source(file.path(Sys.getenv('RTRCE_HOME'), 'R', 'common.R')); cat(paste(missing_packages(), collapse=' '))"
        $missingPkgs = & "$rscriptBin" -e "$checkScript" 2>$null
        Remove-Item Env:\RTRCE_HOME -ErrorAction SilentlyContinue
        
        if (-not $missingPkgs -or $missingPkgs -eq "") {
            Write-Host " All installed!" -ForegroundColor Green
        } else {
            Write-Host " Missing: $missingPkgs" -ForegroundColor Yellow
            Write-Host "Installing missing packages from CRAN..." -ForegroundColor Cyan
            try {
                & "$rscriptBin" -e "install.packages(strsplit('$missingPkgs', ' ')[[1]], repos='https://cloud.r-project.org', quiet=TRUE)"
            } catch {
                Write-Host "[!] Warning: Auto-install failed. Run install.packages(required_packages()) inside R (the list is in R/common.R)." -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host " Skipped (R not fully available yet)." -ForegroundColor Yellow
    }
}

# 3b. Optional: Pre-install React Studio backend dependencies if Node.js & npm are present
$NpmCmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
if (-not $NpmCmd) { $NpmCmd = Get-Command "npm" -ErrorAction SilentlyContinue }
if ($NpmCmd) {
    $ServerModules = Join-Path $InstallDir "studio\server\node_modules"
    if (-not (Test-Path $ServerModules)) {
        Write-Host "Installing React Studio backend dependencies..." -ForegroundColor Cyan
        try {
            Push-Location (Join-Path $InstallDir "studio\server")
            & $NpmCmd.Source install --silent --omit=dev 2>$null
            Pop-Location
        } catch {}
    }
}

# 4. Generate Windows CMD Executable Wrappers
Write-Host "Generating CLI and Studio wrappers in $binDir..."

# rtrce.cmd (CLI router)
$escapedInstallDir = $InstallDir -replace '\\', '\\'
$escapedRscriptBin = $rscriptBin -replace '\\', '\\'

$rTrceCmd = @"
@echo off
setlocal
set "INSTALL_DIR=$InstallDir"
set "RSCRIPT_BIN=$rscriptBin"

if not exist "%RSCRIPT_BIN%" (
    where Rscript.exe >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%i in ('where Rscript.exe') do set "RSCRIPT_BIN=%%i"
    ) else (
        echo Error: Rscript.exe not found. Please ensure R is installed and on your PATH. 1>&2
        exit /b 1
    )
)

"%RSCRIPT_BIN%" "%INSTALL_DIR%\r_trce.R" %*
"@
Set-Content -Path "$binDir\rtrce.cmd" -Value $rTrceCmd -Encoding ASCII

# Legacy alias so existing habits and scripts keep working
Set-Content -Path "$binDir\r-trce.cmd" -Value $rTrceCmd -Encoding ASCII

# rtrce-studio.cmd (Interactive Studio)
$rTrceStudioCmd = @"
@echo off
setlocal
set "INSTALL_DIR=$InstallDir"
set "RSCRIPT_BIN=$rscriptBin"

if not exist "%RSCRIPT_BIN%" (
    where Rscript.exe >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%i in ('where Rscript.exe') do set "RSCRIPT_BIN=%%i"
    ) else (
        echo Error: Rscript.exe not found. Please ensure R is installed and on your PATH. 1>&2
        exit /b 1
    )
)

set "PORT=8083"
set "HOST=127.0.0.1"

echo Starting R-TRCE Code Assistant Studio on http://%HOST%:%PORT% ...
start http://%HOST%:%PORT%
"%RSCRIPT_BIN%" "%INSTALL_DIR%\app.R"
"@
Set-Content -Path "$binDir\rtrce-studio.cmd" -Value $rTrceStudioCmd -Encoding ASCII

# rtrce-react-studio.cmd (React Local Studio)
$rTrceReactStudioCmd = @"
@echo off
setlocal
call "$InstallDir\start_react_studio.bat" %*
"@
Set-Content -Path "$binDir\rtrce-react-studio.cmd" -Value $rTrceReactStudioCmd -Encoding ASCII

# Legacy alias for the Studio launcher
Set-Content -Path "$binDir\r-trce-studio.cmd" -Value $rTrceStudioCmd -Encoding ASCII

# 5. Add $binDir to User Environment PATH
Write-Host "Configuring User PATH environment variable..."
$currentUserPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
if (-not $currentUserPath) { $currentUserPath = "" }

if ($currentUserPath -notlike "*$binDir*") {
    # Avoid adding trailing semicolons
    if ($currentUserPath -and -not $currentUserPath.EndsWith(";")) {
        $newPath = "$currentUserPath;$binDir"
    } else {
        $newPath = "$currentUserPath$binDir"
    }
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
    $env:Path = "$env:Path;$binDir"
    Write-Host "Added $binDir to User PATH." -ForegroundColor Green
} else {
    Write-Host "$binDir is already on PATH." -ForegroundColor Green
}

# 6. Create Desktop and Start Menu Shortcuts
try {
    $wshShell = New-Object -ComObject WScript.Shell
    
    # Desktop Shortcut (Shiny Studio)
    $desktopPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
    if ($desktopPath -and (Test-Path $desktopPath)) {
        $shortcutDesktop = $wshShell.CreateShortcut("$desktopPath\R-TRCE Code Assistant Studio.lnk")
        $shortcutDesktop.TargetPath = "$binDir\rtrce-studio.cmd"
        $shortcutDesktop.WorkingDirectory = $InstallDir
        $shortcutDesktop.Description = "R-TRCE Code Assistant Interactive Studio & Guided Walkthrough"
        $shortcutDesktop.Save()

        $shortcutReactDesktop = $wshShell.CreateShortcut("$desktopPath\R-TRCE React Studio.lnk")
        $shortcutReactDesktop.TargetPath = "$binDir\rtrce-react-studio.cmd"
        $shortcutReactDesktop.WorkingDirectory = $InstallDir
        $shortcutReactDesktop.Description = "R-TRCE Code Assistant React Local Studio (Monaco Editor)"
        $shortcutReactDesktop.Save()
    }
    
    # Start Menu Shortcut
    $startMenuPrograms = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
    if ($startMenuPrograms -and (Test-Path $startMenuPrograms)) {
        $shortcutStart = $wshShell.CreateShortcut("$startMenuPrograms\R-TRCE Code Assistant Studio.lnk")
        $shortcutStart.TargetPath = "$binDir\rtrce-studio.cmd"
        $shortcutStart.WorkingDirectory = $InstallDir
        $shortcutStart.Description = "R-TRCE Code Assistant Interactive Studio & Guided Walkthrough"
        $shortcutStart.Save()

        $shortcutReactStart = $wshShell.CreateShortcut("$startMenuPrograms\R-TRCE React Studio.lnk")
        $shortcutReactStart.TargetPath = "$binDir\rtrce-react-studio.cmd"
        $shortcutReactStart.WorkingDirectory = $InstallDir
        $shortcutReactStart.Description = "R-TRCE Code Assistant React Local Studio (Monaco Editor)"
        $shortcutReactStart.Save()
    }
    
    Write-Host "Created Desktop & Start Menu shortcuts." -ForegroundColor Green
} catch {
    Write-Verbose "Shortcut creation skipped: $_"
}

Write-Host @"

==================================================================
  R-TRCE Code Assistant installed successfully on Windows!
==================================================================

Quick Start Commands (in PowerShell or CMD):
  rtrce tutor script.R        Student walkthrough & pitfall audit
  rtrce pitfalls script.R     Audit beginner traps & memory bottlenecks
  rtrce quiz script.R         Generate comprehension quiz
  rtrce explain script.R      Architectural explanation & dependency flow
  rtrce help                  Every command and option
  rtrce-react-studio          Launch React local studio (Monaco & Asterov UI)
  rtrce-studio                Launch interactive Shiny web studio

You can also launch "R-TRCE React Studio" or "R-TRCE Code Assistant Studio" directly from your Desktop or Start Menu!

NOTE: The older names 'r-trce' and 'r-trce-studio' still work as aliases.
NOTE: You may need to restart your terminal for PATH changes to take effect.
"@ -ForegroundColor Green
