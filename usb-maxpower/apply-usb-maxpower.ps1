# Max USB power: forbid Windows from powering down ANY USB controller, hub or
# device (Device Manager "allow the computer to turn off..." unchecked for all),
# plus USB selective suspend and USB3 Link Power Management off in the active
# power scheme. Software cannot raise the physical current limit (500 mA USB2 /
# 900 mA USB3) - this kills power-saving, not physics. Idempotent; run as admin.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'
$log = Join-Path $PSScriptRoot 'apply-log.txt'
Start-Transcript -Path $log -Force

'=== [1/3] MSPower_DeviceEnable -> False for all USB controllers/hubs/devices ==='
$usbIds = (Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
           Where-Object { $_.Class -in 'USB','USBDevice' }).InstanceId
"USB-class devices present: $($usbIds.Count)"
$changed = 0; $already = 0
Get-CimInstance -Namespace root/wmi -ClassName MSPower_DeviceEnable -ErrorAction SilentlyContinue |
  ForEach-Object {
    $devId = $_.InstanceName -replace '_\d+$', ''
    if ($devId -in $usbIds) {
        if ($_.Enable) {
            $_ | Set-CimInstance -Property @{Enable=$false}
            "off: $devId"; $changed++
        } else { $already++ }
    }
  }
"changed: $changed, already off: $already"

'=== [2/3] Power scheme: USB selective suspend + USB3 Link PM -> off (AC/DC) ==='
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 0
powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 0
powercfg /setactive SCHEME_CURRENT
'USB selective suspend + USB3 LPM -> off'

'=== [3/3] VERIFY: any USB MSPower still enabled? ==='
$still = Get-CimInstance -Namespace root/wmi -ClassName MSPower_DeviceEnable -ErrorAction SilentlyContinue |
         Where-Object { $_.Enable -and (($_.InstanceName -replace '_\d+$', '') -in $usbIds) }
if ($still) { $still | ForEach-Object { "STILL ON: $($_.InstanceName)" } } else { 'all USB power-down: forbidden' }
'=== USB MAXPOWER DONE ==='
Stop-Transcript
