# VPN/DNS doctor: cleans leftovers from Windows VPN clients (Amnezia/sing-box,
# Outline, WireGuard, TAP) that cause dead or 10-40s-slow DNS when the VPN is
# off: orphaned default routes into dead tunnels, static DNS stuck on physical
# adapters, NRPT leftovers, stale cache.
# SAFE BY DESIGN: if any VPN tunnel is UP, it only reports and touches nothing.
# Idempotent; run as admin.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'
$log = Join-Path $PSScriptRoot 'doctor-log.txt'
if ((Test-Path $log) -and ((Get-Item $log).Length -gt 262144)) { Remove-Item $log -Force }
function L($m) { $s = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"; $s; Add-Content -Path $log -Value $s -Encoding UTF8 }
L '--- vpn-dns-doctor start ---'

$tunnels = Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match 'singbox|outline|amnezia|wg|tun' -or
    $_.InterfaceDescription -match 'sing-tun|TAP-Windows|WireGuard|Wintun|Amnezia'
}
$active = @($tunnels | Where-Object Status -eq 'Up')

if ($active.Count -gt 0) {
    $active | ForEach-Object { L "tunnel UP: $($_.Name) ($($_.InterfaceDescription)) - VPN active, leaving everything alone" }
} else {
    L 'no VPN tunnel is up - cleaning leftovers'

    # 1) orphaned default/split routes pointing into down tunnels
    foreach ($t in $tunnels) {
        Get-NetRoute -InterfaceIndex $t.ifIndex -ErrorAction SilentlyContinue |
          Where-Object { $_.DestinationPrefix -in '0.0.0.0/0','0.0.0.0/1','128.0.0.0/1','::/0' } |
          ForEach-Object {
              L "removing orphan route $($_.DestinationPrefix) via $($t.Name)"
              $_ | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
          }
    }

    # 2) physical adapters: DNS back to DHCP (no-op if already DHCP)
    Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { -not $_.Virtual -and $_.Status -eq 'Up' } |
      ForEach-Object {
          $dns = (Get-DnsClientServerAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
          L "reset DNS to DHCP on $($_.Name) (was: $(if ($dns) { $dns -join ', ' } else { 'DHCP' }))"
          Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
      }

    # 3) NRPT leftovers (home PC: no corp DNS policies expected)
    $nrpt = Get-DnsClientNrptRule -ErrorAction SilentlyContinue
    if ($nrpt) {
        $nrpt | ForEach-Object { L "removing NRPT rule: $($_.Namespace -join ',')"; Remove-DnsClientNrptRule -Name $_.Name -Force -ErrorAction SilentlyContinue }
    } else { L 'NRPT: clean' }

    # 4) flush resolver cache
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    L 'DNS cache flushed'
}

foreach ($h in 'ya.ru','github.com') {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try { $ip = (Resolve-DnsName $h -Type A -ErrorAction Stop | Select-Object -First 1).IPAddress } catch { $ip = 'FAIL' }
    $sw.Stop()
    L ("resolve {0}: {1} ({2} ms)" -f $h, $ip, $sw.ElapsedMilliseconds)
}
L '--- vpn-dns-doctor done ---'
