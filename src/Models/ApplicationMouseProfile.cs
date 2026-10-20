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
        public int PollingRate { get; set; }
        public bool Enabled { get; set; }

        public ApplicationMouseProfile() { Enabled = true; }

        public bool IsValid()
        {
            return IsExecutablePath(ExecutablePath) && !string.IsNullOrEmpty(DeviceId) &&
                DeviceId.StartsWith("Metapanda:", StringComparison.Ordinal) && DeviceId.Length > 10 &&
                DpiStage > 0 && (PollingRate == 125 || PollingRate == 1000);
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
