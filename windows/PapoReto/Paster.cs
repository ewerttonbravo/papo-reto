using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using PapoReto.Core;

namespace PapoReto;

/// <summary>The Win32 clipboard; the snapshot copies every memory format and the EMF in the original order. The other
/// GDI handles are skipped: Windows synthesizes the bitmap from the DIB and the old metafile from the EMF.</summary>
sealed class WindowsClipboard : IClipboard<List<(uint Format, byte[] Data)>>, IDisposable
{
    const uint CF_UNICODETEXT = 13, CF_ENHMETAFILE = 14, GMEM_MOVEABLE = 2;
    // CF_BITMAP, CF_METAFILEPICT, CF_PALETTE, CF_OWNERDISPLAY, CF_DSPBITMAP, CF_DSPMETAFILEPICT, CF_DSPENHMETAFILE, and the
    // source app's live OLE object, which written back as bytes would describe data that is no longer there.
    static readonly HashSet<uint> Skipped =
        [2, 3, 9, 0x80, 0x82, 0x83, 0x8E, RegisterClipboardFormat("DataObject"), RegisterClipboardFormat("Ole Private Data")];
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
                if (Skipped.Contains(format) || format is >= 0x200 and <= 0x3FF) continue;
                var handle = GetClipboardData(format);
                if ((format == CF_ENHMETAFILE ? MetafileBits(handle) : Copy(handle)) is { } data) formats.Add((format, data));
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

    // Allocated before emptying, so a failed allocation or a busy clipboard leaves it as it was.
    void Write(List<(uint Format, byte[] Data)> formats)
    {
        var handles = new List<(uint Format, IntPtr Handle)>();
        try
        {
            foreach (var (format, data) in formats) handles.Add((format, Allocate(format, data)));
            Open();
        }
        catch
        {
            handles.ForEach(Free);
            throw;
        }
        try
        {
            EmptyClipboard();
            // The system owns each handle it takes; one it refuses is freed and the others still go.
            foreach (var handle in handles)
                if (SetClipboardData(handle.Format, handle.Handle) == IntPtr.Zero) Free(handle);
        }
        finally { CloseClipboard(); }
    }

    // Clipboard managers open it for a moment after every copy, ours included. 10 x 100 ms, as WinForms retries.
    void Open()
    {
        for (var attempt = 1; !OpenClipboard(window.Handle); attempt++)
        {
            if (attempt == 10) throw new Win32Exception();
            Thread.Sleep(100);
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

    static byte[]? MetafileBits(IntPtr metafile)
    {
        var size = GetEnhMetaFileBits(metafile, 0, null);
        if (size == 0) return null;
        var data = new byte[size];
        return GetEnhMetaFileBits(metafile, size, data) == size ? data : null;
    }

    static IntPtr Allocate(uint format, byte[] data)
    {
        if (format == CF_ENHMETAFILE)
        {
            var metafile = SetEnhMetaFileBits((uint)data.Length, data);
            return metafile != IntPtr.Zero ? metafile : throw new Win32Exception();
        }
        var handle = GlobalAlloc(GMEM_MOVEABLE, (UIntPtr)Math.Max(data.Length, 1));
        if (handle == IntPtr.Zero) throw new Win32Exception();
        var target = GlobalLock(handle);
        if (target == IntPtr.Zero)
        {
            var error = new Win32Exception();
            GlobalFree(handle);
            throw error;
        }
        Marshal.Copy(data, 0, target, data.Length);
        GlobalUnlock(handle);
        return handle;
    }

    static void Free((uint Format, IntPtr Handle) handle)
    {
        if (handle.Format == CF_ENHMETAFILE) DeleteEnhMetaFile(handle.Handle);
        else GlobalFree(handle.Handle);
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

    [DllImport("gdi32.dll")]
    static extern uint GetEnhMetaFileBits(IntPtr metafile, uint size, byte[]? data);

    [DllImport("gdi32.dll", SetLastError = true)]
    static extern IntPtr SetEnhMetaFileBits(uint size, byte[] data);

    [DllImport("gdi32.dll")]
    static extern bool DeleteEnhMetaFile(IntPtr metafile);
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
        // Blocked by a UAC prompt or the lock screen, it pastes nothing and the restore still runs: only the log says so.
        if (SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>()) != inputs.Length)
            Log.Write("paste", $"Ctrl+V blocked: {new Win32Exception().Message}");
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
