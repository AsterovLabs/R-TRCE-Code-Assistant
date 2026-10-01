@echo off
:: =============================================================================
:: start_studio.bat -- Double-Click Studio Launcher for Windows 10 & 11
:: =============================================================================
:: Copyright (c) 2026 Asterov Labs. All Rights Reserved.
:: Licensed under the Asterov Labs Proprietary Software License.
:: See LICENSE file in the project root for full license terms.
:: =============================================================================

title R-TRCE Code Assistant Studio
cd /d "%~dp0"

set "RSCRIPT_BIN=Rscript.exe"

where Rscript >nul 2>nul
if %errorlevel% neq 0 (
    :: Try standard Program Files path
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

set "PORT=8083"
set "HOST=127.0.0.1"

echo ==================================================================
echo   Starting R-TRCE Code Assistant Interactive Studio
echo   Access at: http://%HOST%:%PORT%
echo ==================================================================

start http://%HOST%:%PORT%
"%RSCRIPT_BIN%" "%~dp0app.R"

pause
