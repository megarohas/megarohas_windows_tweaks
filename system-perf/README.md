# system-perf

Точечные системные твики производительности Windows 11 — один идемпотентный
`apply-system-perf.ps1` (запускать от администратора, лог пишется рядом).

| Твик | Что даёт |
|---|---|
| **Game Bar DVR → off** | Фоновая DVR-механика Windows не висит в играх. Xbox app / Game Pass работают; запись через NVIDIA App / OBS — отдельный стек, не затрагивается |
| **HAGS → on** (`HwSchMode=2`) | Аппаратное планирование GPU: ниже латентность подачи кадров на современных картах. Вступает после перезагрузки |
| **Fast Startup → off** | Каждое включение = честная загрузка: задачи планировщика At Startup срабатывают всегда (критично для [boot-guard](../boot-guard/)), меньше глюков со «стейлом» драйверов |
| **Power Throttling → off** | Windows перестаёт зажимать частоты фоновым процессам |

## Чего здесь сознательно нет

- **Смена схемы питания** — AMD Ryzen Balanced с минимальной частотой CPU 99 %
  уже почти не отличается от High Performance по производительности.
- **Отключение VBS / Memory Integrity** — сначала проверьте: возможно, уже
  выключено (`Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard`).
- **SysMain / WSearch / «оптимизаторы»** — карго-культ, на SSD вреда от них нет.

## Проверьте сначала (частые «бесплатные» победы не в Windows, а в BIOS)

- **XMP/DOCP**: `Get-CimInstance Win32_PhysicalMemory | Select Speed, ConfiguredClockSpeed` —
  если Configured ниже паспортной, память работает на 2133 и это главный тормоз.
- **Resizable BAR**: `nvidia-smi -q -d MEMORY` — BAR1 Total = 256 MiB означает
  «выключен»; включается двумя опциями в BIOS (Above 4G Decoding + Re-Size BAR
  Support), нужен UEFI/GPT.
