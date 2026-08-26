# Reassert idempotent tweak packs at logon. Run by scheduled task
# "Tweaks-Reassert" (this user, highest rights, hidden, +45s delay).
# Both child scripts are idempotent and fast when nothing drifted.
$ErrorActionPreference = 'Continue'
$log = 'S:\Claude\toolbox\reassert-at-logon.log'
if ((Test-Path $log) -and ((Get-Item $log).Length -gt 262144)) { Remove-Item $log -Force }
function L($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Add-Content -Path $log -Encoding UTF8 }
L '--- reassert start ---'
try { & 'S:\Claude\toolbox\system-perf\apply-system-perf.ps1' | Out-Null; L 'system-perf: done' }
catch { L "system-perf FAILED: $($_.Exception.Message)" }
try { & 'S:\Claude\toolbox\debloat\apply-debloat.ps1' | Out-Null; L 'debloat: done' }
catch { L "debloat FAILED: $($_.Exception.Message)" }
L '--- reassert done ---'
