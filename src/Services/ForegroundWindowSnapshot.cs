// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Capture the actual foreground identity once. Taskbar flashing is not a focus signal.
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
namespace RazerBatteryTray
{
    public sealed class ForegroundWindowSnapshot
    {
        public IntPtr Window { get; private set; }
        public uint ProcessId { get; private set; }
        public string ProcessName { get; private set; }
        public string ExecutablePath { get; private set; }
        public bool Known { get; private set; }
        public string Key { get { return Window.ToInt64().ToString("x") + ":" + ProcessId + ":" + ProcessName; } }
        [DllImport("kernel32.dll", SetLastError = true)] private static extern IntPtr OpenProcess(uint access, bool inherit, uint processId);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern bool QueryFullProcessImageName(IntPtr process, uint flags, StringBuilder path, ref uint size);
        public bool IsCurrent()
        {
            IntPtr foreground = NativeMethods.GetForegroundWindow(); uint id;
            NativeMethods.GetWindowThreadProcessId(foreground, out id);
            return Known && foreground == Window && id == ProcessId;
        }
        public static ForegroundWindowSnapshot Capture()
        {
            var result = new ForegroundWindowSnapshot { ProcessName = "", ExecutablePath = "" };
            result.Window = NativeMethods.GetForegroundWindow();
            if (result.Window == IntPtr.Zero) return result;
            uint processId; NativeMethods.GetWindowThreadProcessId(result.Window, out processId); result.ProcessId = processId;
            if (processId == 0) return result;
            IntPtr process = OpenProcess(0x1000, false, processId); // Limited query works across process bitness and avoids reading modules.
            try
            {
                if (process != IntPtr.Zero)
                {
                    StringBuilder path = new StringBuilder(32768); uint length = (uint)path.Capacity;
                    if (QueryFullProcessImageName(process, 0, path, ref length))
                    { result.ExecutablePath = path.ToString(); result.ProcessName = Path.GetFileNameWithoutExtension(result.ExecutablePath); }
                }
                if (result.ProcessName.Length == 0)
                {
                    try { using (Process fallback = Process.GetProcessById((int)processId)) result.ProcessName = fallback.ProcessName; }
                    catch { }
                }
                result.Known = result.ProcessName.Length > 0 && NativeMethods.GetForegroundWindow() == result.Window;
                return result;
            }
            finally { if (process != IntPtr.Zero) RazerDeviceHelper.CloseHandle(process); }
        }
    }
}
