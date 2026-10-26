# Builds (if needed), adds DisplayHotkeys to the current user's autostart and starts it.
$ErrorActionPreference = 'Stop'
$exe = Join-Path $PSScriptRoot 'DisplayHotkeys.exe'
if (-not (Test-Path $exe)) { & (Join-Path $PSScriptRoot 'build.ps1') }
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'DisplayHotkeys' -Value "`"$exe`""
Get-Process DisplayHotkeys -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process $exe
Write-Host 'DisplayHotkeys installed: Win+M+1 = PC screen only, Win+M+2 = second screen only'
