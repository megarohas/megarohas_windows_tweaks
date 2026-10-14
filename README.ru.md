# megarohas_windows_tweaks

[English](README.md) | **Русский**

Твики Windows 11 для ПК на MSI B450M MORTAR MAX (MS-7B89) под Windows 11
Insider **Dev channel**. Заточено под конкретную конфигурацию, но железо
распространённое (Realtek RTL8852BE Wi-Fi/BT + Realtek RTL8111H GbE), так что
может пригодиться и вам.

## Предыстория

Dev-канал Insider при каждом флайте пересобирает стек драйверов и умеет
откатывать OEM-драйверы на inbox-заглушки Microsoft. 23.08.2026 так «умер»
проводной интернет: заглушка `rtcx21x64.sys` встала без единой ошибки
(ProblemCode 0, Status OK, в диспетчере всё зелёное) — но не поднимала PHY:
ни линка, ни лампочек на порту. Windows Update ничего не предлагал, потому что
считал устройство исправным.

Из этого выросло всё остальное: правильные драйверы, твики питания для всех
трёх сетевых устройств и сторож, который после каждого флайта чинит систему
автоматически.

## Состав

| Папка | Что внутри |
|---|---|
| [`bluetooth-rtl8852be-maxperf/`](bluetooth-rtl8852be-maxperf/) | BT: запрет power-down и USB selective suspend — лечит заикания звука и отвалы геймпада |
| [`wifi-rtl8852be-maxperf/`](wifi-rtl8852be-maxperf/) | Wi-Fi: MSPower off, PCIe ASPM off, роуминг на минимум — против просадок пинга и скачков между точками |
| [`lan-rtl8111h-maxperf/`](lan-rtl8111h-maxperf/) | LAN: EEE / Green Ethernet / GigaLite / Interrupt Moderation — Выкл (GigaLite тихо резал гигабит до ~500 Мбит!) |
| [`boot-guard/`](boot-guard/) | Сторож: задача планировщика, которая на каждой загрузке проверяет все три устройства, переставляет откатившиеся драйверы и заново прожимает твики |
| [`stayawake/`](stayawake/) | «Не спать»: мини-окно — пока открыто, ПК не уходит в сон и экран не гаснет |
| [`debloat-win11-insider/`](debloat-win11-insider/) | Чистка дефолтного балласта: UWP-мусор, телеметрия-задачи, реклама, лишние автостарты — без вреда для Insider-флайтов |
| [`system-perf/`](system-perf/) | Системные перф-твики: Game Bar DVR off, HAGS on, Fast Startup off, Power Throttling off |
| [`bios-b450m-mortar-max/`](bios-b450m-mortar-max/) | BIOS-гайд: обновление до v2O (фикс fTPM-статтера), включение Resizable BAR и PBO, чек-лист после прошивки |
| [`fancontrol-quiet-fans/`](fancontrol-quiet-fans/) | Тихий профиль вентиляторов: кривые FanControl с гистерезисом (CPU от Tctl, корпусные от GPU), автозапуск, снапшот конфига |
| [`usb-maxpower/`](usb-maxpower/) | Максимум питания USB: запрет power-down для всех контроллеров/хабов, selective suspend и USB3 LPM — off |
| [`tweaks-reassert/`](tweaks-reassert/) | Сторож-обёртка: перепрожимает system-perf, vpn-dns-doctor и деблоат при каждом входе + карта «кто что сторожит» |
| [`vpn-dns-doctor/`](vpn-dns-doctor/) | Чистка хвостов VPN-клиентов: осиротевшие маршруты, залипший DNS, NRPT — лечит «без VPN ничего не грузится» |
| [`display-fxaa-artifacts/`](display-fxaa-artifacts/) | Разгадка «пережатых» приложений: глобальный FXAA NVIDIA мылит Electron/Flutter, а браузеры маскируют проблему |

Папки твиков самодостаточны: README с объяснением «что и почему» +
идемпотентный скрипт `apply-*-tweaks.ps1` (запускать от администратора).

Всё разом — **`apply-all.ps1`** в корне (от администратора): прогоняет все
запускаемые паки в разумном порядке, любой можно исключить —
`.\apply-all.ps1 -Skip debloat,lan`. Гайды и установочные папки
(bios, stayawake, fancontrol, boot-guard, tweaks-reassert) он сознательно
не трогает — там свои шаги, см. их README.

## Драйверы

Бинарники драйверов (CAB'ы из Microsoft Update Catalog) в репозиторий не
коммитятся — точные версии и где их взять описаны в README соответствующих
папок.

---
*Скрипты привязаны к конкретному железу и локальным путям — перед использованием
на другой машине поправьте пути, instance ID устройств и эталонные версии
(детали — в README соответствующих папок). Репозиторий пополняется по мере
появления новых твиков.*
