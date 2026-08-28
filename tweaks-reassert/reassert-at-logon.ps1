# Reassert idempotent tweak packs at logon. Run by scheduled task
# "Tweaks-Reassert" (this user, highest rights, hidden, +45s delay).
# Both child scripts are idempotent and fast when nothing drifted.
$ErrorActionPreference = 'Continue'
$log = 'S:\Claude\toolbox\reassert-at-logon.log'
if ((Test-Path $log) -and ((Get-Item $log).Length -gt 262144)) { Remove-Item $log -Force }
function L($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Add-Content -Path $log -Encoding UTF8 }
L '--- reassert start ---'
# packs run in child processes: a try/catch in this wrapper would otherwise turn
# statement-terminating errors inside a pack into a silent mid-run abort
foreach ($pack in 'S:\Claude\toolbox\system-perf\apply-system-perf.ps1',
                  'S:\Claude\toolbox\vpn-dns-doctor\vpn-dns-doctor.ps1',
                  'S:\Claude\toolbox\debloat\apply-debloat.ps1') {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $pack *> $null
    L "$(Split-Path (Split-Path $pack -Parent) -Leaf): exit $LASTEXITCODE"
}
L '--- reassert done ---'
