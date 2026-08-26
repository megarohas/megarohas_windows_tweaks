# Boot guard v2: Realtek 8852BE (WiFi+BT) + RTL8111H (LAN) - drivers & power tweaks.
# Runs as SYSTEM at startup (scheduled task "Wireless-8852BE-MaxPerf").
# Insider Dev flights roll drivers back to inbox stubs; this detects and fixes it.
$ErrorActionPreference = 'Continue'
$root = 'S:\Claude\toolbox'
$log  = "$root\wireless-drivers\boot-guard.log"
if ((Test-Path $log) -and ((Get-Item $log).Length -gt 262144)) { Remove-Item $log -Force }
function Log($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Add-Content -Path $log -Encoding UTF8 }
Log '--- boot-guard v2 start ---'

$btId  = 'USB\VID_13D3&PID_3570\00E04C000001'
$wlId  = 'PCI\VEN_10EC&DEV_B852&SUBSYS_54701A3B&REV_00\6&970B1E8&0&0020020B'
$lanId = 'PCI\VEN_10EC&DEV_8168&SUBSYS_7B891462&REV_15\6&11BFDFFB&0&0008020B'
$btReinstalled = $false; $lanReinstalled = $false

function Test-Drift($devId, $minVer) {
    $ver  = (Get-PnpDeviceProperty -InstanceId $devId -KeyName DEVPKEY_Device_DriverVersion  -ErrorAction SilentlyContinue).Data
    $prov = (Get-PnpDeviceProperty -InstanceId $devId -KeyName DEVPKEY_Device_DriverProvider -ErrorAction SilentlyContinue).Data
    $drift = $true
    try { if ($prov -like 'Realtek*' -and [version]$ver -ge [version]$minVer) { $drift = $false } } catch {}
    return @{ Drift = $drift; Ver = $ver; Prov = $prov }
}

# --- 1. Driver drift checks ---
$r = Test-Drift $btId '18.4038.2509.1901'
if ($r.Drift) {
    Log "BT driver drift (prov='$($r.Prov)' ver='$($r.Ver)') -> reinstalling"
    pnputil /add-driver "$root\wireless-drivers\bt\ext\rtkbtfilter.inf" /install | Out-Null
    Log "pnputil BT exit: $LASTEXITCODE"; $btReinstalled = $true
} else { Log "BT driver OK: $($r.Ver)" }

$r = Test-Drift $wlId '6001.15.165.3'
if ($r.Drift) {
    Log "WLAN driver drift (prov='$($r.Prov)' ver='$($r.Ver)') -> reinstalling"
    pnputil /add-driver "$root\wireless-drivers\wlan\ext\netrtwlane601.inf" /install | Out-Null
    Log "pnputil WLAN exit: $LASTEXITCODE"
} else { Log "WLAN driver OK: $($r.Ver)" }

$r = Test-Drift $lanId '10.79.50.1003'
if ($r.Drift) {
    Log "LAN driver drift (prov='$($r.Prov)' ver='$($r.Ver)') -> reinstalling"
    pnputil /add-driver "$root\lan-driver\ext\rt640x64.inf" /install | Out-Null
    Log "pnputil LAN exit: $LASTEXITCODE"; $lanReinstalled = $true
} else { Log "LAN driver OK: $($r.Ver)" }

if ($btReinstalled -or $lanReinstalled) { Start-Sleep -Seconds 8 }

# --- 2. MSPower: forbid turning devices off to save power (all three) ---
Get-CimInstance -Namespace root/wmi -ClassName MSPower_DeviceEnable |
  Where-Object { ($_.InstanceName -like '*VID_13D3&PID_3570*' -or
                  $_.InstanceName -like '*DEV_B852*' -or
                  $_.InstanceName -like '*DEV_8168*') -and $_.Enable } |
  ForEach-Object { $_ | Set-CimInstance -Property @{Enable=$false}; Log "MSPower -> False: $($_.InstanceName)" }

# --- 3. BT selective suspend off ---
$btKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$btId\Device Parameters"
if ((Get-ItemProperty $btKey -Name SelectiveSuspendEnabled -ErrorAction SilentlyContinue).SelectiveSuspendEnabled -ne 0) {
    New-ItemProperty -Path $btKey -Name SelectiveSuspendEnabled -PropertyType DWord -Value 0 -Force | Out-Null
    Log 'SelectiveSuspendEnabled -> 0'
}

# --- 4. Power scheme: USB suspend off, PCIe ASPM off ---
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
powercfg /setdcvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
powercfg /setactive SCHEME_CURRENT

# --- 5. WLAN roaming lowest (only when drifted; setting restarts binding) ---
$roam = Get-NetAdapterAdvancedProperty -InterfaceDescription 'Realtek 8852BE*' -RegistryKeyword RegRoamLevel -ErrorAction SilentlyContinue
if ($roam -and $roam.DisplayValue -notmatch '^1') {
    $lowest = @($roam.ValidDisplayValues) | Where-Object { $_ -match '^1' } | Select-Object -First 1
    if ($lowest) { Set-NetAdapterAdvancedProperty -InterfaceDescription 'Realtek 8852BE*' -RegistryKeyword RegRoamLevel -DisplayValue $lowest; Log "Roam -> $lowest" }
}

# --- 6. LAN advanced tweaks (RegistryValue is locale-independent) ---
$lanDesc = 'Realtek PCIe GbE*'
$want = [ordered]@{ '*EEE'='0'; 'EnableGreenEthernet'='0'; 'GigaLite'='0'; 'PowerSavingMode'='0'; '*InterruptModeration'='0' }
$lanChanged = 0
foreach ($kw in $want.Keys) {
    $p = Get-NetAdapterAdvancedProperty -InterfaceDescription $lanDesc -RegistryKeyword $kw -ErrorAction SilentlyContinue
    if ($p -and (@($p.RegistryValue)[0] -ne $want[$kw])) {
        Set-NetAdapterAdvancedProperty -InterfaceDescription $lanDesc -RegistryKeyword $kw -RegistryValue $want[$kw] -NoRestart
        Log "LAN $kw -> $($want[$kw])"; $lanChanged++
    }
}
foreach ($kw in '*ReceiveBuffers','*TransmitBuffers') {
    $p = Get-NetAdapterAdvancedProperty -InterfaceDescription $lanDesc -RegistryKeyword $kw -ErrorAction SilentlyContinue
    if ($p -and $p.NumericParameterMaxValue -and ([int](@($p.RegistryValue)[0]) -lt [int]$p.NumericParameterMaxValue)) {
        Set-NetAdapterAdvancedProperty -InterfaceDescription $lanDesc -RegistryKeyword $kw -RegistryValue "$($p.NumericParameterMaxValue)" -NoRestart
        Log "LAN $kw -> $($p.NumericParameterMaxValue)"; $lanChanged++
    }
}
if ($lanChanged -gt 0) {
    Restart-NetAdapter -InterfaceDescription $lanDesc -ErrorAction SilentlyContinue
    Log "LAN adapter restarted to apply $lanChanged change(s)"
}

if ($btReinstalled) {
    pnputil /restart-device $btId | Out-Null
    Log "BT device restarted: $LASTEXITCODE"
}
Log '--- boot-guard v2 done ---'
