# Run every runnable tweak pack in this repo, in a sane order.
#
# Usage (as admin):   .\apply-all.ps1                     - run everything
#                     .\apply-all.ps1 -Skip debloat,lan   - run all but these
#
# Each pack is idempotent and logs into its own folder (apply-log.txt).
# Guides and per-machine installers (bios-b450m-mortar-max, stayawake,
# fancontrol-quiet-fans, boot-guard, tweaks-reassert) are deliberately NOT
# included here - see their READMEs.
#Requires -RunAsAdministrator
param([string[]]$Skip = @())
$ErrorActionPreference = 'Continue'

$packs = [ordered]@{
    'system-perf' = 'system-perf\apply-system-perf.ps1'
    'usb'         = 'usb-maxpower\apply-usb-maxpower.ps1'
    'bluetooth'   = 'bluetooth-rtl8852be-maxperf\apply-bt-tweaks.ps1'   # restarts the BT device: audio blips for a couple of seconds
    'wifi'        = 'wifi-rtl8852be-maxperf\apply-wifi-tweaks.ps1'
    'lan'         = 'lan-rtl8111h-maxperf\apply-lan-tweaks.ps1'
    'debloat'     = 'debloat-win11-insider\apply-debloat.ps1'           # slowest, so it goes last
}

$results = [ordered]@{}
foreach ($name in $packs.Keys) {
    if ($name -in $Skip) { $results[$name] = 'skipped'; continue }
    $path = Join-Path $PSScriptRoot $packs[$name]
    if (-not (Test-Path $path)) { $results[$name] = 'not found'; continue }
    Write-Host ""
    Write-Host "===== [$name] $($packs[$name]) =====" -ForegroundColor Cyan
    # run each pack in a child process: a try/catch here would otherwise turn
    # statement-terminating errors inside a pack into a mid-run abort of it
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path
    if ($LASTEXITCODE -eq 0) { $results[$name] = 'done' } else { $results[$name] = "exit $LASTEXITCODE" }
}

Write-Host ""
Write-Host "===== SUMMARY =====" -ForegroundColor Cyan
foreach ($k in $results.Keys) { Write-Host ("  {0,-12} {1}" -f $k, $results[$k]) }
Write-Host "Reboot recommended: HAGS and removed apps finish after a restart."
