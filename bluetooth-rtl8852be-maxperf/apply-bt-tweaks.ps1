# Realtek RTL8852BE Bluetooth (USB VID_13D3&PID_3570) - max-performance power tweaks.
# Kills selective suspend / power-down that causes audio stutter and gamepad drops.
# Idempotent; run as admin. See README.md for the why.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'
$btPattern = 'USB\VID_13D3&PID_3570\*'   # AzureWave RTL8852BE, BT half

'=== [1/4] MSPower: forbid powering the radio down ==='
$bt = Get-CimInstance -Namespace root/wmi -ClassName MSPower_DeviceEnable |
      Where-Object InstanceName -like '*VID_13D3&PID_3570*'
if ($bt) { $bt | Set-CimInstance -Property @{Enable=$false}; 'MSPower BT -> False' }
else { 'WARN: BT MSPower instance not found - is the device present?' }

'=== [2/4] USB selective suspend off for the BT device itself ==='
$dev = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
       Where-Object InstanceId -like $btPattern | Select-Object -First 1
if ($dev) {
    $key = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters"
    New-ItemProperty -Path $key -Name SelectiveSuspendEnabled -PropertyType DWord -Value 0 -Force | Out-Null
    "SelectiveSuspendEnabled -> 0 ($($dev.InstanceId))"
} else { 'WARN: BT USB device not found' }

'=== [3/4] Power scheme: USB selective suspend off (AC+DC) ==='
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive SCHEME_CURRENT
'USB selective suspend -> off (AC/DC)'

'=== [4/4] Restart device to pick params up without a reboot ==='
if ($dev) { pnputil /restart-device $dev.InstanceId; "restart exit: $LASTEXITCODE" }

'=== VERIFY ==='
Get-CimInstance -Namespace root/wmi -ClassName MSPower_DeviceEnable |
  Where-Object InstanceName -like '*VID_13D3*' | Select-Object InstanceName, Enable | Format-List
if ($dev) {
    Get-PnpDeviceProperty -InstanceId $dev.InstanceId `
      -KeyName DEVPKEY_Device_DriverVersion, DEVPKEY_Device_DriverProvider |
      Select-Object KeyName, Data | Format-List
    Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters" |
      Select-Object SelectiveSuspendEnabled | Format-List
}
