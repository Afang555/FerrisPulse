// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Foreground-only game reconciliation: one writer, stale request guards and verified retries.
using System;
using System.Diagnostics;
using System.Threading;
namespace RazerBatteryTray
{
    public partial class MainForm
    {
        private readonly GameFocusTracker metapandaGameFocus = new GameFocusTracker();
        private readonly MetapandaGameSession metapandaGameSession = new MetapandaGameSession();
        private int metapandaGameBusy, metapandaGameGeneration;
        private string metapandaGameRequestKey = "", metapandaGameLogKey = "";
        private DateTime metapandaGameLastLog;
        private sealed class MetapandaGameRequest
        {
            public int Generation, Stage, Rate;
            public string DeviceId;
            public bool Gaming, DpiEnabled, RateEnabled;
            public ForegroundWindowSnapshot Foreground;
        }
        private bool HasPendingMetapandaGameSession()
        {
            if (!Monitor.TryEnter(metapandaProfileGate)) return true;
            try { return metapandaGameSession.ActiveDeviceIds.Length > 0; }
            finally { Monitor.Exit(metapandaProfileGate); }
        }
        private void TickMetapandaGameMode(MouseBatteryInfo device)
        {
            if (metapandaProfilesStopping || PauseBackgroundRefresh || device == null) return;
            ForegroundWindowSnapshot foreground = ForegroundWindowSnapshot.Capture();
            bool game = foreground.Known && ContainsGameProcess(foreground.ProcessName);
            if (foreground.Known && !game && fallbackFullscreenEnabled)
            { string ignored; game = GameDetector.IsGameRunning(out ignored) && foreground.IsCurrent(); }
            metapandaGameFocus.Observe(foreground.Key, foreground.Known, game);
            string decision = "hwnd=" + foreground.Window.ToInt64().ToString("x") + " pid=" + foreground.ProcessId +
                " process=" + foreground.ProcessName + " known=" + foreground.Known + " game=" + game +
                " stable=" + metapandaGameFocus.Ready + " active=" + metapandaGameFocus.Active +
                " target_stage=" + gameDpiStage + " target_hz=" + gamePollingRate;
            if (decision != metapandaGameLogKey || (DateTime.UtcNow - metapandaGameLastLog).TotalSeconds >= 5)
            { DiagnosticLog.Default.Write("game-focus", decision); metapandaGameLogKey = decision; metapandaGameLastLog = DateTime.UtcNow; }
            if (!metapandaGameFocus.Ready) return; // Unknown or transient focus never schedules an exit/restore.
            bool desiredGame = metapandaGameFocus.Active && (autoGameDpiEnabled || autoGameRateEnabled);
            isGamingActive = desiredGame;
            string requestKey = device.DeviceId + "|" + foreground.Key + "|" + desiredGame + "|" + autoGameDpiEnabled + "|" + autoGameRateEnabled + "|" + gameDpiStage + "|" + gamePollingRate;
            if (requestKey != metapandaGameRequestKey)
            { metapandaGameRequestKey = requestKey; Interlocked.Increment(ref metapandaGameGeneration); }
            if (HasActiveMetapandaApplicationProfile(device.DeviceId))
            { DiagnosticLog.Default.Write("game-reconcile", "result=application-profile-priority device=" + DiagnosticLog.DeviceKey(device.DeviceId)); return; }
            if (!desiredGame && !HasPendingMetapandaGameSession()) return;
            if (Interlocked.CompareExchange(ref metapandaGameBusy, 1, 0) != 0) return;
            var request = new MetapandaGameRequest { Generation = metapandaGameGeneration, DeviceId = device.DeviceId,
                Foreground = foreground, Gaming = desiredGame, DpiEnabled = autoGameDpiEnabled, RateEnabled = autoGameRateEnabled,
                Stage = gameDpiStage, Rate = gamePollingRate };
            ThreadPool.QueueUserWorkItem(delegate { ReconcileMetapandaGameMode(request); });
        }
        private bool IsCurrentMetapandaGameRequest(MetapandaGameRequest request)
        {
            return !metapandaProfilesStopping && !IsDisposed && selectedDevice != null && selectedDevice.DeviceId == request.DeviceId &&
                Interlocked.CompareExchange(ref metapandaGameGeneration, 0, 0) == request.Generation && request.Foreground.IsCurrent();
        }
        private void ReconcileMetapandaGameMode(MetapandaGameRequest request)
        {
            Stopwatch elapsed = Stopwatch.StartNew();
            try
            {
                lock (metapandaProfileGate)
                {
                    Func<bool> current = delegate { return IsCurrentMetapandaGameRequest(request) &&
                        (metapandaProfiles == null || !metapandaProfiles.HasActiveProfile(request.DeviceId)); };
                    if (!current()) { DiagnosticLog.Default.Write("game-reconcile", "result=stale-before-read"); return; }
                    MouseBatteryInfo actual = MetapandaDeviceHelper.QueryDevice(request.DeviceId, "game-observe");
                    if (actual == null) { DiagnosticLog.Default.Write("game-reconcile", "result=endpoint-unavailable"); return; }
                    MouseBatteryInfo confirmed = actual;
                    bool success = metapandaGameSession.Update(actual, request.Gaming, request.DpiEnabled, request.RateEnabled,
                        request.Stage, request.Rate, current, delegate(string id, int stage, int rate) {
                            if (!current() || !SetUnownedMetapandaDpiStage(id, stage, out confirmed)) return false;
                            if (!current() || !SetUnownedMetapandaPollingRate(id, rate, out confirmed)) return false;
                            return current() && confirmed != null && confirmed.IsConnected && confirmed.DpiStage == stage && confirmed.PollingRate == rate;
                        });
                    DiagnosticLog.Default.Write("game-reconcile", "device=" + DiagnosticLog.DeviceKey(request.DeviceId) + " generation=" + request.Generation +
                        " desired=" + (request.Gaming ? "game" : "desktop") + " result=" + (success ? "confirmed" : current() ? "retry-needed" : "cancelled-stale") +
                        " actual_stage=" + (confirmed == null ? 0 : confirmed.DpiStage) + " actual_dpi=" + (confirmed == null ? 0 : confirmed.Dpi) +
                        " actual_hz=" + (confirmed == null ? 0 : confirmed.PollingRate) + " elapsed_ms=" + elapsed.ElapsedMilliseconds);
                    if (!success || confirmed == null) return;
                    MouseBatteryInfo publish = confirmed;
                    try { BeginInvoke(new Action(delegate {
                        if (!IsCurrentMetapandaGameRequest(request) || HasActiveMetapandaApplicationProfile(request.DeviceId)) return;
                        PublishMetapandaObservedState(publish); UpdatePollingRateDisplayStates();
                    })); } catch (InvalidOperationException) { }
                }
            }
            catch (Exception ex) { DiagnosticLog.Default.Write("game-error", ex.GetType().Name + " " + ex.Message); }
            finally { Interlocked.Exchange(ref metapandaGameBusy, 0); }
        }
        private void RestoreMetapandaGameSessions()
        {
            foreach (string id in metapandaGameSession.ActiveDeviceIds)
            {
                MouseBatteryInfo actual = MetapandaDeviceHelper.QueryDevice(id, "game-shutdown");
                bool success = metapandaGameSession.Update(actual, false, false, false, 0, 0,
                    delegate { return true; }, ApplyMetapandaApplicationSettings);
                DiagnosticLog.Default.Write("game-shutdown", "device=" + DiagnosticLog.DeviceKey(id) + " restored=" + success);
            }
        }
    }
}
