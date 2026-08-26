# Debloat pack for Windows 11 Insider Dev builds.
# Removes commonly unused default apps, telemetry-ish scheduled tasks, vendor
# RGB/monitoring services, ads/suggestions, and heavy autostarts.
# Idempotent; run as admin. Re-run after a flight if apps come back (see README).
#
# The lists below reflect one owner's choices - edit them to taste. This pack
# deliberately KEEPS:
#  - Xbox / Game Pass stack, printing (Spooler), RDP host, Quick Assist
#  - Insider telemetry (DiagTrack / Compatibility Appraiser) - Dev flights need it
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'
$log = Join-Path $PSScriptRoot 'apply-log.txt'
Start-Transcript -Path $log -Force

'=== [1/7] Remove default UWP apps ==='
$apps = @(
  # unused Microsoft defaults
  'Microsoft.MicrosoftSolitaireCollection','Microsoft.BingNews','Microsoft.BingWeather',
  'Microsoft.BingSearch','Microsoft.GetHelp','Microsoft.MicrosoftOfficeHub','Microsoft.People',
  'Microsoft.Todos','Microsoft.WindowsAlarms','Microsoft.WindowsMaps','Microsoft.WindowsSoundRecorder',
  'Microsoft.ZuneVideo','Clipchamp.Clipchamp','Microsoft.PowerAutomateDesktop','Microsoft.Windows.DevHome',
  'Microsoft.Edge.GameAssist',
  # Widgets
  'MicrosoftWindows.Client.WebExperience','Microsoft.WidgetsPlatformRuntime',
  # Phone Link
  'Microsoft.YourPhone','MicrosoftWindows.CrossDevice',
  # new Outlook + legacy Mail/Calendar
  'Microsoft.OutlookForWindows','microsoft.windowscommunicationsapps',
  # both Teams flavors
  'MicrosoftTeams','MSTeams',
  # OneDrive store shim (the win32 client is uninstalled in [2/7])
  'Microsoft.OneDriveSync'
)
# NOTE: on fresh Insider builds this can intermittently fail with "access denied"
# even elevated; deprovisioning is then skipped and a flight may bring apps back -
# just re-run. Contained in try/catch: an enclosing try/catch in a caller would
# otherwise turn this statement-terminating COMException into a full script abort.
try { $prov = Get-AppxProvisionedPackage -Online -ErrorAction Stop }
catch { $prov = @(); "provisioned enum unavailable: $($_.Exception.Message)" }
foreach ($a in $apps) {
    $p = Get-AppxPackage -AllUsers -Name $a -ErrorAction SilentlyContinue
    if ($p) {
        try { $p | Remove-AppxPackage -AllUsers -ErrorAction Stop; "removed: $a" }
        catch { "FAILED : $a -> $($_.Exception.Message)" }
    } else { "absent : $a" }
    $pv = $prov | Where-Object { $_.DisplayName -eq $a }
    if ($pv) {
        try { $pv | Remove-AppxProvisionedPackage -Online -ErrorAction Stop | Out-Null; "deprov : $a" }
        catch { "deprov FAILED: $a -> $($_.Exception.Message)" }
    }
}

'=== [2/7] Uninstall OneDrive (local OneDrive folder and its files are NOT deleted) ==='
$od = Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                       'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                       'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName -eq 'Microsoft OneDrive' } | Select-Object -First 1
if ($od) {
    $u = $od.QuietUninstallString; if (-not $u) { $u = $od.UninstallString }
    "uninstalling OneDrive :: $u"
    cmd.exe /c "$u"; "exit: $LASTEXITCODE"
} else { 'OneDrive: not installed' }

'=== [3/7] Uninstall leftover junk (Freemake, Win11 Installation Assistant) ==='
# the Cyrillic pattern matches the RU DisplayName of the Installation Assistant
$junk = Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                         'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                         'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'Freemake*' -or $_.DisplayName -like '*омощник по установке Windows 11*' -or $_.DisplayName -like 'Windows 11 Installation Assistant*' }
foreach ($j in $junk) {
    $u = $j.QuietUninstallString
    if (-not $u) {
        $u = $j.UninstallString
        # NSIS uninstallers (Freemake) accept /S for silent
        if ($u -and $j.DisplayName -like 'Freemake*') { $u += ' /S' }
    }
    if ($u) { "uninstalling: $($j.DisplayName) :: $u"; cmd.exe /c "$u"; "exit: $LASTEXITCODE" }
}
if (-not $junk) { 'junk: nothing found' }

