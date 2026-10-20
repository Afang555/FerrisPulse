// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Target-only activity refresh, independent of the slower multi-brand full scan.
using System;
using System.Diagnostics;
using System.Threading;
namespace RazerBatteryTray
{
    public partial class MainForm
    {
        private System.Windows.Forms.Timer metapandaStateTimer;
        private readonly ActivityRefreshSchedule metapandaRefreshSchedule = new ActivityRefreshSchedule();
        private readonly Stopwatch metapandaRefreshClock = Stopwatch.StartNew();
        private long metapandaLastMouseInput = -10000;
        private void StartMetapandaStateRefresh()
        {
            metapandaStateTimer = new System.Windows.Forms.Timer();
            metapandaStateTimer.Interval = 200;
            metapandaStateTimer.Tick += delegate { TickMetapandaStateRefresh(); };
            metapandaStateTimer.Start();
            Disposed += delegate { metapandaStateTimer.Dispose(); };
        }
        private void TickMetapandaStateRefresh()
        {
            if (PauseBackgroundRefresh || metapandaProfilesStopping || IsDisposed) return;
            MouseBatteryInfo target = selectedDevice;
            if (!MetapandaDeviceHelper.IsMetapanda(target)) return;
            long now = metapandaRefreshClock.ElapsedMilliseconds;
            bool active = now - metapandaLastMouseInput < 1500;
            if (!metapandaRefreshSchedule.TryBegin(now, Visible && WindowState != System.Windows.Forms.FormWindowState.Minimized, active)) return;
            string reason = active ? "mouse-activity" : Visible ? "visible-poll" : "idle-poll";
            ThreadPool.QueueUserWorkItem(delegate {
                MouseBatteryInfo observed = null;
                try { observed = MetapandaDeviceHelper.QueryDevice(target.DeviceId, reason); }
                catch (Exception ex) { DiagnosticLog.Default.Write("refresh-error", ex.GetType().Name + " " + ex.Message); }
                try { BeginInvoke(new Action(delegate {
                    metapandaRefreshSchedule.Complete();
                    if (PauseBackgroundRefresh || metapandaProfilesStopping || IsDisposed || observed == null ||
                        selectedDevice == null || selectedDevice.DeviceId != target.DeviceId) return;
                    // Timestamp reconciliation rejects older scans and late settings callbacks.
                    if (observed.IsConnected) PublishMetapandaObservedState(observed);
                    // A transient online-query miss is logged; the normal full scan owns removal/offline UI.
                })); } catch (InvalidOperationException) { metapandaRefreshSchedule.Complete(); }
            });
        }
    }
}
