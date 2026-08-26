# Realtek RTL8111H GbE (PCIe DEV_8168) - max-performance tweaks.
# GigaLite silently caps gigabit to ~500 Mbit; EEE/Green Ethernet add latency.
# Locale-independent (RegistryValue, not DisplayValue). Idempotent; run as admin.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'
$lanDesc = 'Realtek PCIe GbE*'

'=== [1/3] MSPower: forbid powering the NIC down ==='
$lan = Get-CimInstance -Namespace root/wmi -ClassName MSPower_DeviceEnable |
       Where-Object InstanceName -like '*DEV_8168*'
if ($lan) { $lan | Set-CimInstance -Property @{Enable=$false}; 'MSPower LAN -> False' }
else { 'WARN: LAN MSPower instance not found - is the device present?' }

'=== [2/3] Advanced properties: power saving off, buffers to hw max ==='
$want = [ordered]@{ '*EEE'='0'; 'EnableGreenEthernet'='0'; 'GigaLite'='0'; 'PowerSavingMode'='0'; '*InterruptModeration'='0' }
$changed = 0
foreach ($kw in $want.Keys) {
    $p = Get-NetAdapterAdvancedProperty -InterfaceDescription $lanDesc -RegistryKeyword $kw -ErrorAction SilentlyContinue
    if (-not $p) { "skip: $kw not exposed by this driver"; continue }
    if (@($p.RegistryValue)[0] -ne $want[$kw]) {
        Set-NetAdapterAdvancedProperty -InterfaceDescription $lanDesc -RegistryKeyword $kw -RegistryValue $want[$kw] -NoRestart
        "$kw -> $($want[$kw])"; $changed++
    } else { "$kw already $($want[$kw])" }
}
foreach ($kw in '*ReceiveBuffers','*TransmitBuffers') {
    $p = Get-NetAdapterAdvancedProperty -InterfaceDescription $lanDesc -RegistryKeyword $kw -ErrorAction SilentlyContinue
    if ($p -and $p.NumericParameterMaxValue -and ([int](@($p.RegistryValue)[0]) -lt [int]$p.NumericParameterMaxValue)) {
        Set-NetAdapterAdvancedProperty -InterfaceDescription $lanDesc -RegistryKeyword $kw -RegistryValue "$($p.NumericParameterMaxValue)" -NoRestart
        "$kw -> $($p.NumericParameterMaxValue)"; $changed++
    } elseif ($p) { "$kw already at hw max ($(@($p.RegistryValue)[0]))" }
}

'=== [3/3] Restart adapter once if anything changed ==='
if ($changed -gt 0) {
    Restart-NetAdapter -InterfaceDescription $lanDesc -ErrorAction SilentlyContinue
    "adapter restarted to apply $changed change(s) (link blips ~2s)"
} else { 'nothing changed - no restart needed' }

'=== VERIFY ==='
Get-NetAdapter -InterfaceDescription $lanDesc |
  Select-Object InterfaceDescription, Status, LinkSpeed, DriverVersion, DriverProvider | Format-List
Get-NetAdapterAdvancedProperty -InterfaceDescription $lanDesc |
  Where-Object { $_.RegistryKeyword -in '*EEE','EnableGreenEthernet','GigaLite','PowerSavingMode','*InterruptModeration','*ReceiveBuffers','*TransmitBuffers' } |
  Select-Object RegistryKeyword, RegistryValue, DisplayValue | Format-Table -AutoSize