'=== [4/7] Disable unused services (vendor RGB/monitoring stack, Maps) ==='
foreach ($s in 'MSI_Center_Service','MSI_Case_Service','Mystic_Light_Service','LightKeeperService','MapsBroker') {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc) {
        "service $s : was $($svc.StartType)/$($svc.Status)"
        Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
        Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue
        "service $s -> Disabled"
    } else { "service $s : absent" }
}

'=== [5/7] Disable telemetry-ish scheduled tasks (Insider-critical Appraiser is NOT touched) ==='
$taskSpecs = @(
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Names = 'Consolidator','UsbCeip' },
    @{ Path = '\Microsoft\Windows\Feedback\Siuf\';                           Names = 'DmClient','DmClientOnScenarioDownload' },
    @{ Path = '\Microsoft\Windows\Windows Error Reporting\';                 Names = 'QueueReporting' },
    @{ Path = '\Microsoft\Windows\Maps\';                                    Names = 'MapsToastTask' }
)
foreach ($spec in $taskSpecs) { foreach ($n in $spec.Names) {
    try { Disable-ScheduledTask -TaskPath $spec.Path -TaskName $n -ErrorAction Stop | Out-Null; "task disabled: $($spec.Path)$n" }
    catch { "task skip: $($spec.Path)$n" }
} }
# wildcard ones: ad "soft landing", Firefox default-browser telemetry, OneDrive leftovers
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
    $_.State -ne 'Disabled' -and (
        $_.TaskPath -like '\SoftLanding\*' -or
        $_.TaskName -like 'Firefox Default Browser Agent*' -or
        ($_.TaskPath -eq '\' -and $_.TaskName -like 'OneDrive*')
    )
} | ForEach-Object {
    try { $_ | Disable-ScheduledTask -ErrorAction Stop | Out-Null; "task disabled: $($_.TaskPath)$($_.TaskName)" }
    catch { "task skip: $($_.TaskPath)$($_.TaskName)" }
}

'=== [6/7] Registry: no ads/suggestions, no Edge preload, no update seeding, no Widgets ==='
function Set-Reg($Path, $Name, $Value) {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
    "reg: $Path\$Name = $Value"
}
# ContentDeliveryManager: silent sponsored installs, tips, Start/Settings suggestions
$cdm = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach ($v in 'SilentInstalledAppsEnabled','SoftLandingEnabled','SubscribedContent-338388Enabled',
               'SubscribedContent-338389Enabled','SubscribedContent-353694Enabled','SubscribedContent-353696Enabled') {
    Set-Reg $cdm $v 0
}
# Edge: no startup boost, no background mode (kills the login-time preload for good)
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0
# Delivery Optimization: plain HTTP, do not seed updates to the internet
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
# Widgets off by policy too (belt and braces; the Dsh key may be TrustedInstaller-
# protected on newer builds - harmless to fail, the packages are removed anyway)
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0

'=== [7/7] Autostart cleanup (Edge preload, Epic, GOG, OneDrive leftover) ==='
$run = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
(Get-Item $run).Property | Where-Object {
    $_ -like 'MicrosoftEdgeAutoLaunch*' -or $_ -in 'EpicGamesLauncher','GogGalaxy','OneDrive'
} | ForEach-Object {
    Remove-ItemProperty -Path $run -Name $_ -ErrorAction SilentlyContinue
    "Run value removed: $_"
}

'=== VERIFY ==='
'apps still present:'
foreach ($a in $apps) { if (Get-AppxPackage -AllUsers -Name $a -ErrorAction SilentlyContinue) { "  still here: $a" } }
'services:'
Get-Service 'MSI_Center_Service','MSI_Case_Service','Mystic_Light_Service','LightKeeperService','MapsBroker' -ErrorAction SilentlyContinue |
  ForEach-Object { "  $($_.Name): $($_.StartType)/$($_.Status)" }
'Run key now:'
(Get-Item $run).Property | ForEach-Object { "  $_" }
'=== DEBLOAT DONE ==='
Stop-Transcript
