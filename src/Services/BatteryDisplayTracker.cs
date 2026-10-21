// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Per-endpoint valid discharge floor. Unknown/sleep never becomes a low battery.
using System;
using System.Collections.Generic;
namespace RazerBatteryTray
{
    public sealed class BatteryDisplayTracker
    {
        public static readonly BatteryDisplayTracker Default = new BatteryDisplayTracker();
        private sealed class Entry { public double Value; public bool Charging; }
        private readonly Dictionary<string, Entry> readings = new Dictionary<string, Entry>(StringComparer.Ordinal);
        private readonly object gate = new object();
        public void Apply(MouseBatteryInfo state)
        {
            if (state == null || string.IsNullOrEmpty(state.DeviceId)) return;
            lock (gate)
            {
                Entry previous; readings.TryGetValue(state.DeviceId, out previous);
                bool valid = state.IsConnected && !state.IsSleeping && !state.IsBatteryReadingStale &&
                    state.BatteryPercent >= 0 && state.BatteryPercent <= 100 &&
                    state.ExactBatteryPercent >= 0 && state.ExactBatteryPercent <= 100;
                if (!valid)
                {
                    state.IsBatteryReadingStale = true;
                    state.BatteryPercent = previous == null ? -1 : (int)previous.Value;
                    state.ExactBatteryPercent = previous == null ? -1 : previous.Value;
                    if (previous != null) state.IsCharging = previous.Charging;
                    return;
                }
                if (previous == null) { previous = new Entry { Value = state.ExactBatteryPercent }; readings[state.DeviceId] = previous; }
                if (state.IsCharging || previous.Charging) previous.Value = state.ExactBatteryPercent;
                else previous.Value = Math.Min(previous.Value, state.ExactBatteryPercent);
                previous.Charging = state.IsCharging;
                state.ExactBatteryPercent = previous.Value; state.BatteryPercent = (int)previous.Value;
            }
        }
    }
    public static class BatteryAlertPolicy
    {
        public static bool CanAlert(MouseBatteryInfo state)
        {
            return state != null && state.IsConnected && !state.IsSleeping && !state.IsBatteryReadingStale &&
                !state.IsCharging && state.BatteryPercent >= 0 && state.BatteryPercent <= 20;
        }
    }
}
