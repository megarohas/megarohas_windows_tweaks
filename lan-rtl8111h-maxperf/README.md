# lan-rtl8111h-maxperf

Realtek RTL8111H GbE (PCIe, `VEN_10EC&DEV_8168`), встроенный в MSI B450M
MORTAR MAX.

Главная находка: **GigaLite тихо режет гигабит до ~500 Мбит** — «зелёная»
фича, включённая по умолчанию, о которой адаптер никак не сообщает. Остальные
энергосберегайки (EEE, Green Ethernet, Power Saving Mode) добавляют латентность
и микрофризы; Interrupt Moderation меняет пропускную способность на задержку.

## Твики — `apply-lan-tweaks.ps1` (от администратора)

Ставятся через `Set-NetAdapterAdvancedProperty -RegistryValue` —
**локаленезависимо**, работает на системе с любым языком интерфейса
(DisplayValue типа «Выкл.»/«Disabled» не используется):

| Параметр | Значение |
|---|---|
| `*EEE` (Energy-Efficient Ethernet) | 0 |
| `EnableGreenEthernet` | 0 |
| `GigaLite` | 0 |
| `PowerSavingMode` | 0 |
| `*InterruptModeration` | 0 |
| `*ReceiveBuffers` / `*TransmitBuffers` | максимум железа (у RTL8111H — 512/128) |

Плюс **MSPower_DeviceEnable → False** (запрет отключения для экономии
энергии). Все изменения ставятся с `-NoRestart`, адаптер перезапускается один
раз в конце — и только если что-то реально поменялось (линк моргнёт ~2 с).

## Драйвер

`rt640x64` **10.79.50.1003** (окт. 2025) — родной Realtek с Microsoft Update
Catalog / сайта MSI. Держу страховочную копию CAB'а: Insider-флайт 23.08.2026
заменил его на inbox-заглушку `rtcx21x64.sys` (Microsoft, 1.0.0.14, 2017),
которая грузилась «успешно», но не поднимала PHY — порт выглядел мёртвым при
полностью «исправном» устройстве в диспетчере.

На моей машине этот сценарий автоматически чинит [boot-guard](../boot-guard/).
