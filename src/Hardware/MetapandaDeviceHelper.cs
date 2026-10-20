// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Endpoint-isolated Metapanda HID discovery/transport. C# 5 / .NET 4, no dependencies.
// Publish the verified discharge-voltage estimate rather than freezing on the coarse battery byte.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
namespace RazerBatteryTray
{
    public static class MetapandaDeviceHelper
    {
        private const string Prefix = "Metapanda:";
        private static readonly object Gate = new object();
        private static readonly Dictionary<string, object> EndpointLocks = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        [StructLayout(LayoutKind.Sequential)]
        private struct Overlapped { public IntPtr Internal, InternalHigh; public uint Offset, OffsetHigh; public IntPtr Event; }
        [DllImport("kernel32.dll", SetLastError = true)] private static extern IntPtr CreateEvent(IntPtr attributes, bool manualReset, bool initial, string name);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool ReadFile(IntPtr handle, IntPtr buffer, uint length, out uint transferred, IntPtr overlapped);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool DeviceIoControl(IntPtr handle, uint code, IntPtr input, uint inputLength, IntPtr output, uint outputLength, out uint transferred, IntPtr overlapped);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool GetOverlappedResult(IntPtr handle, IntPtr overlapped, out uint transferred, bool wait);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool CancelIoEx(IntPtr handle, IntPtr overlapped);
        [DllImport("hid.dll", SetLastError = true)] private static extern bool HidD_FlushQueue(IntPtr handle);
        private sealed class Endpoint { public string Path, Name; public ushort Pid; public int InputLength; }
        public static bool IsKnownDevicePath(string path)
        {
            if (string.IsNullOrEmpty(path)) return false;
            string value = path.ToLowerInvariant();
            return value.Contains("vid_3554&pid_f5a9&") || value.Contains("vid_3554&pid_f5ab&") || value.Contains("vid_3554&pid_f5ac&");
        }
        public static bool IsMetapanda(MouseBatteryInfo device)
        {
            return device != null && !string.IsNullOrEmpty(device.DeviceId) && device.DeviceId.StartsWith(Prefix, StringComparison.Ordinal) && IsKnownDevicePath(device.DeviceId.Substring(Prefix.Length));
        }
        private static object GetLock(string path)
        {
            lock (Gate) { object result; if (!EndpointLocks.TryGetValue(path, out result)) { result = new object(); EndpointLocks.Add(path, result); } return result; }
        }
        private static bool ValidHandle(IntPtr handle) { return handle != IntPtr.Zero && handle != new IntPtr(-1); }
        private static IntPtr Open(string path) { return RazerDeviceHelper.CreateFile(path, 0xC0000000, 3, IntPtr.Zero, 3, 0x40000000, IntPtr.Zero); }
        private static List<Endpoint> Enumerate()
        {
            List<Endpoint> endpoints = new List<Endpoint>(); Guid guid; RazerDeviceHelper.HidD_GetHidGuid(out guid);
            IntPtr list = RazerDeviceHelper.SetupDiGetClassDevs(ref guid, null, IntPtr.Zero, 0x12);
            if (!ValidHandle(list)) return endpoints;
            try
            {
                RazerDeviceHelper.SP_DEVICE_INTERFACE_DATA item = new RazerDeviceHelper.SP_DEVICE_INTERFACE_DATA(); item.cbSize = Marshal.SizeOf(item);
                for (uint index = 0; RazerDeviceHelper.SetupDiEnumDeviceInterfaces(list, IntPtr.Zero, ref guid, index, ref item); index++)
                {
                    uint size; RazerDeviceHelper.SetupDiGetDeviceInterfaceDetail(list, ref item, IntPtr.Zero, 0, out size, IntPtr.Zero);
                    if (size < 8 || size > 65536) continue;
                    IntPtr detail = Marshal.AllocHGlobal((int)size);
                    try
                    {
                        Marshal.WriteInt32(detail, IntPtr.Size == 8 ? 8 : 6);
                        if (!RazerDeviceHelper.SetupDiGetDeviceInterfaceDetail(list, ref item, detail, size, out size, IntPtr.Zero)) continue;
                        string path = Marshal.PtrToStringAuto(new IntPtr(detail.ToInt64() + 4));
                        if (!IsKnownDevicePath(path)) continue;
                        IntPtr handle = Open(path); if (!ValidHandle(handle)) continue;
                        try
                        {
                            RazerDeviceHelper.HIDD_ATTRIBUTES attributes = new RazerDeviceHelper.HIDD_ATTRIBUTES(); attributes.Size = Marshal.SizeOf(attributes);
                            if (!RazerDeviceHelper.HidD_GetAttributes(handle, ref attributes) || attributes.VendorID != 0x3554 || (attributes.ProductID != 0xF5A9 && attributes.ProductID != 0xF5AB && attributes.ProductID != 0xF5AC)) continue;
                            IntPtr preparsed; if (!RazerDeviceHelper.HidD_GetPreparsedData(handle, out preparsed)) continue;
                            RazerDeviceHelper.HIDP_CAPS caps;
                            try { if (RazerDeviceHelper.HidP_GetCaps(preparsed, out caps) != 0x110000) continue; }
                            finally { RazerDeviceHelper.HidD_FreePreparsedData(preparsed); }
                            if (caps.UsagePage != 0xFF02 || caps.Usage != 2 || caps.InputReportByteLength != 17 || caps.OutputReportByteLength != 17) continue;
                            StringBuilder name = new StringBuilder(256); RazerDeviceHelper.HidD_GetProductString(handle, name, 512);
                            endpoints.Add(new Endpoint { Path = path, Name = name.ToString(), Pid = attributes.ProductID, InputLength = caps.InputReportByteLength });
                        }
                        finally { RazerDeviceHelper.CloseHandle(handle); }
                    }
                    finally { Marshal.FreeHGlobal(detail); }
                }
            }
            finally { RazerDeviceHelper.SetupDiDestroyDeviceInfoList(list); }
            return endpoints;
        }
        // Both native buffer and OVERLAPPED live in unmanaged memory until cancellation has
        // completed. No pending kernel operation can retain a movable managed byte[] address.
        private static byte[] NativeIo(IntPtr handle, byte[] output, int inputLength, int timeout)
        {
            IntPtr buffer = Marshal.AllocHGlobal(output == null ? inputLength : output.Length);
            IntPtr operation = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(Overlapped)));
            IntPtr signal = CreateEvent(IntPtr.Zero, true, false, null);
            bool pending = false;
            try
            {
                if (signal == IntPtr.Zero) return null;
                Overlapped ov = new Overlapped(); ov.Event = signal; Marshal.StructureToPtr(ov, operation, false);
                uint transferred; bool completed;
                if (output != null)
                {
                    Marshal.Copy(output, 0, buffer, output.Length);
                    // hidclass.h: HID_IN_CTL_CODE(101), same SET_REPORT Output path as HidD_SetOutputReport.
                    completed = DeviceIoControl(handle, 0x000B0195, buffer, (uint)output.Length, IntPtr.Zero, 0, out transferred, operation);
                }
                else completed = ReadFile(handle, buffer, (uint)inputLength, out transferred, operation);
                if (!completed)
                {
                    if (Marshal.GetLastWin32Error() != 997) return null;
                    pending = true;
                    if (WaitForSingleObject(signal, (uint)Math.Max(1, timeout)) != 0) return null;
                    if (!GetOverlappedResult(handle, operation, out transferred, false)) return null;
                    pending = false;
                }
                if (output != null) return new byte[0];
                if (transferred != inputLength) return null;
                byte[] result = new byte[inputLength]; Marshal.Copy(buffer, result, 0, inputLength); return result;
            }
            finally
            {
                if (pending) { uint drained; CancelIoEx(handle, operation); GetOverlappedResult(handle, operation, out drained, true); }
                if (signal != IntPtr.Zero) RazerDeviceHelper.CloseHandle(signal);
                Marshal.FreeHGlobal(operation); Marshal.FreeHGlobal(buffer);
            }
        }
        private static byte[] Exchange(IntPtr handle, byte[] request, int inputLength)
        {
            if (request == null) return null;
            HidD_FlushQueue(handle);
            if (NativeIo(handle, request, 0, 350) == null) return null;
            Stopwatch watch = Stopwatch.StartNew();
            while (watch.ElapsedMilliseconds < 450)
            {
                byte[] response = NativeIo(handle, null, inputLength, 450 - (int)watch.ElapsedMilliseconds);
                if (response == null) return null;
                if (MetapandaProtocol.MatchesResponse(request, response)) return response;
            }
            return null;
        }
        private static bool Online(IntPtr handle, Endpoint endpoint)
        {
            byte[] response = Exchange(handle, MetapandaProtocol.BuildCommand(3), endpoint.InputLength);
            return response != null && response[5] == 1 && response[6] == 1;
        }
        private static MouseBatteryInfo ReadState(IntPtr handle, Endpoint endpoint, string reason)
        {
            Stopwatch elapsed = Stopwatch.StartNew(); byte[] batteryReport = null;
            MouseBatteryInfo state = new MouseBatteryInfo();
            state.DeviceId = Prefix + endpoint.Path; state.Brand = "Metapanda"; state.Category = DeviceCategory.Mouse;
            state.DeviceName = string.IsNullOrEmpty(endpoint.Name) ? "玄熊猫鼠标" : endpoint.Name;
            state.HardwareId = "HID:3554:" + endpoint.Pid.ToString("X4"); state.HardwareFingerprint = state.DeviceId;
            state.Transport = endpoint.Pid == 0xF5AB ? "USB" : "2.4G"; state.BatteryPercent = -1; state.ExactBatteryPercent = -1;
            state.SupportedPollingRates = endpoint.Pid == 0xF5AC ? new int[] { 125, 250, 500, 1000, 2000, 4000 } : new int[] { 125, 1000 }; state.MaxPollingRate = endpoint.Pid == 0xF5AC ? 4000 : 1000;
            state.IsDonglePresent = true; state.LastUpdated = DateTime.Now;
            state.IsConnected = Online(handle, endpoint);
            if (!state.IsConnected) { DiagnosticLog.Default.RecordBattery(state, null, reason, elapsed.ElapsedMilliseconds); return state; }
            int battery; bool charging; double estimate;
            batteryReport = Exchange(handle, MetapandaProtocol.BuildCommand(4), endpoint.InputLength);
            if (MetapandaProtocol.DecodeBattery(batteryReport, out battery, out charging, out estimate))
            { state.BatteryPercent = battery; state.ExactBatteryPercent = estimate; state.IsCharging = charging; }
            byte[] memory = new byte[44]; bool complete = true; int required = 20;
            for (int address = 0; address < required; address += 10)
            {
                byte[] request = MetapandaProtocol.BuildReadMemory(address, Math.Min(10, required - address));
                if (!MetapandaProtocol.CopyMemoryResponse(request, Exchange(handle, request, endpoint.InputLength), memory)) { complete = false; break; }
                if (address == 10 && memory[10] < 8) required = Math.Max(20, 12 + (memory[10] + 1) * 4);
            }
            if (complete) MetapandaProtocol.DecodeSettings(memory, state);
            state.LastUpdated = DateTime.Now;
            DiagnosticLog.Default.RecordBattery(state, batteryReport, reason, elapsed.ElapsedMilliseconds);
            return state;
        }
        public static List<MouseBatteryInfo> QueryDevices()
        {
            List<MouseBatteryInfo> result = new List<MouseBatteryInfo>();
            foreach (Endpoint endpoint in Enumerate())
            {
                lock (GetLock(endpoint.Path))
                {
                    IntPtr handle = Open(endpoint.Path); if (!ValidHandle(handle)) continue;
                    try { result.Add(ReadState(handle, endpoint, "scan")); } finally { RazerDeviceHelper.CloseHandle(handle); }
                }
            }
            return result;
        }
        private static Endpoint Find(string id)
        {
            if (string.IsNullOrEmpty(id) || !id.StartsWith(Prefix, StringComparison.Ordinal)) return null;
            string path = id.Substring(Prefix.Length); if (!IsKnownDevicePath(path)) return null;
            foreach (Endpoint endpoint in Enumerate()) if (string.Equals(endpoint.Path, path, StringComparison.OrdinalIgnoreCase)) return endpoint;
            return null;
        }
        public static MouseBatteryInfo QueryDevice(string deviceId)
        { return QueryDevice(deviceId, "query"); }
        public static MouseBatteryInfo QueryDevice(string deviceId, string reason)
        {
            Endpoint endpoint = Find(deviceId); if (endpoint == null) return null;
            lock (GetLock(endpoint.Path))
            {
                IntPtr handle = Open(endpoint.Path); if (!ValidHandle(handle)) return null;
                try { return ReadState(handle, endpoint, reason); } finally { RazerDeviceHelper.CloseHandle(handle); }
            }
        }
        private static bool Set(string deviceId, int value, bool dpi, out MouseBatteryInfo confirmed)
        {
            confirmed = null;
            byte[] command = dpi ? MetapandaProtocol.BuildDpiStage(value) : MetapandaProtocol.BuildPollingRate(value);
            if (command == null) return false;
            Endpoint endpoint = Find(deviceId); if (endpoint == null) return false;
            lock (GetLock(endpoint.Path))
            {
                IntPtr handle = Open(endpoint.Path); if (!ValidHandle(handle)) return false;
                try
                {
                    DiagnosticLog.Default.Write("setting-request", "device=" + DiagnosticLog.DeviceKey(deviceId) + " kind=" + (dpi ? "stage" : "polling_hz") + " target=" + value);
                    MouseBatteryInfo before = ReadState(handle, endpoint, "setting-before");
                    if (!before.IsConnected || (dpi && (before.DpiStageCount == 0 || value > before.DpiStageCount)) || (!dpi && (before.PollingRate == 0 || Array.IndexOf(before.SupportedPollingRates, value) < 0))) return false;
                    if ((dpi ? before.DpiStage : before.PollingRate) == value) { confirmed = before; return true; }
                    if (Exchange(handle, command, endpoint.InputLength) == null)
                    { DiagnosticLog.Default.Write("setting-result", "device=" + DiagnosticLog.DeviceKey(deviceId) + " result=no-matching-ack"); return false; }
                    MouseBatteryInfo after = ReadState(handle, endpoint, "setting-after");
                    if (!after.IsConnected || (dpi ? after.DpiStage : after.PollingRate) != value)
                    { DiagnosticLog.Default.Write("setting-result", "device=" + DiagnosticLog.DeviceKey(deviceId) + " result=readback-mismatch"); return false; }
                    DiagnosticLog.Default.Write("setting-result", "device=" + DiagnosticLog.DeviceKey(deviceId) + " result=confirmed");
                    confirmed = after; return true;
                }
                finally { RazerDeviceHelper.CloseHandle(handle); }
            }
        }
        public static bool SetDpiStage(string deviceId, int oneBasedStage) { MouseBatteryInfo confirmed; return Set(deviceId, oneBasedStage, true, out confirmed); }
        public static bool SetDpiStage(string deviceId, int oneBasedStage, out MouseBatteryInfo confirmed) { return Set(deviceId, oneBasedStage, true, out confirmed); }
        public static bool SetPollingRate(string deviceId, int hz) { MouseBatteryInfo confirmed; return Set(deviceId, hz, false, out confirmed); }
        public static bool SetPollingRate(string deviceId, int hz, out MouseBatteryInfo confirmed) { return Set(deviceId, hz, false, out confirmed); }
    }
}
