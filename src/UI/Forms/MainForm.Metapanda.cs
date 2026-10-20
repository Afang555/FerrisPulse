// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Metapanda application profile orchestration. C# 5 / .NET Framework 4.0.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;
using System.Windows.Forms;
namespace RazerBatteryTray
{
    public partial class MainForm
    {
        private ApplicationMouseProfileService metapandaProfiles;
        private System.Windows.Forms.Timer metapandaProfileTimer;
        private readonly object metapandaProfileGate = new object();
        private int metapandaProfileBusy;
        private volatile bool metapandaProfilesStopping;
        private string metapandaForegroundCandidate = "";
        private DateTime metapandaForegroundSince;
        private void StartMetapandaApplicationProfiles()
        {
            metapandaProfiles = new ApplicationMouseProfileService();
            try { metapandaProfiles.Load(); }
            catch (Exception ex) { MessageBox.Show(this, "应用规则未能读取：" + ex.Message, "玄熊猫应用规则"); }
            metapandaProfileTimer = new System.Windows.Forms.Timer();
            metapandaProfileTimer.Interval = 500;
            metapandaProfileTimer.Tick += (s, e) => TickMetapandaApplicationProfiles();
            metapandaProfileTimer.Start();
        }
        private void AddMetapandaApplicationProfilesMenu()
        {
            ToolStripMenuItem item = new ToolStripMenuItem("玄熊猫 · 按应用设置…");
            item.Click += (s, e) => OpenMetapandaApplicationProfiles();
            contextMenu.Items.Insert(0, item);
        }
        private bool HasActiveMetapandaApplicationProfile(string deviceId)
        {
            // UI/game timer never waits for HID traffic on the scheduler thread.
            if (!Monitor.TryEnter(metapandaProfileGate)) return true;
            try { return metapandaProfiles != null && metapandaProfiles.HasActiveProfile(deviceId); }
            finally { Monitor.Exit(metapandaProfileGate); }
        }
        private bool SetUnownedMetapandaDpiStage(string deviceId, int stage)
        {
            lock (metapandaProfileGate)
            {
                if (metapandaProfilesStopping || (metapandaProfiles != null && metapandaProfiles.HasActiveProfile(deviceId))) return false;
                return MetapandaDeviceHelper.SetDpiStage(deviceId, stage);
            }
        }
        private bool SetUnownedMetapandaPollingRate(string deviceId, int hz)
        {
            lock (metapandaProfileGate)
            {
                if (metapandaProfilesStopping || (metapandaProfiles != null && metapandaProfiles.HasActiveProfile(deviceId))) return false;
                return MetapandaDeviceHelper.SetPollingRate(deviceId, hz);
            }
        }
        private void BeginMetapandaGameTransition(MouseBatteryInfo curDev)
        {
            ThreadPool.QueueUserWorkItem(_ =>
            {
                CaptureMetapandaDesktopSettings(curDev);
                try
                {
                    BeginInvoke(new Action(() =>
                    {
                        if (!isGamingActive || selectedDevice == null || selectedDevice.DeviceId != curDev.DeviceId ||
                            HasActiveMetapandaApplicationProfile(curDev.DeviceId)) return;
                        if (autoGameRateEnabled) ApplyGamePollingRate();
                        if (autoGameDpiEnabled) ApplyGameDpiStage();
                    }));
                }
                catch (InvalidOperationException) { }
            });
        }
        private void CaptureMetapandaDesktopSettings(MouseBatteryInfo device)
        {
            lock (metapandaProfileGate)
            {
                if (metapandaProfiles != null && metapandaProfiles.HasActiveProfile(device.DeviceId)) return;
                MouseBatteryInfo actual = MetapandaDeviceHelper.QueryDevice(device.DeviceId);
                if (actual == null || !actual.IsConnected) return;
                if (actual.DpiStage > 0) desktopDpiStage = actual.DpiStage;
                if (actual.PollingRate == 125 || actual.PollingRate == 1000) desktopPollingRate = actual.PollingRate;
            }
        }
        private void OpenMetapandaApplicationProfiles()
        {
            if (metapandaProfileBusy != 0) return;
            metapandaProfileTimer.Stop();
            try
            {
                lock (metapandaProfileGate)
                using (ApplicationMouseProfilesDialog dialog = new ApplicationMouseProfilesDialog(
                    activeDevices == null ? new List<MouseBatteryInfo>() : new List<MouseBatteryInfo>(activeDevices), metapandaProfiles))
                    dialog.ShowDialog(this);
            }
            finally { metapandaProfileTimer.Start(); }
        }
        private static string MetapandaForegroundExecutable()
        {
            IntPtr hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return "";
            uint processId; GetWindowThreadProcessId(hwnd, out processId);
            try
            {
                using (Process process = Process.GetProcessById((int)processId))
                    return process.MainModule.FileName;
            }
            catch { return ""; }
        }
        private void TickMetapandaApplicationProfiles()
        {
            if (metapandaProfilesStopping || PauseBackgroundRefresh) return;
            string executable = MetapandaForegroundExecutable();
            // An inaccessible process is not proof that the matching application exited.
            if (string.IsNullOrEmpty(executable)) return;
            if (!string.Equals(executable, metapandaForegroundCandidate, StringComparison.OrdinalIgnoreCase))
            { metapandaForegroundCandidate = executable; metapandaForegroundSince = DateTime.UtcNow; return; }
            if ((DateTime.UtcNow - metapandaForegroundSince).TotalMilliseconds < 750) return;
            if (Interlocked.CompareExchange(ref metapandaProfileBusy, 1, 0) != 0) return;
            List<MouseBatteryInfo> devices = activeDevices == null ? new List<MouseBatteryInfo>() : new List<MouseBatteryInfo>(activeDevices);
            ThreadPool.QueueUserWorkItem(_ =>
            {
                try
                {
                    lock (metapandaProfileGate)
                    {
                        if (metapandaProfilesStopping) return;
                        if (!string.Equals(executable, MetapandaForegroundExecutable(), StringComparison.OrdinalIgnoreCase)) return;
                        if (metapandaProfiles.Profiles.Count == 0 && !AnyMetapandaProfileActive(devices)) return;
                        // Snapshot the real state immediately before acquiring profile ownership.
                        List<MouseBatteryInfo> fresh = new List<MouseBatteryInfo>();
                        foreach (MouseBatteryInfo device in devices)
                        {
                            if (!MetapandaDeviceHelper.IsMetapanda(device)) continue;
                            MouseBatteryInfo actual = MetapandaDeviceHelper.QueryDevice(device.DeviceId);
                            if (actual != null) fresh.Add(actual);
                        }
                        metapandaProfiles.Update(executable, fresh, ApplyMetapandaApplicationSettings);
                    }
                }
                catch (Exception ex) { Trace.WriteLine("Metapanda profile: " + ex.Message); }
                finally { Interlocked.Exchange(ref metapandaProfileBusy, 0); }
            });
        }
        private bool AnyMetapandaProfileActive(List<MouseBatteryInfo> devices)
        {
            foreach (MouseBatteryInfo device in devices)
                if (metapandaProfiles.HasActiveProfile(device.DeviceId)) return true;
            return false;
        }
        private bool ApplyMetapandaApplicationSettings(string deviceId, int stage, int hz)
        {
            MouseBatteryInfo before = MetapandaDeviceHelper.QueryDevice(deviceId);
            if (before == null || !before.IsConnected || before.DpiStage < 1 || before.PollingRate < 1) return false;
            if (!MetapandaDeviceHelper.SetDpiStage(deviceId, stage)) return false;
            if (!MetapandaDeviceHelper.SetPollingRate(deviceId, hz))
            {
                MetapandaDeviceHelper.SetDpiStage(deviceId, before.DpiStage);
                MetapandaDeviceHelper.SetPollingRate(deviceId, before.PollingRate);
                return false;
            }
            MouseBatteryInfo after = MetapandaDeviceHelper.QueryDevice(deviceId);
            if (after == null || after.DpiStage != stage || after.PollingRate != hz) return false;
            try
            {
                BeginInvoke(new Action(() =>
                {
                    if (activeDevices != null)
                        for (int i = 0; i < activeDevices.Count; i++)
                            if (activeDevices[i].DeviceId == deviceId) activeDevices[i] = after;
                    if (selectedDevice != null && selectedDevice.DeviceId == deviceId)
                    { selectedDevice = after; UpdateUI(after, false); }
                }));
            }
            catch (InvalidOperationException) { }
            return true;
        }
        private void StopMetapandaApplicationProfiles()
        {
            metapandaProfilesStopping = true;
            if (metapandaProfileTimer != null) { metapandaProfileTimer.Stop(); metapandaProfileTimer.Dispose(); }
            // Restore known desktop snapshots before this application's scheduler exits.
            lock (metapandaProfileGate)
            {
                if (metapandaProfiles != null)
                    metapandaProfiles.RestoreAll(activeDevices == null ? new List<MouseBatteryInfo>() : new List<MouseBatteryInfo>(activeDevices), ApplyMetapandaApplicationSettings);
            }
        }
    }
}
