# Stops DisplayHotkeys and removes it from autostart.
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'DisplayHotkeys' -ErrorAction SilentlyContinue
Get-Process DisplayHotkeys -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host 'DisplayHotkeys removed'
