// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Publish verified HID state on the UI thread; older full scans must not undo it.
// Preserve C# 5 / .NET Framework 4.0 and UTF-8 BOM.
using System;
using System.Collections.Generic;
using System.Threading;
namespace RazerBatteryTray
{
    public partial class MainForm
    {
        private readonly Dictionary<string, MouseBatteryInfo> metapandaConfirmedStates = new Dictionary<string, MouseBatteryInfo>(StringComparer.Ordinal);
        private readonly Dictionary<string, Action> metapandaPendingFeedback = new Dictionary<string, Action>(StringComparer.Ordinal);
        private System.Windows.Forms.Timer metapandaFeedbackTimer;
        private void QueueMetapandaManualFeedback(string deviceId, Action feedback)
        {
            if (IsDisposed || metapandaProfilesStopping || feedback == null) return;
            metapandaPendingFeedback[deviceId] = feedback;
            if (TryPublishMetapandaManualFeedback()) return;
            if (metapandaFeedbackTimer == null)
            {
                metapandaFeedbackTimer = new System.Windows.Forms.Timer();
                metapandaFeedbackTimer.Interval = 50;
                metapandaFeedbackTimer.Tick += delegate { TryPublishMetapandaManualFeedback(); };
                Disposed += delegate { metapandaFeedbackTimer.Dispose(); metapandaPendingFeedback.Clear(); };
            }
            metapandaFeedbackTimer.Start();
        }
        private bool TryPublishMetapandaManualFeedback()
        {
            if (!Monitor.TryEnter(metapandaProfileGate)) return false;
            try
            {
                foreach (var item in new List<KeyValuePair<string, Action>>(metapandaPendingFeedback))
                {
                    metapandaPendingFeedback.Remove(item.Key);
                    if (!metapandaProfilesStopping && (metapandaProfiles == null || !metapandaProfiles.HasActiveProfile(item.Key))) item.Value();
                }
            }
            finally { Monitor.Exit(metapandaProfileGate); }
            if (metapandaFeedbackTimer != null) metapandaFeedbackTimer.Stop();
            return true;
        }
        private bool PublishMetapandaConfirmedState(MouseBatteryInfo state)
        {
            if (!MetapandaDeviceHelper.IsMetapanda(state) || !state.IsConnected) return false;
            MouseBatteryInfo previous;
            if (metapandaConfirmedStates.TryGetValue(state.DeviceId, out previous) && previous.LastUpdated > state.LastUpdated) return false;
            previous = activeDevices == null ? null : activeDevices.Find(d => d != null && d.DeviceId == state.DeviceId);
            if (previous == null && selectedDevice != null && selectedDevice.DeviceId == state.DeviceId) previous = selectedDevice;
            if (previous != null && previous.LastUpdated > state.LastUpdated) return false;
            if (previous != null)
            {
                state.CustomName = previous.CustomName; state.IsPrimary = previous.IsPrimary;
                state.PriorityIndex = previous.PriorityIndex; state.IsCustom = previous.IsCustom;
            }
            metapandaConfirmedStates[state.DeviceId] = state;
            if (activeDevices != null)
                for (int i = 0; i < activeDevices.Count; i++)
                    if (activeDevices[i] != null && activeDevices[i].DeviceId == state.DeviceId) activeDevices[i] = state;
            if (lastInfo != null && lastInfo.DeviceId == state.DeviceId) lastInfo = state;
            if (selectedDevice != null && selectedDevice.DeviceId == state.DeviceId)
            {
                selectedDevice = state;
                UpdateUI(state, false); UpdateDeviceTabsUI(); UpdatePrimaryPinButton(state);
            }
            UpdateStatusDisplay();
            DiagnosticLog.Default.Write("ui-confirmed", "device=" + DiagnosticLog.DeviceKey(state.DeviceId) + " battery=" + state.BatteryPercent + " dpi=" + state.Dpi + " stage=" + state.DpiStage + " polling_hz=" + state.PollingRate);
            return true;
        }
        private void PublishMetapandaManualDpiState(MouseBatteryInfo state)
        {
            if (PublishMetapandaConfirmedState(state))
                OnDpiChanged("Metapanda", state.Dpi, state.DpiStage, state.DpiStageCount, state.DeviceId);
        }
        private void PublishMetapandaObservedState(MouseBatteryInfo state)
        {
            if (state == null || selectedDevice == null || state.DeviceId != selectedDevice.DeviceId) return;
            int oldStage = selectedDevice.DpiStage, oldDpi = selectedDevice.Dpi;
            if (PublishMetapandaConfirmedState(state) && oldStage > 0 && state.DpiStage > 0 && state.Dpi > 0 &&
                (oldStage != state.DpiStage || oldDpi != state.Dpi))
                OnDpiChanged("Metapanda", state.Dpi, state.DpiStage, state.DpiStageCount, state.DeviceId);
        }
        private void ReconcileMetapandaSnapshots(List<MouseBatteryInfo> devices)
        {
            if (devices == null) return;
            for (int i = 0; i < devices.Count; i++)
            {
                var observed = devices[i]; MouseBatteryInfo confirmed;
                if (observed == null || !MetapandaDeviceHelper.IsMetapanda(observed) ||
                    !metapandaConfirmedStates.TryGetValue(observed.DeviceId, out confirmed)) continue;
                if (observed.LastUpdated < confirmed.LastUpdated) devices[i] = confirmed;
                else metapandaConfirmedStates.Remove(observed.DeviceId);
            }
        }
    }
}
