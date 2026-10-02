@echo off
chcp 65001 >nul 2>&1
title GPU Rollback - Admin Required

REM Auto-elevate if not admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ========================================
echo   GPU ROLLBACK — Restore defaults
echo ========================================
echo.

REM Delete registry keys
reg delete HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers /v TdrDelay /f >nul 2>&1 && echo [OK] TdrDelay deleted || echo [--] TdrDelay not found
reg delete HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers /v HwSchMode /f >nul 2>&1 && echo [OK] HwSchMode deleted || echo [--] HwSchMode not found  
reg delete HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers /v DisableMpo3 /f >nul 2>&1 && echo [OK] DisableMpo3 deleted || echo [--] DisableMpo3 not found

echo.
echo Verifying...
for %%K in (TdrDelay HwSchMode DisableMpo3) do (
    reg query HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers /v %%K >nul 2>&1
    if %errorLevel% equ 0 (echo [!!] %%K STILL EXISTS!) else echo [OK] %%K confirmed removed
)

echo.
REM Run ViVeTool — adjust path as needed
set VIVETOOL=%LOCALAPPDATA%\Temp\vivetool\ViVeTool.exe
if exist "%VIVETOOL%" (
    echo Running ViVeTool /enable /id:58989092...
    "%VIVETOOL%" /enable /id:58989092
) else (
    echo [!!] ViVeTool not found at %VIVETOOL%
)

echo.
echo ========================================
echo   DONE — REBOOT REQUIRED!
echo ========================================
timeout /t 10
