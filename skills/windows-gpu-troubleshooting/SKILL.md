---
name: windows-gpu-troubleshooting
description: Diagnose and fix NVIDIA GPU issues on Windows — black screen, TDR, MPO, driver scheduling, ViVeTool feature control. Covers RTX 5090 + Windows 25H2 patterns, registry modifications, rollback procedures, and the UAC elevation deadlock workaround.
---

# Windows GPU Troubleshooting

Diagnose and fix NVIDIA GPU issues on Windows: black screen freezes, TDR timeouts, MPO conflicts, hardware scheduling problems, and KB-related feature control via ViVeTool.

## Triggers

- Black screen / freeze after GPU-intensive operation or system update
- Intermittent display drops with RTX 4090/5090 on Windows 24H2/25H2
- User asks to audit, apply, or rollback GPU-related registry changes
- ViVeTool feature enable/disable for graphics-related KBs
- WHEA-Logger events in Event Viewer (hardware errors)
- Kernel-Power 41 (unexpected shutdown) + Disk I/O timeout cluster

## WHEA-Logger & Hardware Error Diagnosis

**WHEA-Logger ID 17 (Error)** = Windows Hardware Error Architecture — corrected hardware error detected. Common causes on i9-13900K + RTX 5090:
- Vcore voltage droop under load
- CPU core thermal throttling
- Memory ECC correction (if ECC RAM)

**Kernel-Power Event ID 41 (Critical)** = unexpected shutdown — system did not shut down cleanly. When paired with WHEA-Logger + Disk timeout events at the same timestamp, indicates:
- PSU voltage rail instability under GPU load
- Forced power button / PSU protection trip
- Motherboard VRM thermal shutdown

**Diagnostic commands:**
```powershell
# Get WHEA details (error type, processor vs memory):
Get-WinEvent -FilterHashtable @{LogName='System'; ID=17} | Select-Object -First 5 | Format-List

# Check for Kernel-Power 41 cluster with Disk events:
Get-WinEvent -FilterHashtable @{LogName='System'; ID=@(41,26,55)} | Sort-Object TimeCreated -Descending | Select-Object -First 10

# Current GPU temps + power draw:
nvidia-smi --query-gpu=temperature.gpu,power.draw,power.limit,utilization.gpu --format=csv

# CPU thermal history (last boot):
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Thermal'} | Select-Object -First 5
```

**When WHEA + Kernel-Power 41 appear together:** Check PSU stability first (Seasonic TX-1600 ATX 3.1 on RTX 5090 is known stable, but verify PCIe 5.0 power delivery), then CPU Vcore settings in BIOS.

### WHEA / KP41 field decoding (when the message text is truncated)

```powershell
Get-WinEvent -FilterHashtable @{LogName='System'; ID=17; StartTime=<window>} | Select-Object -First 1 | ForEach-Object { $_.ToXml() }
```
- WHEA `ErrorSource=4` → Advanced Error Reporting = a **PCIe link** error, not CPU/memory. The VendorID/DeviceID in the event name the reporting **root port** (chipset), NOT the GPU — map the endpoint with `nvidia-smi --query-gpu=pci.bus_id --format=csv`.
- `UncorrectableErrorStatus 0x4000` = Bad TLP. A single AER Bad-TLP 20–30 s before a GPU TDR under load = link margin exceeded (usually an OC profile), not a dead component — verify single-event vs cluster over 30 days before blaming hardware.
- Kernel-Power 41 with `BugcheckCode=0` + non-zero `PowerButtonTimestamp` = forced power button by the user; the system **hung, it did not BSOD** — hunt the hang cause (TDR/blackbox), do not look for a dump.

**Symptom pattern — black screen + fans spinning at uncontrolled max:** the GPU driver died mid-session; with the driver gone, Windows power/fan control is lost and the EC spins fans hard. The fan scream is a consequence, not the cause.

## GPU Black Screen / Hang: WER LiveKernelEvent Buckets (FIRST STOP)

