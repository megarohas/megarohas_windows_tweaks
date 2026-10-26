// DisplayHotkeys — горячие клавиши режима проецирования (то же, что Win+P):
//   Win+M+1 — только экран компьютера, Win+M+2 — только второй экран.
// Обычный Win+M (свернуть все окна) продолжает работать, если цифру не нажали.
// Сборка: build.ps1 (csc из .NET Framework 4, C# 5).
using System;
using System.Collections.Concurrent;
using System.Runtime.InteropServices;
using System.Threading;

static class Program
{
    const int WH_KEYBOARD_LL = 13;
    const int WM_KEYDOWN = 0x100, WM_SYSKEYDOWN = 0x104;
    const int VK_SHIFT = 0x10, VK_CONTROL = 0x11, VK_MENU = 0x12;
    const int VK_LWIN = 0x5B, VK_RWIN = 0x5C, VK_M = 0x4D;
    const int VK_1 = 0x31, VK_2 = 0x32, VK_NUMPAD1 = 0x61, VK_NUMPAD2 = 0x62;
    // Неназначенная клавиша: её нажатие при зажатом Win не даёт открыться «Пуску»,
    // когда M и цифру мы проглотили и система видит «голый» Win.
    const int VK_MASK = 0xE8;
    const uint KEYEVENTF_EXTENDEDKEY = 0x1, KEYEVENTF_KEYUP = 0x2;
    const uint SDC_APPLY = 0x80, SDC_TOPOLOGY_INTERNAL = 0x1, SDC_TOPOLOGY_EXTERNAL = 0x8;
    const uint MB_ICONHAND = 0x10;
    // Метка наших собственных SendInput, чтобы хук пропускал их мимо себя.
    static readonly IntPtr Marker = (IntPtr)0x44484B59;

    [StructLayout(LayoutKind.Sequential)]
    struct KBDLLHOOKSTRUCT { public uint vkCode, scanCode, flags, time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Sequential)]
    struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Explicit)]
    struct InputUnion { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }

    [StructLayout(LayoutKind.Sequential)]
    struct INPUT { public uint type; public InputUnion u; }

    [StructLayout(LayoutKind.Sequential)]
    struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam, lParam; public uint time; public int x, y, lPrivate; }

    delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, HookProc fn, IntPtr hMod, uint threadId);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hhk, int code, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
    [DllImport("user32.dll")] static extern uint SendInput(uint count, INPUT[] inputs, int size);
    [DllImport("user32.dll")] static extern int GetMessage(out MSG msg, IntPtr hwnd, uint min, uint max);
    [DllImport("user32.dll")] static extern int SetDisplayConfig(uint numPaths, IntPtr paths, uint numModes, IntPtr modes, uint flags);
    [DllImport("user32.dll")] static extern bool MessageBeep(uint type);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string name);

    static readonly HookProc hookProc = Hook;  // держим ссылку, чтобы делегат не собрал GC
    // Всё медленное (SendInput, переключение экранов) — в отдельном потоке по очереди:
    // хук обязан отвечать мгновенно, иначе Windows его снимет.
    static readonly BlockingCollection<Action> work = new BlockingCollection<Action>();

    static bool chord;   // M перехвачена при зажатом Win
    static bool used;    // в этом нажатии M уже переключили экран (или отыграли Win+M)
    static int digitVk;  // проглоченная цифра — глотаем и её автоповтор с отпусканием

    static void Main()
    {
        bool first;
        using (new Mutex(true, @"Local\DisplayHotkeys", out first))
        {
            if (!first) return;
            var worker = new Thread(() => { foreach (var job in work.GetConsumingEnumerable()) job(); });
            worker.IsBackground = true;
            worker.Start();
            if (SetWindowsHookEx(WH_KEYBOARD_LL, hookProc, GetModuleHandle(null), 0) == IntPtr.Zero) return;
            MSG msg;
            while (GetMessage(out msg, IntPtr.Zero, 0, 0) > 0) { }
        }
    }

    static IntPtr Hook(int code, IntPtr wParam, IntPtr lParam)
    {
        if (code >= 0)
        {
            var k = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
            bool down = (int)wParam == WM_KEYDOWN || (int)wParam == WM_SYSKEYDOWN;
            if (k.dwExtraInfo != Marker && Swallow((int)k.vkCode, down)) return (IntPtr)1;
        }
        return CallNextHookEx(IntPtr.Zero, code, wParam, lParam);
    }

    static bool Swallow(int vk, bool down)
    {
        if (vk == VK_M)
        {
            if (down)
            {
                if (chord) return true;  // автоповтор
                if (!WinHeld() || Held(VK_SHIFT) || Held(VK_CONTROL) || Held(VK_MENU)) return false;  // Win+Shift+M и пр. не трогаем
                chord = true;
                used = false;
                Send(Key(VK_MASK, false), Key(VK_MASK, true));
                return true;
            }
            if (!chord) return false;
            chord = false;
            if (!used) Send(Key(VK_M, false), Key(VK_M, true));  // цифру не нажали — обычный Win+M
            return true;
        }
        if (vk == VK_LWIN || vk == VK_RWIN)
        {
            // Win отпустили раньше M, а цифры не было — отыгрываем Win+M, пока Win ещё «зажат».
            if (down || !chord || used) return false;
            used = true;
            Send(Key(VK_M, false), Key(VK_M, true), Key(vk, true));
            return true;
        }
        if (digitVk != 0 && vk == digitVk)
        {
            if (!down) digitVk = 0;
            return true;
        }
        uint topology = vk == VK_1 || vk == VK_NUMPAD1 ? SDC_TOPOLOGY_INTERNAL
                      : vk == VK_2 || vk == VK_NUMPAD2 ? SDC_TOPOLOGY_EXTERNAL : 0;
        if (topology == 0 || !down || !chord || !WinHeld()) return false;
        digitVk = vk;
        used = true;
        uint flags = SDC_APPLY | topology;
        work.Add(() => { if (SetDisplayConfig(0, IntPtr.Zero, 0, IntPtr.Zero, flags) != 0) MessageBeep(MB_ICONHAND); });
        return true;
    }

    static bool Held(int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; }

    static bool WinHeld() { return Held(VK_LWIN) || Held(VK_RWIN); }

    static INPUT Key(int vk, bool up)
    {
        var input = new INPUT { type = 1 };
        uint flags = up ? KEYEVENTF_KEYUP : 0;
        if (vk == VK_LWIN || vk == VK_RWIN) flags |= KEYEVENTF_EXTENDEDKEY;
        input.u.ki = new KEYBDINPUT { wVk = (ushort)vk, dwFlags = flags, dwExtraInfo = Marker };
        return input;
    }

    static void Send(params INPUT[] keys)
    {
        work.Add(() => SendInput((uint)keys.Length, keys, Marshal.SizeOf(typeof(INPUT))));
    }
}
