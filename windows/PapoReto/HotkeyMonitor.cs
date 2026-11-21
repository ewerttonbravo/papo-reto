using System.ComponentModel;
using System.Runtime.InteropServices;

namespace PapoReto;

/// <summary>Right Ctrl through a low-level keyboard hook that only observes: the key still reaches the focused app.</summary>
sealed class HotkeyMonitor : IDisposable
{
    const int WH_KEYBOARD_LL = 13;
    const int WM_KEYDOWN = 0x0100, WM_KEYUP = 0x0101, WM_SYSKEYDOWN = 0x0104, WM_SYSKEYUP = 0x0105;
    const uint VK_RCONTROL = 0xA3;

    readonly SynchronizationContext ui = SynchronizationContext.Current!;
    readonly Action pressed;
    readonly Action<TimeSpan> released;
    // Retained: native code holds the only other reference, which the GC does not see.
    readonly HookProc proc;
    readonly IntPtr hook;
    // The event time of the press; null while up, which also drops the keyboard's auto-repeat.
    uint? downAt;

    public HotkeyMonitor(Action pressed, Action<TimeSpan> released)
    {
        this.pressed = pressed;
        this.released = released;
        proc = Callback;
        hook = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(null), 0);
        if (hook == IntPtr.Zero) throw new Win32Exception();
    }

    // Windows silently removes a hook that is slow to return, so the work goes to the UI queue.
    IntPtr Callback(int code, IntPtr message, IntPtr data)
    {
        if (code >= 0)
        {
            var key = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(data);
            var msg = (int)message;
            if (key.vkCode == VK_RCONTROL && (msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN) && downAt is null)
            {
                downAt = key.time;
                ui.Post(_ => pressed(), null);
            }
            else if (key.vkCode == VK_RCONTROL && (msg == WM_KEYUP || msg == WM_SYSKEYUP) && downAt is uint at)
            {
                downAt = null;
                // Event times in ms, as GetTickCount: unsigned subtraction survives the 49-day wrap.
                var held = TimeSpan.FromMilliseconds(unchecked(key.time - at));
                ui.Post(_ => released(held), null);
            }
        }
        return CallNextHookEx(hook, code, message, data);
    }

    public void Dispose() => UnhookWindowsHookEx(hook);

    delegate IntPtr HookProc(int code, IntPtr message, IntPtr data);

    [StructLayout(LayoutKind.Sequential)]
    struct KBDLLHOOKSTRUCT
    {
        public uint vkCode, scanCode, flags, time;
        public UIntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr SetWindowsHookEx(int idHook, HookProc proc, IntPtr module, uint threadId);

    [DllImport("user32.dll")]
    static extern bool UnhookWindowsHookEx(IntPtr hook);

    [DllImport("user32.dll")]
    static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr message, IntPtr data);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr GetModuleHandle(string? name);
}
