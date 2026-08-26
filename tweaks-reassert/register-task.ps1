# Register the Tweaks-Reassert task: at logon +45s, highest rights, hidden
# window, ignore-new instances, 20 min execution limit. Idempotent; run as
# admin. Adjust the wrapper path to your layout.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$wrapper = 'S:\Claude\toolbox\reassert-at-logon.ps1'
if (-not (Test-Path $wrapper)) { throw "wrapper not found: $wrapper" }
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
           -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$wrapper`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$trigger.Delay = 'PT45S'
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest -LogonType Interactive
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
             -ExecutionTimeLimit (New-TimeSpan -Minutes 20) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'Tweaks-Reassert' -Action $action -Trigger $trigger `
  -Principal $principal -Settings $settings -Force
'Task registered. Test run:'
Start-ScheduledTask -TaskName 'Tweaks-Reassert'
