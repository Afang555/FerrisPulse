// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Serialized desired-vs-observed game reconciliation. Caller holds the shared profile gate.
using System;
using System.Collections.Generic;
namespace RazerBatteryTray
{
    public sealed class GameFocusTracker
    {
        private string candidate = "";
        private int count;
        public bool Active { get; private set; }
        public bool Ready { get; private set; }
        public void Observe(string key, bool known, bool gaming)
        {
            Ready = false;
            if (!known) { count = 0; return; }
            string next = (gaming ? "game:" : "desktop:") + key;
            if (!string.Equals(candidate, next, StringComparison.Ordinal)) { candidate = next; count = 1; return; }
            count = Math.Min(2, count + 1);
            Ready = count >= 2;
            if (Ready) Active = gaming;
        }
    }
    public sealed class MetapandaGameSession
    {
        private sealed class Baseline { public int Stage, X, Y, Rate; public bool DpiControlled, RateControlled; }
        private readonly Dictionary<string, Baseline> states = new Dictionary<string, Baseline>(StringComparer.Ordinal);
        public bool HasSession(string id) { return id != null && states.ContainsKey(id); }
        public string[] ActiveDeviceIds { get { return new List<string>(states.Keys).ToArray(); } }
        private static bool KnownStage(MouseBatteryInfo device, int stage)
        { return device.DpiStages != null && stage >= 1 && stage <= device.DpiStages.Length && device.DpiStages[stage - 1] > 0; }
        private static int StageY(MouseBatteryInfo device, int stage)
        { return device.DpiStagesY != null && stage <= device.DpiStagesY.Length ? device.DpiStagesY[stage - 1] : device.DpiStages[stage - 1]; }
        private static int RestoreStage(MouseBatteryInfo device, Baseline baseline)
        {
            if (KnownStage(device, baseline.Stage) && device.DpiStages[baseline.Stage - 1] == baseline.X && StageY(device, baseline.Stage) == baseline.Y) return baseline.Stage;
            if (device.DpiStages != null)
                for (int i = 1; i <= device.DpiStages.Length; i++)
                    if (device.DpiStages[i - 1] == baseline.X && StageY(device, i) == baseline.Y) return i;
            return 0;
        }
        public bool Update(MouseBatteryInfo device, bool gaming, bool dpiEnabled, bool rateEnabled, int gameStage, int gameRate,
            Func<bool> current, Func<string, int, int, bool> apply)
        {
            if (device == null || !device.IsConnected || string.IsNullOrEmpty(device.DeviceId) || current == null || apply == null ||
                !KnownStage(device, device.DpiStage) || !ApplicationMouseProfile.SupportsPollingRate(device, device.PollingRate) || !current()) return false;
            Baseline baseline;
            if (!states.TryGetValue(device.DeviceId, out baseline))
            {
                if (!gaming || (!dpiEnabled && !rateEnabled)) return true;
                baseline = new Baseline { Stage = device.DpiStage, X = device.DpiStages[device.DpiStage - 1], Y = StageY(device, device.DpiStage), Rate = device.PollingRate };
                states.Add(device.DeviceId, baseline);
            }
            if (gaming) { baseline.DpiControlled |= dpiEnabled; baseline.RateControlled |= rateEnabled; }
            int stage = gaming && dpiEnabled ? gameStage : baseline.DpiControlled ? RestoreStage(device, baseline) : device.DpiStage;
            int rate = gaming && rateEnabled ? gameRate : baseline.RateControlled ? baseline.Rate : device.PollingRate;
            if (!KnownStage(device, stage) || !ApplicationMouseProfile.SupportsPollingRate(device, rate)) return false;
            if ((device.DpiStage != stage || device.PollingRate != rate) && (!current() || !apply(device.DeviceId, stage, rate))) return false;
            if (!current()) return false; // A write finishing after a focus change must retain its baseline for correction.
            if (!gaming || !dpiEnabled) baseline.DpiControlled = false;
            if (!gaming || !rateEnabled) baseline.RateControlled = false;
            if (!baseline.DpiControlled && !baseline.RateControlled) states.Remove(device.DeviceId);
            return true;
        }
    }
}
