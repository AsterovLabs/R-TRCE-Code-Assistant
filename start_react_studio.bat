@echo off
:: =============================================================================
:: start_react_studio.bat -- Double-Click React Studio Launcher for Windows 10 & 11
:: =============================================================================
:: Copyright (c) 2026 Asterov Labs. All Rights Reserved.
:: Licensed under the Asterov Labs Proprietary Software License.
:: See LICENSE file in the project root for full license terms.
:: =============================================================================

title R-TRCE React Studio
cd /d "%~dp0"

echo ==================================================================
echo   Starting R-TRCE Code Assistant React Studio (Windows)
echo ==================================================================

:: 1. Locate Rscript.exe
set "RSCRIPT_BIN=Rscript.exe"
where Rscript >nul 2>nul
if %errorlevel% neq 0 (
    for /d %%D in ("%ProgramFiles%\R\R-*") do (
        if exist "%%D\bin\Rscript.exe" set "RSCRIPT_BIN=%%D\bin\Rscript.exe"
    )
)

if not exist "%RSCRIPT_BIN%" (
    where Rscript >nul 2>nul
    if %errorlevel% neq 0 (
        echo [!] Error: Rscript.exe not found.
        echo Please ensure R is installed from https://cran.r-project.org/
        pause
        exit /b 1
    )
)
echo [OK] Found Rscript: %RSCRIPT_BIN%

:: 2. Locate Electron runtime
set "ELECTRON_BIN="
if exist "%~dp0studio\server\node_modules\electron\dist\electron.exe" (
    set "ELECTRON_BIN=%~dp0studio\server\node_modules\electron\dist\electron.exe"
)
if not defined ELECTRON_BIN (
    if exist "%~dp0studio\server\node_modules\.bin\electron.cmd" (
        set "ELECTRON_BIN=%~dp0studio\server\node_modules\.bin\electron.cmd"
    )
)
if not defined ELECTRON_BIN (
    where electron >nul 2>nul
    if not errorlevel 1 set "ELECTRON_BIN=electron"
)

:: 3. If Electron is not yet installed and npm exists, install dependencies
if not defined ELECTRON_BIN (
    where npm >nul 2>nul
    if not errorlevel 1 (
        echo [*] Installing local desktop runtime dependencies...
        cd /d "%~dp0studio\server"
        call npm install --silent
        cd /d "%~dp0"
        if exist "%~dp0studio\server\node_modules\electron\dist\electron.exe" (
            set "ELECTRON_BIN=%~dp0studio\server\node_modules\electron\dist\electron.exe"
        )
    )
)

if not defined ELECTRON_BIN (
    echo [!] Error: Native desktop Electron runtime not found.
    echo Please run 'npm install' inside studio\server or ensure internet access on first launch.
    pause
    exit /b 1
)

:: 4. Check client build exists
if not exist "%~dp0studio\client\dist\" (
    where npm >nul 2>nul
    if not errorlevel 1 (
        echo [*] Building React client...
        cd /d "%~dp0studio\client"
        call npm install --silent
        call npm run build
        cd /d "%~dp0"
    )
)

set "PORT=8084"
set "HOST=127.0.0.1"
set "RSCRIPT_BIN=%RSCRIPT_BIN%"

echo [*] Launching R-TRCE Studio Native Desktop IDE...
call "%ELECTRON_BIN%" "%~dp0studio\server\electron-main.js" %*
exit /b %ERRORLEVEL%
