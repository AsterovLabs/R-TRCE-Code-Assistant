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

:: 2. Locate node.exe
set "NODE_BIN=node.exe"
where node >nul 2>nul
if %errorlevel% neq 0 (
    if exist "%ProgramFiles%\nodejs\node.exe" (
        set "NODE_BIN=%ProgramFiles%\nodejs\node.exe"
    ) else (
        echo ==================================================================
        echo   [i] Note: Node.js was not detected on this computer.
        echo   Launching interactive Shiny Studio workspace instead...
        echo   (Install Node.js v18+ from https://nodejs.org to use React Studio)
        echo ==================================================================
        call "%~dp0start_studio.bat"
        exit /b %ERRORLEVEL%
    )
)
echo [OK] Found Node.js: %NODE_BIN%

:: 3. Check backend dependencies
if not exist "%~dp0studio\server\node_modules\" (
    echo [*] Installing backend dependencies...
    cd /d "%~dp0studio\server"
    call npm install --silent
    cd /d "%~dp0"
)

:: 4. Check client build
if not exist "%~dp0studio\client\dist\" (
    echo [*] Building React client...
    cd /d "%~dp0studio\client"
    call npm install --silent
    call npm run build
    cd /d "%~dp0"
)

set "PORT=8084"
set "HOST=127.0.0.1"

echo ==================================================================
echo   R-TRCE React Studio running at: http://%HOST%:%PORT%
echo ==================================================================

set "RSCRIPT_BIN=%RSCRIPT_BIN%"
set "ELECTRON_BIN=%~dp0studio\server\node_modules\.bin\electron.cmd"

if exist "%ELECTRON_BIN%" (
    echo [*] Launching Native Desktop IDE...
    call "%ELECTRON_BIN%" "%~dp0studio\server\electron-main.js"
    exit /b %ERRORLEVEL%
)

:: Standalone App Window Fallback (Edge / Chrome)
start msedge.exe --app="http://%HOST%:%PORT%" 2>nul || start chrome.exe --app="http://%HOST%:%PORT%" 2>nul || start http://%HOST%:%PORT%
"%NODE_BIN%" "%~dp0studio\server\server.js"

pause
