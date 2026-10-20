// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Hardware-free endpoint rule persistence and apply/restore transitions.
// Preserve C# 5 / .NET 4 and UTF-8 BOM. Caller serializes Update and editor access.
using System;
using System.Collections.Generic;
using System.IO;
using System.Xml;

namespace RazerBatteryTray
{
    public sealed class ApplicationMouseProfileService
    {
        private sealed class EndpointState
        {
            public int DesktopStage, DesktopDpi, DesktopDpiY, DesktopRate, AppliedStage, AppliedRate;
        }
        private readonly string storagePath;
        private readonly Dictionary<string, EndpointState> states = new Dictionary<string, EndpointState>(StringComparer.Ordinal);
        public List<ApplicationMouseProfile> Profiles { get; private set; }
        public static string DefaultStoragePath
        {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "FerrisPulse", "application-profiles.xml"); }
        }
        public ApplicationMouseProfileService() : this(DefaultStoragePath) { }
        public ApplicationMouseProfileService(string path)
        {
            if (string.IsNullOrEmpty(path)) throw new ArgumentException("Storage path required", "path");
            storagePath = path;
            Profiles = new List<ApplicationMouseProfile>();
        }

        // Call Load only while the scheduler is paused; active restore snapshots remain intact.
        public void Load()
        {
            var loaded = new List<ApplicationMouseProfile>();
            if (!File.Exists(storagePath)) { Profiles = loaded; return; }
            try
            {
                var settings = new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null };
                var document = new XmlDocument { XmlResolver = null };
                using (var reader = XmlReader.Create(storagePath, settings)) document.Load(reader);
                if (document.DocumentElement == null || document.DocumentElement.Name != "profiles") { Profiles = loaded; return; }
                foreach (XmlNode node in document.DocumentElement.SelectNodes("profile"))
                {
                    int stage, rate, dpi = 0; bool enabled;
                    if (!int.TryParse(Attribute(node, "stage"), out stage) ||
                        !int.TryParse(Attribute(node, "rate"), out rate) || !bool.TryParse(Attribute(node, "enabled"), out enabled)) continue;
                    if (Attribute(node, "dpi").Length > 0 && !int.TryParse(Attribute(node, "dpi"), out dpi)) continue;
                    var profile = new ApplicationMouseProfile { DpiValue = dpi, ExecutablePath = Attribute(node, "exe"), DeviceId = Attribute(node, "device"), DpiStage = stage, PollingRate = rate, Enabled = enabled };
                    if (profile.IsValid()) loaded.Add(profile);
                }
            }
            catch (XmlException) { loaded.Clear(); }
            catch (IOException) { loaded.Clear(); }
            catch (UnauthorizedAccessException) { loaded.Clear(); }
            Profiles = loaded;
        }
        private static string Attribute(XmlNode node, string key)
        {
            return node.Attributes[key] == null ? "" : node.Attributes[key].Value;
        }

        // Atomic replacement preserves the previous rules when writing the new file fails.
        public void Save()
        {
            string directory = Path.GetDirectoryName(Path.GetFullPath(storagePath));
            Directory.CreateDirectory(directory);
            string temporary = Path.Combine(directory, Guid.NewGuid().ToString("N") + ".tmp");
            try
            {
                using (var writer = XmlWriter.Create(temporary, new XmlWriterSettings { Indent = true }))
                {
                    writer.WriteStartElement("profiles");
                    foreach (var profile in Profiles)
                    {
                        if (profile == null || !profile.IsValid()) continue;
                        writer.WriteStartElement("profile");
                        writer.WriteAttributeString("exe", profile.ExecutablePath);
                        writer.WriteAttributeString("device", profile.DeviceId);
                        writer.WriteAttributeString("stage", XmlConvert.ToString(profile.DpiStage));
                        if (profile.DpiValue > 0) writer.WriteAttributeString("dpi", XmlConvert.ToString(profile.DpiValue));
                        writer.WriteAttributeString("rate", XmlConvert.ToString(profile.PollingRate));
                        writer.WriteAttributeString("enabled", XmlConvert.ToString(profile.Enabled));
                        writer.WriteEndElement();
                    }
                    writer.WriteEndElement();
                }
                if (File.Exists(storagePath)) File.Replace(temporary, storagePath, null);
                else File.Move(temporary, storagePath);
            }
            finally { if (File.Exists(temporary)) File.Delete(temporary); }
        }

        // First enabled valid rule wins for a given executable + endpoint pair.
        public ApplicationMouseProfile Resolve(string executablePath, string deviceId)
        {
            if (!ApplicationMouseProfile.IsExecutablePath(executablePath)) return null;
            foreach (var profile in Profiles)
                if (profile != null && profile.Enabled && profile.IsValid() &&
                    string.Equals(profile.DeviceId, deviceId, StringComparison.Ordinal) &&
                    string.Equals(profile.ExecutablePath, executablePath, StringComparison.OrdinalIgnoreCase)) return profile;
            return null;
        }
        public bool HasActiveProfile(string deviceId) { return deviceId != null && states.ContainsKey(deviceId); }
        private static bool KnownStage(MouseBatteryInfo device, int stage)
        {
            return device.DpiStages != null && stage > 0 && stage <= device.DpiStages.Length && device.DpiStages[stage - 1] > 0;
        }

        private static int StageY(MouseBatteryInfo device, int stage)
        {
            return device.DpiStagesY != null && stage <= device.DpiStagesY.Length ? device.DpiStagesY[stage - 1] : device.DpiStages[stage - 1];
        }
        private static int RestoreStage(MouseBatteryInfo device, EndpointState state)
        {
            if (KnownStage(device, state.DesktopStage) && device.DpiStages[state.DesktopStage - 1] == state.DesktopDpi && StageY(device, state.DesktopStage) == state.DesktopDpiY) return state.DesktopStage;
            if (device.DpiStages != null)
                for (int i = 0; i < device.DpiStages.Length; i++)
                    if (device.DpiStages[i] == state.DesktopDpi && StageY(device, i + 1) == state.DesktopDpiY) return i + 1;
            return 0;
        }

        // Invoke from a single debounced foreground scheduler. Callback must verify BOTH settings
        // and return true only on complete success. Failures retry on the next scheduler tick.
        // Unknown foreground path is treated as a transient query failure: retain ownership.
        public void Update(string executablePath, List<MouseBatteryInfo> devices, Func<string, int, int, bool> apply)
        {
            UpdateCore(executablePath, devices, apply, false);
        }

        // Explicit shutdown/release path. Failed restores retain snapshots for a later retry.
        public void RestoreAll(List<MouseBatteryInfo> devices, Func<string, int, int, bool> apply)
        {
            UpdateCore(null, devices, apply, true);
        }

        private void UpdateCore(string executablePath, List<MouseBatteryInfo> devices, Func<string, int, int, bool> apply, bool restoreAll)
        {
            if (devices == null || apply == null) throw new ArgumentNullException(devices == null ? "devices" : "apply");
            var connected = new HashSet<string>(StringComparer.Ordinal);
            foreach (var device in devices)
            {
                if (device == null || !device.IsConnected || string.IsNullOrEmpty(device.DeviceId) ||
                    !device.DeviceId.StartsWith("Metapanda:", StringComparison.Ordinal) || !connected.Add(device.DeviceId)) continue;
                if (!restoreAll && !ApplicationMouseProfile.IsExecutablePath(executablePath)) continue;
                EndpointState state;
                states.TryGetValue(device.DeviceId, out state);
                var profile = restoreAll ? null : Resolve(executablePath, device.DeviceId);
                int targetStage = profile == null ? 0 : profile.ResolveDpiStage(device);
                if (profile != null && (targetStage == 0 || !ApplicationMouseProfile.SupportsPollingRate(device, profile.PollingRate))) profile = null;
                if (state == null)
                {
                    if (profile == null || !KnownStage(device, device.DpiStage) ||
                        !ApplicationMouseProfile.SupportsPollingRate(device, device.PollingRate)) continue;
                    state = new EndpointState { DesktopStage = device.DpiStage, DesktopDpi = device.DpiStages[device.DpiStage - 1], DesktopDpiY = StageY(device, device.DpiStage), DesktopRate = device.PollingRate };
                    states.Add(device.DeviceId, state);
                }
                int stage = profile == null ? RestoreStage(device, state) : targetStage;
                int rate = profile == null ? state.DesktopRate : profile.PollingRate;
                if (!KnownStage(device, stage) || !ApplicationMouseProfile.SupportsPollingRate(device, rate)) continue;
                bool success = state.AppliedStage == stage && state.AppliedRate == rate &&
                    device.DpiStage == stage && device.PollingRate == rate;
                if (!success)
                {
                    // A failed callback may have partially written: never keep an older success cache.
                    state.AppliedStage = 0; state.AppliedRate = 0;
                    try { success = apply(device.DeviceId, stage, rate); }
                    catch { success = false; }
                    if (success) { state.AppliedStage = stage; state.AppliedRate = rate; }
                }
                if (profile == null && success) states.Remove(device.DeviceId);
            }
            foreach (string id in new List<string>(states.Keys))
                if (!connected.Contains(id)) states.Remove(id);
        }
    }
}
