# System performance tweaks pack - selected set:
#  - Game Bar DVR capture off (Windows background capture; NVIDIA App / OBS
#    recording is a separate stack and is NOT touched, Xbox app / Game Pass keep working)
#  - Hardware-accelerated GPU scheduling (HAGS) on - needs a reboot
#  - Fast Startup off (so every power-on is a real boot and At-Startup tasks fire)
#  - Background power throttling off
# Power scheme deliberately NOT changed (AMD Ryzen Balanced kept, min CPU = 99%).
# Idempotent; run as admin.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'
$log = Join-Path $PSScriptRoot 'apply-log.txt'
Start-Transcript -Path $log -Force

function Set-Reg($Path, $Name, $Value) {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
    "reg: $Path\$Name = $Value"
}

'=== [1/4] Game Bar DVR capture off (Xbox app / Game Pass unaffected) ==='
Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' 'HistoricalCaptureEnabled' 0

'=== [2/4] Hardware-accelerated GPU scheduling on (takes effect after reboot) ==='
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2

'=== [3/4] Fast Startup off (every power-on is a real boot; At-Startup tasks fire) ==='
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0

'=== [4/4] Background power throttling off ==='
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1

'=== VERIFY ==='
"GameDVR_Enabled    = $((Get-ItemProperty 'HKCU:\System\GameConfigStore').GameDVR_Enabled)"
"AppCaptureEnabled  = $((Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR').AppCaptureEnabled)"
"HistoricalCapture  = $((Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR').HistoricalCaptureEnabled)"
"HwSchMode          = $((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers').HwSchMode)"
"HiberbootEnabled   = $((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power').HiberbootEnabled)"
"PowerThrottlingOff = $((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling').PowerThrottlingOff)"
'=== PERF TWEAKS DONE ==='
Stop-Transcript
