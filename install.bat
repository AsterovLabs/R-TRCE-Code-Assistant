@echo off
:: =============================================================================
:: install.bat -- Double-Click Windows Installer for R-TRCE Code Assistant
:: Works seamlessly on Windows 10 & Windows 11
:: =============================================================================
:: Copyright (c) 2026 Asterov Labs. All Rights Reserved.
:: Licensed under the Asterov Labs Proprietary Software License.
:: See LICENSE file in the project root for full license terms.
:: =============================================================================

title R-TRCE Code Assistant Auto-Installer
cd /d "%~dp0"

echo ==================================================================
echo   R-TRCE Code Assistant Windows Auto-Installer
echo ==================================================================
echo.
echo Launching PowerShell installer with execution bypass...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"

if %errorlevel% neq 0 (
    echo.
    echo [!] An error occurred during installation.
    pause
    exit /b %errorlevel%
)

echo.
echo Press any key to exit installer...
pause >nul
