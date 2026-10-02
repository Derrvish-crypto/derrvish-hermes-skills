# WHEA-Logger + Kernel-Power 41 Diagnosis (2026-07-08)

## Observed event cluster on i9-13900K + RTX 5090 + Seasonic TX-1600 ATX 3.1:

| Time | Source | ID | Severity | Detail |
|------|--------|----|----------|--------|
| 08.07 16:42 | Kernel-Power | **41** | Critical | Unexpected shutdown — system did not shut down cleanly |
| 08.07 16:42 | WHEA-Logger | **17** | Error | Corrected hardware error (processor) |
| 08.07 16:42 | Disk | 26, 55 | Warning | I/O timeout — disk did not respond in time |

## Interpretation

The cluster (WHEA + Kernel-Power 41 + Disk timeout at the same second) indicates a **power-related event**:
- PSU voltage rail dip or protection trip under GPU load
- Motherboard VRM thermal shutdown
- Forced power button press by user

On this specific hardware (Seasonic TX-1600 ATX 3.1, RTX 5090), the PSU is rated well above requirements. Most likely cause: transient PCIe 5.0 power spike or CPU Vcore instability under combined GPU+CPU load.

## Diagnostic steps to recommend:
1. `Get-WinEvent -FilterHashtable @{LogName='System'; ID=17} | Select-Object -First 5 | Format-List` — get WHEA error type (processor vs memory)
2. `nvidia-smi --query-gpu=temperature.gpu,power.draw,power.limit,utilization.gpu --format=csv` — current GPU state
3. Check BIOS for CPU Vcore settings and PCIe power delivery mode
4. Review SMART data on Z: drive (`Get-PhysicalDisk | Get-StorageReliabilityCounter`)

## System baseline (known stable):
- RTX 5090: WHEA errors = 0 historically, PCIe Gen5 x16 confirmed
- Seasonic TX-1600 ATX 3.1: rated well above RTX 5090 requirements
- i9-13900K + 192GB RAM: stable under normal load

## Variant 2: PCIe AER (ErrorSource=4) + GPU TDR — single-event pattern

Cluster: ONE WHEA-17 (AER) 20–30 s before WER `LKD_0x141_Tdr:*` (Application log) + `LKD_0x1B8_*_Blackscreen_Blackbox` + KP41 with `BugcheckCode=0` (forced power button). No BSOD, no disk timeouts.

Decoding:
- WHEA `ErrorSource=4` → Advanced Error Reporting = PCIe link error; `UncorrectableErrorStatus 0x4000` = Bad TLP. The VendorID/DeviceID in the event = the reporting **root port** (chipset), not the GPU — map the endpoint with `nvidia-smi --query-gpu=pci.bus_id --format=csv`.
- WER bucket suffix `_UserOC` → a user OC profile (MSI Afterburner, auto-starts at boot) was active at fault time — primary suspect over hardware.
- Single WHEA event over 30 days + single KP41 over 7 days = margin problem (OC/power), not failing hardware.

Interpretation: full inference load exceeds the PCIe link margin (often under OC) → GPU TDR → display pipeline death (blackscreen blackboxes) → TDR recovery fails → full hang, fans uncontrolled → user hard reset.

Recovery checklist after reboot:
1. `nvidia-smi --query-gpu=power.limit --format=csv` — `-pl` is volatile; re-apply only with user permission.
2. Check the Afterburner OC profile (`C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.cfg` + `.oem2`) — it reloaded itself at boot.
3. Reconstruct the load window: the local LLM server `requests.jsonl` (unix-ms timestamps); `serve.log` is already overwritten.
4. WSL `dmesg` covers only the post-reboot kernel — not usable for pre-crash WSL state.
