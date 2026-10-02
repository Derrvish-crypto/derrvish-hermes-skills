# Chrome CDP Auto-Start on Windows

## Problem
Windows Scheduled Tasks with `InteractiveToken` show visible cmd.exe windows even when launching `pythonw.exe`. Same issue applies to Chrome auto-start — need hidden window at login.

## Solution: VBS Wrapper (Window Style 0)

### File: `start_chrome_cdp.vbs`
```vbs
Set WshShell = CreateObject("WScript.Shell")
' Запуск Chrome с CDP в скрытом режиме (window style 0)
WshShell.Run """C:\Program Files\Google\Chrome\Application\chrome.exe"" --remote-debugging-port=9222 --user-data-dir=""%USERPROFILE%\BrowserHarness-Profile"" --no-first-run", 0, False
Set WshShell = Nothing
```

### File: `start_chrome_cdp.bat` (for manual use)
```bat
@echo off
set CHROME_PATH="C:\Program Files\Google\Chrome\Application\chrome.exe"
set PROFILE_DIR=%USERPROFILE%\BrowserHarness-Profile
set CDP_PORT=9222

start "" %CHROME_PATH% --remote-debugging-port=%CDP_PORT% --user-data-dir="%PROFILE_DIR%" --no-first-run
timeout /t 3 /nobreak >nul

REM Verify CDP is listening
curl -s http://127.0.0.1:%CDP_PORT%/json/version | findstr "Browser" >nul
if %errorlevel% equ 0 (
    echo Chrome CDP is ready on port %CDP_PORT%
) else (
    echo WARNING: Could not verify CDP connection
)

set BU_CDP_URL=http://127.0.0.1:%CDP_PORT%
echo Ready to use browser-harness!
```

### Install to Auto-Start
Copy VBS to Windows startup folder:
```bash
cp start_chrome_cdp.vbs "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\chrome_cdp_autostart.vbs"
```

Or via PowerShell:
```powershell
Copy-Item "start_chrome_cdp.vbs" "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\"
```

### Verify After Login
```bash
curl -s http://127.0.0.1:9222/json/version | grep Browser
# Expected: "Browser": "Chrome/xxx.xxxxx"
```

### Disable Auto-Start
Delete the VBS file from startup folder:
```
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\chrome_cdp_autostart.vbs
```

## Key Points
- **VBS with window style 0** = completely hidden, no console window
- **Isolated profile** (`BrowserHarness-Profile`) keeps automation separate from main Chrome
- **No scheduled task needed** — Windows startup folder handles it natively
- **Verified on:** Windows 11 Pro 25H2, Chrome 149.0.7827.103