For any black screen / GPU hang, check the **Application** log for LiveKernelEvent fault buckets — the bucket name usually names the driver and the trigger:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Windows Error Reporting'; StartTime=(Get-Date).AddHours(-48)} |
  Where-Object { $_.Message -match 'LiveKernelEvent|Tdr|Blackscreen' } |
  ForEach-Object { '{0} :: {1}' -f $_.TimeCreated, ($_.Message -split "`r?`n")[0] }
```

- `LKD_0x141_Tdr:N_IMAGE_<driver>_...` — GPU TDR timeout. A trailing `UserOC` (e.g. `nvlddmkm.sys_Blackwell_UserOC`) = a **user overclock profile was active** at fault time (MSI Afterburner/RivaTuner) — primary suspect.
- `LKD_0x1B8_*_Blackscreen_Blackbox_dxgkrnl!...` — display pipeline death; its timestamp ≈ the moment the user actually saw the black screen (typically ×2: Intel + NV blackbox).
- Verified event order: WHEA AER (link) → 0x141 TDR → 0x1B8 blackbox(es) → forced power button. All WER events land before the power cut — the system is still (barely) alive writing them.

**Anchoring "about an hour ago" incidents:** the user's memory usually marks the **reboot**, not the crash. Anchor on `Win32_OperatingSystem LastBootUpTime` + KP41, then walk the timeline BACKWARDS (boot events → WER → WHEA → app logs) to find the true fault moment.

## Common Fixes (RTX 5090 + Windows 25H2)

| Symptom | Registry Key | Path | Value | Default |
|---------|-------------|------|-------|---------|
| TDR timeout | `TdrDelay` | `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` | `8` (REG_DWORD) | `2` |
| HW scheduling | `HwSchMode` | same | `2` = preferred | key absent / `1` |
| MPO conflicts | `DisableMpo3` | same | `1` = disabled | key absent |
| Low Latency Profile (KB5094126/KB5094135) | N/A — ViVeTool | ID `58989092` | `/disable` to disable | enabled by default |

All registry changes require **reboot** to take effect.

## Audit Current State

```python
import subprocess
keys = ['TdrDelay', 'HwSchMode', 'DisableMpo3']
for k in keys:
    r = subprocess.run(['reg', 'query', r'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers', '/v', k], capture_output=True)
    out = r.stdout.decode('cp1251', errors='replace').strip()
    if r.returncode == 0:
        print(f'[!!] {k}: EXISTS — {out}')
    else:
        print(f'[OK] {k}: not present')
```

**Important:** `reg` output is cp1251-encoded on Russian Windows — decode with `cp1251`, not utf-8.

## Apply Fixes (requires admin)

```batch
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /t REG_DWORD /d 8 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v DisableMpo3 /t REG_DWORD /d 1 /f
```

## Rollback to Default (requires admin)

```batch
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v DisableMpo3 /f
```

## ViVeTool Usage

### Download (latest v0.3.4)

GitHub requires proper User-Agent and correct tag format (`v` prefix):

```bash
curl -L -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
  -o ViVeTool.zip \
  "https://github.com/thebookisclosed/ViVe/releases/download/v0.3.4/ViVeTool-v0.3.4-IntelAmd.zip"
```

For ARM64 (Snapdragon): replace filename with `ViVeTool-v0.3.4-SnapdragonArm64.zip`.

### Commands (run from same directory as ViVeTool.exe)

```batch
ViVeTool /query                    :: list custom feature configs
ViVeTool /disable /id:58989092     :: disable Low Latency Profile KB
ViVeTool /enable  /id:58989092     :: re-enable (restore default)
```

### ⚠️ MSYS/Git Bash Path Conversion Bug

When running ViVeTool from MSYS bash, arguments like `/query` are converted to POSIX paths (`c:/program files/git/query`). **Always run through `cmd.exe`:**

```bash
# WRONG — MSYS converts /query to a path
/tmp/vivetool/ViVeTool.exe /query

