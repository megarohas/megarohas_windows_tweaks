# Realtek RTL8852BE WiFi 6 (PCIe DEV_B852) - max-performance power tweaks.
# Kills power saving (ping spikes) and aggressive roaming (random AP hopping).
# Idempotent; run as admin. See README.md for the why.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'
$wlDesc = 'Realtek 8852BE*'

'=== [1/3] MSPower: forbid powering the adapter down ==='
$wl = Get-CimInstance -Namespace root/wmi -ClassName MSPower_DeviceEnable |
      Where-Object InstanceName -like '*DEV_B852*'
if ($wl) { $wl | Set-CimInstance -Property @{Enable=$false}; 'MSPower WLAN -> False' }
else { 'WARN: WLAN MSPower instance not found - is the device present?' }

'=== [2/3] Power scheme: PCIe ASPM off (AC+DC) ==='
powercfg /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
powercfg /setdcvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
powercfg /setactive SCHEME_CURRENT
'PCIe ASPM -> off (AC/DC)'

'=== [3/3] Roaming -> lowest (key renamed to RegRoamLevel in 6001.15.165.3) ==='
$roam = Get-NetAdapterAdvancedProperty -InterfaceDescription $wlDesc `
        -RegistryKeyword RegRoamLevel -ErrorAction SilentlyContinue
if ($roam) {
    if ($roam.DisplayValue -match '^1') { "Roaming already lowest: $($roam.DisplayValue)" }
    else {
        $lowest = @($roam.ValidDisplayValues) | Where-Object { $_ -match '^1' } | Select-Object -First 1
        if ($lowest) {
            Set-NetAdapterAdvancedProperty -InterfaceDescription $wlDesc `
              -RegistryKeyword RegRoamLevel -DisplayValue $lowest
            "Roaming -> $lowest (adapter re-binds, WiFi blips for a few seconds)"
        } else { "WARN: no '1 ...' option among: $($roam.ValidDisplayValues -join ', ')" }
    }
} else { 'WARN: RegRoamLevel not found - driver older than 6001.15.165.3? (key was RegROAMSensitiveLevel)' }

'=== VERIFY ==='
Get-CimInstance -Namespace root/wmi -ClassName MSPower_DeviceEnable |
  Where-Object InstanceName -like '*DEV_B852*' | Select-Object InstanceName, Enable | Format-List
Get-NetAdapter -InterfaceDescription $wlDesc |
  Select-Object InterfaceDescription, Status, DriverVersion, DriverProvider | Format-List
Get-NetAdapterAdvancedProperty -InterfaceDescription $wlDesc -RegistryKeyword RegRoamLevel -ErrorAction SilentlyContinue |
  Select-Object DisplayName, DisplayValue | Format-List
