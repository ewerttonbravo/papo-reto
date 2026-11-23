using System.ComponentModel;
using System.Runtime.InteropServices;

namespace PapoReto;

/// <summary>AltGr (Right Alt) through a low-level keyboard hook that only observes: the key still reaches the focused app.
/// ABNT2 notebooks have no Right Ctrl; AltGr is on every layout (Right Alt on US).</summary>
sealed class HotkeyMonitor : IDisposable
{
    const int WH_KEYBOARD_LL = 13;
    const int WM_KEYDOWN = 0x0100, WM_KEYUP = 0x0101, WM_SYSKEYDOWN = 0x0104, WM_SYSKEYUP = 0x0105, WM_QUIT = 0x0012;
    const uint VK_RMENU = 0xA5, VK_ESCAPE = 0x1B;
    /// <summary>dwExtraInfo of the keys the app sends itself ("PAPO"), which the hook ignores.</summary>
    public const nuint OwnInput = 0x5041504F;

    readonly SynchronizationContext ui = SynchronizationContext.Current!;
    readonly Action<TimeSpan?> pressed;
    readonly Action<TimeSpan> released;
    readonly Action<bool> keyPressed;
    // Retained: native code holds the only other reference, which the GC does not see.
    readonly HookProc proc;
    IntPtr hook;
    uint threadId;
    // The event time of the press; null while up, which also drops the keyboard's auto-repeat.
    uint? downAt;
    // The event time of the last release, for the double tap; null until the first one.
    uint? upAt;

    /// <param name="pressed">Gets the time since the last release, null on the first press.</param>
    /// <param name="keyPressed">Any other key down but a modifier; true for Esc.</param>
    public HotkeyMonitor(Action<TimeSpan?> pressed, Action<TimeSpan> released, Action<bool> keyPressed)
    {
        this.pressed = pressed;
        this.released = released;
        this.keyPressed = keyPressed;
        proc = Callback;
        // Windows calls the hook on the installing thread, and every key in the system waits for it:
        // a thread of its own keeps the UI's slow work (microphone start, clipboard) out of typing.
        var installed = new TaskCompletionSource<int>();
        new Thread(() =>
        {
            threadId = GetCurrentThreadId();
            hook = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(null), 0);
            installed.SetResult(hook == IntPtr.Zero ? Marshal.GetLastWin32Error() : 0);
            if (hook == IntPtr.Zero) return;
            while (GetMessage(out _, IntPtr.Zero, 0, 0) > 0) { }
            UnhookWindowsHookEx(hook);
        }) { IsBackground = true, Name = "hotkey" }.Start();
        if (installed.Task.Result is var error and not 0) throw new Win32Exception(error);
    }

    // Windows silently removes a hook that is slow to return, so the work goes to the UI queue.
    IntPtr Callback(int code, IntPtr message, IntPtr data)
    {
        if (code >= 0 && Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(data) is var key && key.dwExtraInfo != OwnInput)
        {
            var msg = (int)message;
            var down = msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN;
            if (key.vkCode == VK_RMENU && down && downAt is null)
            {
                downAt = key.time;
                TimeSpan? sinceRelease = upAt is uint up ? Elapsed(up, key.time) : null;
                ui.Post(_ => pressed(sinceRelease), null);
            }
            else if (key.vkCode == VK_RMENU && (msg == WM_KEYUP || msg == WM_SYSKEYUP) && downAt is uint at)
            {
                downAt = null;
                upAt = key.time;
                var held = Elapsed(at, key.time);
                ui.Post(_ => released(held), null);
            }
            // Modifiers alone never cancel, as on the Mac; this also covers AltGr's own auto-repeat
            // and the fake Left Ctrl that AltGr sends on layouts like ABNT2.
            else if (down && !IsModifier(key.vkCode))
            {
                var isEscape = key.vkCode == VK_ESCAPE;
                ui.Post(_ => keyPressed(isEscape), null);
            }
        }
        return CallNextHookEx(hook, code, message, data);
    }

    // Event times in ms, as GetTickCount: unsigned subtraction survives the 49-day wrap.
    static TimeSpan Elapsed(uint from, uint to) => TimeSpan.FromMilliseconds(unchecked(to - from));

    // Shift, Ctrl, Alt (generic, left and right), Caps Lock and the Windows keys.
    static bool IsModifier(uint vk) => vk is >= 0x10 and <= 0x12 or 0x14 or 0x5B or 0x5C or >= 0xA0 and <= 0xA5;

    public void Dispose() => PostThreadMessage(threadId, WM_QUIT, IntPtr.Zero, IntPtr.Zero);

    delegate IntPtr HookProc(int code, IntPtr message, IntPtr data);

    [StructLayout(LayoutKind.Sequential)]
    struct KBDLLHOOKSTRUCT
    {
        public uint vkCode, scanCode, flags, time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct MSG
    {
        public IntPtr hwnd;
        public uint message;
        public IntPtr wParam, lParam;
        public uint time;
        public int x, y, lPrivate;
    }

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr SetWindowsHookEx(int idHook, HookProc proc, IntPtr module, uint threadId);

    [DllImport("user32.dll")]
    static extern bool UnhookWindowsHookEx(IntPtr hook);

    [DllImport("user32.dll")]
    static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr message, IntPtr data);

    [DllImport("user32.dll")]
    static extern int GetMessage(out MSG msg, IntPtr hwnd, uint min, uint max);

    [DllImport("user32.dll")]
    static extern bool PostThreadMessage(uint threadId, int message, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll")]
    static extern uint GetCurrentThreadId();

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr GetModuleHandle(string? name);
}
