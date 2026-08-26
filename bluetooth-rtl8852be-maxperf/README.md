# bluetooth-rtl8852be-maxperf

Realtek RTL8852BE — Bluetooth-половина комбо-карты (USB, `VID_13D3&PID_3570`,
модуль AzureWave). Windows по умолчанию агрессивно её усыпляет — отсюда
заикания звука в наушниках, отвалы геймпада и полусекундные «просыпания»
после паузы.

## Твики — `apply-bt-tweaks.ps1` (от администратора)

1. **MSPower_DeviceEnable → False** — программно снятая галка «Разрешить
   отключение этого устройства для экономии энергии» из диспетчера устройств
   (через WMI `root/wmi`).
2. **SelectiveSuspendEnabled → 0** в
   `HKLM\SYSTEM\CurrentControlSet\Enum\USB\VID_13D3&PID_3570\...\Device Parameters` —
   запрет USB selective suspend конкретно для BT-модуля.
3. **USB selective suspend → Запрещено** в активной схеме питания (AC и DC).
4. Рестарт устройства через `pnputil`, чтобы параметры подхватились без
   перезагрузки (BT моргнёт на пару секунд).

Скрипт идемпотентный — можно запускать сколько угодно раз.

## Драйвер

`rtkbtfilter` **18.4038.2509.1901** из Microsoft Update Catalog — новая
архитектура Realtek: фильтр-драйвер `RtkBtFilter2.sys` + сервис
`RtkBtManServ`. Штатные 1.9.x (2022) заметно хуже держат соединение.

Откат драйвера после Insider-флайтов автоматически чинит
[boot-guard](../boot-guard/).