# CORRECT — runs in cmd context where /query stays as argument
cmd.exe /c 'C:\path\to\ViVeTool.exe /query'
```

## ⚠️ CRITICAL: Hermes Terminal Cannot Elevate (UAC)

**Hermes terminal runs in a background session — it CANNOT display UAC dialogs.** Any command that requires admin elevation (`reg add HKLM\...`, `schtasks /create`, `Start-Process -Verb RunAs`) will **silently fail** with "Access denied" or appear to succeed but produce no effect. There is NO way for the agent to trigger a visible UAC prompt from within the Hermes terminal — not even via `cmd.exe /c powershell Start-Process`.

**Correct workflow — ALWAYS use this pattern:**

1. Write a `.bat` script with auto-elevation (`net session` check + `Start-Process -Verb RunAs`)
2. Place it on the **user's desktop** so they can find it easily
3. Instruct user: right-click → "Run as administrator" → confirm UAC
4. After user confirms, verify keys with `reg query`

```batch
@echo off
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
:: ... admin operations here ...
```

**NEVER attempt:** `cmd.exe /c "powershell -Command \"Start-Process ...\""` from Hermes terminal — the UAC window opens in a session the user cannot see. The agent should write the bat file and tell the user to run it manually.

## ⚠️ MSYS Path Conversion with `reg` Commands

When running `reg add` or `reg query` from MSYS/Git Bash (Hermes default shell):
- **Quoted Windows paths get mangled** — `"HKLM\SYSTEM\..."` may be converted to POSIX-style, causing silent failures
- **Solution:** Use unquoted registry paths: `reg add HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers /v TdrDelay ...`
- Or run through `cmd.exe`: `cmd.exe /c "reg add \"HKLM\...\" /v Key /t REG_DWORD /d 1 /f"`

## ⚠️ UAC Elevation Deadlock (when display is broken)

**Problem:** When GPU fixes cause black screen on elevation, you CANNOT undo them automatically — the UAC confirmation dialog triggers the same black screen that blocks it. This is a deadlock.

**Symptoms of deadlock:**
- `Start-Process -Verb RunAs` opens → black screen appears → UAC dialog never confirmed
- Scheduled tasks with `/ru SYSTEM` may fail due to session 0 isolation
- PowerShell elevation scripts hang indefinitely

**Workaround — manual batch file approach:**

1. Write a `.bat` script that auto-elevates and performs all operations
2. Place it on the **desktop** so user can find it easily
3. User right-clicks → "Run as administrator" during a stable period (not during black screen)
4. Script handles: registry delete + ViVeTool enable + verification

Template for rollback batch file (see `templates/rollback_gpu.bat`):

```batch
@echo off
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
:: ... admin operations here ...
```

**When to use:** Any time the fix itself causes display issues that block UAC dialogs. Create the batch file, instruct user to run it manually during stable uptime.

## Pitfalls

- **Registry changes require reboot** — no hot-reload for GraphicsDrivers keys
- **`reg delete` fails silently without admin** — always check return code
- **ViVeTool requires .NET Framework 4.8.1+** — pre-installed on Windows 25H2
- **KB status is persistent** — disabling via ViVeTool survives reboots until explicitly re-enabled
- **Multiple fixes may interact** — apply/remove all related changes together, not piecemeal
- **`nvidia-smi -pl` is volatile** — power limit resets to default (RTX 5090: 610 W) on every reboot. Verify `nvidia-smi --query-gpu=power.limit --format=csv` after each reboot; re-apply only with user permission.
- **OC profiles survive reboots** — MSI Afterburner auto-starts via task scheduler and reloads its profile; a "stability reboot" does NOT clear an OC. After any stability incident, inspect `MSIAfterburner.cfg` + `.oem2`.
- **Large Get-WinEvent slices** — don't run them inline in the terminal (output gets truncated, cp1251 mangles Cyrillic). Write a `.ps1` that `Set-Content -Encoding UTF8`s results to a file, run it, then read the file.
- **Pre-crash load context** — `infer_serve.log` is overwritten on restart; `requests.jsonl` (unix-ms timestamps in `%USERPROFILE%\Documents\bench-logs`) reconstructs the exact inference window. WSL `dmesg` only covers the post-reboot kernel — it cannot prove pre-crash WSL load.

## References

See `references/whea-kernel-power-diagnosis.md` for WHEA + Kernel-Power 41 diagnosis: the power-trip cluster interpretation and the PCIe AER + GPU TDR single-event variant with WER bucket cross-check and post-reboot recovery checklist.
