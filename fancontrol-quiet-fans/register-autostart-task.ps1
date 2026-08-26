# Register the FanControl autostart task: at logon, highest privileges,
# minimized (-m), and no execution time limit (default 3-day limit would
# kill the process). Idempotent; run as admin.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$fc = 'C:\Program Files (x86)\FanControl\FanControl.exe'
if (-not (Test-Path $fc)) { throw "FanControl.exe not found at $fc" }
$action    = New-ScheduledTaskAction -Execute $fc -Argument '-m'
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest -LogonType Interactive
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName 'FanControl' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
'Task registered. Test run:'
Start-ScheduledTask -TaskName 'FanControl'
Start-Sleep -Seconds 5
if (Get-Process FanControl -ErrorAction SilentlyContinue) { 'FanControl is running.' } else { 'WARN: FanControl did not start' }
