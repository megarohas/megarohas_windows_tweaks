# bios-b450m-mortar-max

Обновление BIOS на MSI B450M MORTAR MAX (MS-7B89) на примере 2.E3 → 2.O
с включением **Resizable BAR** и **PBO**. Проверено на связке
Ryzen 5 3600 + RTX 3060 12GB, Windows 11 (UEFI/GPT).

## Зачем обновляться со старых версий

- **v2H (AGESA 1.2.0.7)** — фикс знаменитого **fTPM-статтера** AM4: периодические
  микрофризы всей системы при включённом fTPM (а он включён у всех на Win11).
- **v2K / v2L** — заплатки Inception и LogoFAIL.
- **v2N / v2O** — AGESA 1.2.0.E/F, финальные maintenance-версии.
- **v2P1 (Beta)** — обновление прошивки fTPM для совместимости с новыми античитами.
- **Resizable BAR** плата умеет начиная с v2C (AGESA 1.2.0.0), но по умолчанию
  он выключен — это бесплатные +3–8 % в поддерживаемых играх.

## Включён ли ReBAR сейчас

```powershell
nvidia-smi -q -d MEMORY
```

`BAR1 Memory Usage → Total: 256 MiB` — выключен. После включения BAR1 равен
объёму VRAM, округлённому вверх до степени двойки (у 12-гигабайтной карты —
16384 MiB). Обязательное условие: Windows в UEFI/GPT (проверка:
`$env:firmware_type` → `UEFI`).

## Скачивание

Официальная страница: <https://www.msi.com/Motherboard/B450M-MORTAR-MAX/support>
(файл вида `7B89v2O.zip`, ~18 МБ; внутри образ `E7B89AMS.2O0` и release notes).

## Подготовка

1. USB-флешка в **FAT32**, файл `E7B89AMS.2O0` — в корень.
2. Если включено шифрование устройства/BitLocker — **приостановить**
   (`Suspend-BitLocker -MountPoint C: -RebootCount 2` от админа), иначе после
   прошивки Windows попросит ключ восстановления.
3. Во время прошивки (~5 минут) не выключать питание.

## Прошивка (M-Flash)

1. Перезагрузка → **Del** → BIOS → кнопка **M-FLASH** → Yes.
2. Плата перезагрузится в режим прошивки: выбрать флешку → `E7B89AMS.2O0` → Yes.
3. Дождаться конца прогресс-бара и автоперезагрузки.

## После прошивки — обязательно (настройки сбрасываются на дефолт!)

Del → BIOS → F7 (Advanced mode):

| Что | Где | Значение |
|---|---|---|
| **A-XMP** | OC → A-XMP | **Profile 1** — иначе память останется на 2133! |
| **fTPM** | Settings → Security → Trusted Computing | AMD fTPM switch = **AMD CPU fTPM** (нужен для Win11; проверить) |
| **Above 4G** | Settings → Advanced → PCI Subsystem Settings | Above 4G memory/Crypto Currency mining = **Enabled** |
| **ReBAR** | там же | Re-Size BAR Support = **Enabled** (пункт появляется после Above 4G) |
| **UEFI** | Settings → Advanced → Windows OS Configuration | BIOS UEFI/CSM Mode = **UEFI** |
| PBO (опционально) | OC → Advanced CPU Configuration | Precision Boost Overdrive = **Enabled** (+100–200 МГц в многопотоке на Zen 2 при нормальном охлаждении) |

F10 → Save & Exit.

## Проверка после загрузки

- `nvidia-smi -q -d MEMORY` → BAR1 = 16384 MiB (для 12 ГБ карты);
- `Get-CimInstance Win32_PhysicalMemory | Select Speed, ConfiguredClockSpeed` → 3200/3200;
- `tpmtool getdeviceinformation` → TPM Present: True, Version 2.0.

## Грабли

- **Включение Above 4G/ReBAR перераспределяет PCI-ресурсы**, и Windows может
  пересоздать устройства со сбросом их advanced-настроек. На этой плате после
  включения слетели все пять твиков LAN-адаптера, включая GigaLite (тихо режет
  гигабит до ~500 Мбит). Если стоит [boot-guard](../boot-guard/) — он перепрожмёт
  всё сам на первой загрузке; иначе проверьте настройки сетевых адаптеров руками
  (см. [lan-rtl8111h-maxperf](../lan-rtl8111h-maxperf/)).
- Если после смены настроек памяти система не стартует — Clear CMOS (перемычка
  JBAT1 или батарейка на 30 секунд) и настроить заново.
