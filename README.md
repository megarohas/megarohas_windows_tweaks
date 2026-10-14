# megarohas_windows_tweaks

**English** | [Русский](README.ru.md)

Windows 11 tweaks for a PC on an MSI B450M MORTAR MAX (MS-7B89) running Windows 11
Insider **Dev channel**. Tailored to this specific configuration, but the hardware
is common (Realtek RTL8852BE Wi-Fi/BT + Realtek RTL8111H GbE), so it may come in
handy for you too.

## Background

With every flight, the Insider Dev channel rebuilds the driver stack and may roll
OEM drivers back to Microsoft's inbox stubs. That's how wired internet "died" on
August 23, 2026: the `rtcx21x64.sys` stub installed without a single error
(ProblemCode 0, Status OK, everything green in Device Manager) — but it never
brought up the PHY: no link, no port LEDs. Windows Update offered nothing, because
it considered the device healthy.

Everything else grew out of that: the right drivers, power tweaks for all three
network devices, and a watchdog that automatically fixes the system after every
flight.

## Contents

| Folder | What's inside |
|---|---|
| [`bluetooth-rtl8852be-maxperf/`](bluetooth-rtl8852be-maxperf/) | BT: disables power-down and USB selective suspend — cures audio stutter and gamepad dropouts |
| [`wifi-rtl8852be-maxperf/`](wifi-rtl8852be-maxperf/) | Wi-Fi: MSPower off, PCIe ASPM off, roaming at minimum — against ping spikes and hopping between access points |
| [`lan-rtl8111h-maxperf/`](lan-rtl8111h-maxperf/) | LAN: EEE / Green Ethernet / GigaLite / Interrupt Moderation — Off (GigaLite was silently capping gigabit at ~500 Mbps!) |
| [`boot-guard/`](boot-guard/) | Watchdog: a scheduled task that checks all three devices on every boot, reinstalls rolled-back drivers and re-applies the tweaks |
| [`stayawake/`](stayawake/) | «Не спать» ("Don't sleep"): a tiny window — while it's open, the PC won't go to sleep and the screen won't turn off |
| [`debloat-win11-insider/`](debloat-win11-insider/) | Clears out default dead weight: UWP junk, telemetry tasks, ads, unnecessary autostarts — without breaking Insider flights |
| [`system-perf/`](system-perf/) | System perf tweaks: Game Bar DVR off, HAGS on, Fast Startup off, Power Throttling off |
| [`bios-b450m-mortar-max/`](bios-b450m-mortar-max/) | BIOS guide: updating to v2O (fixes fTPM stutter), enabling Resizable BAR and PBO, a post-flash checklist |
| [`fancontrol-quiet-fans/`](fancontrol-quiet-fans/) | Quiet fan profile: FanControl curves with hysteresis (CPU driven by Tctl, case fans by the GPU), autostart, config snapshot |
| [`usb-maxpower/`](usb-maxpower/) | Maximum USB power: power-down disabled for all controllers/hubs, selective suspend and USB3 LPM — off |
| [`tweaks-reassert/`](tweaks-reassert/) | Wrapper watchdog: re-applies system-perf, vpn-dns-doctor and the debloat at every logon + a map of "who guards what" |
| [`vpn-dns-doctor/`](vpn-dns-doctor/) | Cleans up after VPN clients: orphaned routes, stuck DNS, NRPT — cures "nothing loads without the VPN" |
| [`display-fxaa-artifacts/`](display-fxaa-artifacts/) | The "over-compressed apps" mystery solved: NVIDIA's global FXAA blurs Electron/Flutter apps, while browsers mask the problem |

Tweak folders are self-contained: a README explaining the what and why + an
idempotent `apply-*-tweaks.ps1` script (run it as administrator). (The per-folder
READMEs are in Russian.)

To run everything at once, use **`apply-all.ps1`** in the repo root (as administrator):
it runs all the runnable packs in a sensible order, and any of them can be skipped —
`.\apply-all.ps1 -Skip debloat,lan`. Guides and install-style folders
(bios, stayawake, fancontrol, boot-guard, tweaks-reassert) are deliberately left
out — they have their own steps, see their READMEs.

## Drivers

Driver binaries (CABs from the Microsoft Update Catalog) are not committed to the
repo — the exact versions and where to get them are described in the READMEs of the
corresponding folders.

---
*The scripts are tied to specific hardware and local paths — before using them on
another machine, adjust the paths, device instance IDs and reference versions
(details are in the corresponding folders' READMEs). The repo grows as new tweaks
come along.*
