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
call "%~dp0start_react_studio.bat" %*
