# Register boot-time scheduled task (SYSTEM) for wireless boot-guard + test run
$ErrorActionPreference = 'Stop'
Start-Transcript -Path 'S:\Claude\toolbox\wireless-drivers\task-register-log.txt' -Force
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
           -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "S:\Claude\toolbox\wireless-drivers\boot-guard.ps1"'
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = 'PT25S'
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
             -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'Wireless-8852BE-MaxPerf' -Action $action -Trigger $trigger `
  -Principal $principal -Settings $settings -Force
'Task registered. Test run:'
Start-ScheduledTask -TaskName 'Wireless-8852BE-MaxPerf'
$deadline = (Get-Date).AddSeconds(60)
do { Start-Sleep -Seconds 2; $t = Get-ScheduledTask -TaskName 'Wireless-8852BE-MaxPerf' }
while ($t.State -eq 'Running' -and (Get-Date) -lt $deadline)
Get-ScheduledTaskInfo -TaskName 'Wireless-8852BE-MaxPerf' |
  Select-Object LastRunTime, LastTaskResult | Format-List
Stop-Transcript
