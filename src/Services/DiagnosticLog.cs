// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Local bounded diagnostic events and repeatable battery samples. C# 5 / .NET 4.
// No upload, raw HID identity or foreground executable paths are recorded.
using System;
using System.Globalization;
using System.IO;
using System.Security.Cryptography;
using System.Text;
namespace RazerBatteryTray
{
    public sealed class DiagnosticLog
    {
        public static readonly DiagnosticLog Default = new DiagnosticLog(
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "FerrisPulse", "logs"), 1048576, 5);
        private readonly object gate = new object();
        private readonly string directory;
        private readonly int maxBytes, maxFiles;
        private static readonly Encoding Utf8 = new UTF8Encoding(false);
        private const string BatteryHeader = "utc,device,reason,connected,device_level,voltage_mv,charging,estimate_percent,display_percent,dpi_x,dpi_y,stage,stage_count,polling_hz,elapsed_ms,report_hex\r\n";
        public string DirectoryPath { get { return directory; } }
        public DiagnosticLog(string directory, int maxBytes, int maxFiles)
        { this.directory = directory; this.maxBytes = Math.Max(1024, maxBytes); this.maxFiles = Math.Max(1, Math.Min(20, maxFiles)); }
        public bool Write(string kind, string detail)
        { return Append("diagnostic.log", "", DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture) + " " + Clean(kind) + " " + Clean(detail) + "\r\n"); }
        public bool RecordBattery(MouseBatteryInfo state, byte[] report, string reason, long elapsed)
        {
            if (state == null) return false;
            bool valid = MetapandaProtocol.IsValid(report) && report[1] == 4 && report[5] == 2;
            int rawPercent; bool rawCharging; double rawEstimate;
            if (!MetapandaProtocol.DecodeBattery(report, out rawPercent, out rawCharging, out rawEstimate)) rawEstimate = -1;
            string[] cells = new string[] { DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture), DeviceKey(state.DeviceId), Clean(reason),
                state.IsConnected ? "1" : "0", valid ? report[6].ToString(CultureInfo.InvariantCulture) : "",
                valid ? (report[8] * 256 + report[9]).ToString(CultureInfo.InvariantCulture) : "", valid ? report[7].ToString(CultureInfo.InvariantCulture) : "",
                rawEstimate.ToString("0.###", CultureInfo.InvariantCulture), state.BatteryPercent.ToString(CultureInfo.InvariantCulture),
                state.Dpi.ToString(CultureInfo.InvariantCulture), state.DpiY.ToString(CultureInfo.InvariantCulture), state.DpiStage.ToString(CultureInfo.InvariantCulture),
                state.DpiStageCount.ToString(CultureInfo.InvariantCulture), state.PollingRate.ToString(CultureInfo.InvariantCulture),
                elapsed.ToString(CultureInfo.InvariantCulture), report == null ? "" : BitConverter.ToString(report).Replace("-", "").ToLowerInvariant() };
            for (int i = 0; i < cells.Length; i++) cells[i] = "\"" + cells[i].Replace("\"", "\"\"") + "\"";
            return Append("battery.csv", BatteryHeader, string.Join(",", cells) + "\r\n");
        }
        public static string DeviceKey(string identity)
        {
            using (SHA256 hash = SHA256.Create())
                return BitConverter.ToString(hash.ComputeHash(Utf8.GetBytes(identity ?? "")), 0, 6).Replace("-", "").ToLowerInvariant();
        }
        private static string Clean(string value) { return (value ?? "").Replace('\r', ' ').Replace('\n', ' '); }
        private bool Append(string name, string header, string line)
        {
            try
            {
                lock (gate)
                {
                    Directory.CreateDirectory(directory);
                    string path = Path.Combine(directory, name);
                    // Bound an exceptional stack trace or caller message as well as file growth.
                    if (Utf8.GetByteCount(line) + Utf8.GetByteCount(header) > maxBytes)
                        line = line.Substring(0, Math.Min(line.Length, (maxBytes - Utf8.GetByteCount(header)) / 4)) + " [truncated]\r\n";
                    if (File.Exists(path) && new FileInfo(path).Length + Utf8.GetByteCount(line) > maxBytes)
                    {
                        for (int n = maxFiles - 1; n >= 1; n--)
                        {
                            string target = path + "." + n.ToString(CultureInfo.InvariantCulture);
                            string source = n == 1 ? path : path + "." + (n - 1).ToString(CultureInfo.InvariantCulture);
                            if (File.Exists(target)) File.Delete(target);
                            if (File.Exists(source)) File.Move(source, target);
                        }
                        if (maxFiles == 1) File.Delete(path);
                    }
                    if (!File.Exists(path) && header.Length > 0) File.AppendAllText(path, header, Utf8);
                    File.AppendAllText(path, line, Utf8);
                    return true;
                }
            }
            catch { return false; } // Diagnostics must never prevent hardware feedback or startup.
        }
    }
}
