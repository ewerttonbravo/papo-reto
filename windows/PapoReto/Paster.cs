using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using PapoReto.Core;

namespace PapoReto;

/// <summary>The Win32 clipboard; the snapshot copies every memory format in the original order. GDI handle formats are
/// skipped: Windows synthesizes the bitmap from the DIB.</summary>
sealed class WindowsClipboard : IClipboard<List<(uint Format, byte[] Data)>>, IDisposable
{
    const uint CF_UNICODETEXT = 13, GMEM_MOVEABLE = 2;
    // CF_BITMAP, CF_METAFILEPICT, CF_PALETTE, CF_ENHMETAFILE, CF_OWNERDISPLAY, CF_DSPBITMAP, CF_DSPMETAFILEPICT, CF_DSPENHMETAFILE.
    static readonly HashSet<uint> Handles = [2, 3, 9, 14, 0x80, 0x82, 0x83, 0x8E];
    // Password managers mark their copies with it; Ditto and other managers skip what carries it.
    static readonly uint Exclude = RegisterClipboardFormat("ExcludeClipboardContentFromMonitorProcessing");
    static readonly uint History = RegisterClipboardFormat("CanIncludeInClipboardHistory");
    static readonly uint Cloud = RegisterClipboardFormat("CanUploadToCloudClipboard");
    static readonly byte[] Zero = BitConverter.GetBytes(0);

    // With no window, EmptyClipboard leaves no owner and SetClipboardData fails.
    readonly NativeWindow window = new();

    public WindowsClipboard() => window.CreateHandle(new CreateParams { Parent = new IntPtr(-3) }); // HWND_MESSAGE

    public uint Sequence => GetClipboardSequenceNumber();

    public List<(uint Format, byte[] Data)> Snapshot()
    {
        var formats = new List<(uint, byte[])>();
        Open();
        try
        {
            for (var format = EnumClipboardFormats(0); format != 0; format = EnumClipboardFormats(format))
            {
                // The private and GDI object ranges hold handles the system does not describe.
                if (Handles.Contains(format) || format is >= 0x200 and <= 0x3FF) continue;
                if (Copy(GetClipboardData(format)) is { } data) formats.Add((format, data));
            }
        }
        finally { CloseClipboard(); }
        return formats;
    }

    public void WriteExcluded(string text) =>
        Write([(CF_UNICODETEXT, Encoding.Unicode.GetBytes(text + '\0')), (Exclude, Zero), (History, Zero), (Cloud, Zero)]);

    // Already in the history since the user's copy: written again, it would show twice.
    public void Restore(List<(uint Format, byte[] Data)> snapshot) => Write([.. snapshot, (History, Zero), (Cloud, Zero)]);

    public bool IsConcealed(List<(uint Format, byte[] Data)> snapshot) => snapshot.Exists(f => f.Format == Exclude);

    public void Dispose() => window.DestroyHandle();

    void Write(List<(uint Format, byte[] Data)> formats)
    {
        Open();
        try
        {
            EmptyClipboard();
            foreach (var (format, data) in formats) Set(format, data);
        }
        finally { CloseClipboard(); }
    }

    // Clipboard managers open it for a moment after every copy, ours included.
    void Open()
    {
        for (var attempt = 1; !OpenClipboard(window.Handle); attempt++)
        {
            if (attempt == 5) throw new Win32Exception();
            Thread.Sleep(10);
        }
    }

    static byte[]? Copy(IntPtr handle)
    {
        var source = GlobalLock(handle);
        if (source == IntPtr.Zero) return null;
        try
        {
            var data = new byte[(int)GlobalSize(handle)];
            Marshal.Copy(source, data, 0, data.Length);
            return data;
        }
        finally { GlobalUnlock(handle); }
    }

    static void Set(uint format, byte[] data)
    {
        var handle = GlobalAlloc(GMEM_MOVEABLE, (UIntPtr)Math.Max(data.Length, 1));
        if (handle == IntPtr.Zero) throw new Win32Exception();
        Marshal.Copy(data, 0, GlobalLock(handle), data.Length);
        GlobalUnlock(handle);
        // The system owns the memory once SetClipboardData succeeds.
        if (SetClipboardData(format, handle) != IntPtr.Zero) return;
        var error = new Win32Exception();
        GlobalFree(handle);
        throw error;
    }

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool OpenClipboard(IntPtr owner);

    [DllImport("user32.dll")]
    static extern bool CloseClipboard();

    [DllImport("user32.dll")]
    static extern bool EmptyClipboard();

    [DllImport("user32.dll")]
    static extern uint EnumClipboardFormats(uint format);

    [DllImport("user32.dll")]
    static extern IntPtr GetClipboardData(uint format);

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr SetClipboardData(uint format, IntPtr data);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern uint RegisterClipboardFormat(string name);

    [DllImport("user32.dll")]
    static extern uint GetClipboardSequenceNumber();

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr GlobalAlloc(uint flags, UIntPtr bytes);

    [DllImport("kernel32.dll")]
    static extern IntPtr GlobalFree(IntPtr handle);

    [DllImport("kernel32.dll")]
    static extern IntPtr GlobalLock(IntPtr handle);

    [DllImport("kernel32.dll")]
    static extern bool GlobalUnlock(IntPtr handle);

    [DllImport("kernel32.dll")]
    static extern UIntPtr GlobalSize(IntPtr handle);
}

/// <summary>Synthetic Ctrl+V to the focused app. Windows drops it in silence for an elevated app (UIPI).</summary>
sealed class WindowsKeyboard : IKeyboard
{
    // Virtual keys, so V is V on every layout. Left Ctrl: AltGr already sends a Left Ctrl of its own.
    const ushort VK_LCONTROL = 0xA2, VK_V = 0x56;
    const uint INPUT_KEYBOARD = 1, KEYEVENTF_KEYUP = 2;

    public void PressCtrlV()
    {
        INPUT[] inputs = [Key(VK_LCONTROL, 0), Key(VK_V, 0), Key(VK_V, KEYEVENTF_KEYUP), Key(VK_LCONTROL, KEYEVENTF_KEYUP)];
        if (SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>()) != inputs.Length) throw new Win32Exception();
    }

    static INPUT Key(ushort key, uint flags) => new() { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { wVk = key, dwFlags = flags } };

    // The union is as large as MOUSEINPUT, its largest member: SendInput rejects any other size. Offset 8 is win-x64's.
    [StructLayout(LayoutKind.Explicit)]
    struct INPUT
    {
        [FieldOffset(0)] public uint type;
        [FieldOffset(8)] public KEYBDINPUT ki;
        [FieldOffset(8)] public MOUSEINPUT mi;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct KEYBDINPUT
    {
        public ushort wVk, wScan;
        public uint dwFlags, time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT
    {
        public int dx, dy;
        public uint mouseData, dwFlags, time;
        public UIntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    static extern uint SendInput(uint count, INPUT[] inputs, int size);
}
