// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Application rule contract. Preserve C# 5 / .NET 4 and UTF-8 BOM.
using System;
using System.IO;

namespace RazerBatteryTray
{
    public sealed class ApplicationMouseProfile
    {
        public string ExecutablePath { get; set; }
        public string DeviceId { get; set; }
        public int DpiStage { get; set; }
        public int DpiValue { get; set; }
        public int PollingRate { get; set; }
        public bool Enabled { get; set; }

        public ApplicationMouseProfile() { Enabled = true; }

        public bool IsValid()
        {
            return IsExecutablePath(ExecutablePath) && !string.IsNullOrEmpty(DeviceId) &&
                DeviceId.StartsWith("Metapanda:", StringComparison.Ordinal) && DeviceId.Length > 10 &&
                ((DpiValue == 0 && DpiStage > 0 && DpiStage <= 8) || (DpiStage == 0 && DpiValue > 0 && DpiValue <= 26000)) && IsKnownPollingRate(PollingRate);
        }

        public static bool IsKnownPollingRate(int hz)
        {
            return hz == 125 || hz == 250 || hz == 500 || hz == 1000 || hz == 2000 || hz == 4000;
        }
        public static bool SupportsPollingRate(MouseBatteryInfo device, int hz)
        {
            if (device == null || !IsKnownPollingRate(hz)) return false;
            if (device.SupportedPollingRates == null || device.SupportedPollingRates.Length == 0) return hz == 125 || hz == 1000;
            return Array.IndexOf(device.SupportedPollingRates, hz) >= 0;
        }
        public int ResolveDpiStage(MouseBatteryInfo device)
        {
            if (device == null || device.DpiStages == null) return 0;
            if (DpiValue == 0)
                return DpiStage > 0 && DpiStage <= device.DpiStages.Length && device.DpiStages[DpiStage - 1] > 0 ? DpiStage : 0;
            int first = 0;
            for (int i = 0; i < device.DpiStages.Length; i++)
            {
                if (device.DpiStages[i] != DpiValue || (device.DpiStagesY != null &&
                    (i >= device.DpiStagesY.Length || device.DpiStagesY[i] != DpiValue))) continue;
                if (i + 1 == device.DpiStage) return i + 1;
                if (first == 0) first = i + 1;
            }
            return first;
        }

        public static bool IsExecutablePath(string value)
        {
            if (string.IsNullOrEmpty(value) || value != value.Trim() ||
                !value.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) return false;
            try
            {
                // Reject drive-relative paths (C:game.exe), wildcards and filename-only rules.
                if (!Path.IsPathRooted(value) || value.IndexOfAny(Path.GetInvalidPathChars()) >= 0 ||
                    value.IndexOf('*') >= 0 || value.IndexOf('?') >= 0) return false;
                return (value.Length > 3 && char.IsLetter(value[0]) && value[1] == ':' &&
                    (value[2] == '\\' || value[2] == '/')) || value.StartsWith("\\\\", StringComparison.Ordinal);
            }
            catch (ArgumentException) { return false; }
        }
    }
}
