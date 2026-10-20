// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Editable per-application Metapanda rules. Hardware state is a read-only snapshot here.
// Preserve C# 5 / .NET 4 and UTF-8 BOM; caller pauses the scheduler while editing.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace RazerBatteryTray
{
    public sealed class ApplicationMouseProfilesDialog : Form
    {
        private readonly ApplicationMouseProfileService service;
        private readonly DataGridView grid = new DataGridView();
        private readonly List<MouseBatteryInfo> devices;
        private sealed class RateChoice
        {
            public int Value { get; set; }
            public string Label { get { return Value.ToString() + " Hz"; } }
        }
        private const string StageMode = "档位编号", ValueMode = "DPI 值";
        public ApplicationMouseProfilesDialog(List<MouseBatteryInfo> devices) : this(devices, CreateLoadedService()) { }
        private static ApplicationMouseProfileService CreateLoadedService()
        {
            var result = new ApplicationMouseProfileService(); result.Load(); return result;
        }
        public ApplicationMouseProfilesDialog(List<MouseBatteryInfo> devices, ApplicationMouseProfileService service)
        {
            if (service == null) throw new ArgumentNullException("service");
            this.service = service; this.devices = new List<MouseBatteryInfo>();
            if (devices != null)
                foreach (var device in devices)
                    if (device != null && device.DeviceId != null && device.DeviceId.StartsWith("Metapanda:", StringComparison.Ordinal)) this.devices.Add(device);
            Text = "按应用切换鼠标设置";
            StartPosition = FormStartPosition.CenterParent;
            Size = new Size(1220, 600); MinimumSize = new Size(980, 460);
            Font = new Font("Microsoft YaHei UI", 9F);
            Controls.Add(new Label { Dock = DockStyle.Top, Height = 70, Padding = new Padding(10),
                Text = "选择 DPI 值：自动匹配现有档位；选择档位编号：按从 1 开始的编号切换。双击单元格修改。\r\n游戏预设 800 DPI / 4000 Hz；办公预设 1600 DPI / 125 Hz，均可修改。退出匹配应用后恢复进入前的设置。\r\n完整 exe 路径匹配；预设按钮修改选中规则，保存后生效。这里不会修改鼠标内部的 DPI 档位数值。" });
            grid.Dock = DockStyle.Fill; grid.AllowUserToAddRows = false; grid.AllowUserToDeleteRows = false;
            grid.AutoGenerateColumns = false; grid.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
            grid.MultiSelect = false; grid.RowHeadersVisible = false;
            grid.Columns.Add(new DataGridViewCheckBoxColumn { Name = "enabled", HeaderText = "启用", Width = 48 });
            grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "exe", HeaderText = "应用 exe 完整路径", AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill, MinimumWidth = 140, FillWeight = 55 });
            var endpoints = new DataGridViewComboBoxColumn { Name = "device", HeaderText = "目标设备端点", AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill, MinimumWidth = 150, FillWeight = 45, FlatStyle = FlatStyle.Flat };
            foreach (var device in this.devices) if (!endpoints.Items.Contains(device.DeviceId)) endpoints.Items.Add(device.DeviceId);
            foreach (var profile in service.Profiles)
                if (profile != null && profile.IsValid() && !endpoints.Items.Contains(profile.DeviceId)) endpoints.Items.Add(profile.DeviceId);
            grid.Columns.Add(endpoints);
            var modes = new DataGridViewComboBoxColumn { Name = "mode", HeaderText = "DPI 选择方式", Width = 105, FlatStyle = FlatStyle.Flat };
            modes.Items.Add(StageMode); modes.Items.Add(ValueMode); grid.Columns.Add(modes);
            grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "target", HeaderText = "档位编号 / DPI", Width = 110 });
            var rates = new DataGridViewComboBoxColumn { Name = "rate", HeaderText = "回报率", Width = 95, FlatStyle = FlatStyle.Flat, DisplayMember = "Label", ValueMember = "Value", ValueType = typeof(int) };
            var choices = new List<RateChoice>();
            foreach (int hz in new int[] { 125, 250, 500, 1000, 2000, 4000 }) choices.Add(new RateChoice { Value = hz });
            rates.DataSource = choices;
            grid.Columns.Add(rates);
            grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "resolved", HeaderText = "匹配状态（设备快照）", Width = 195, ReadOnly = true });
            foreach (var profile in service.Profiles)
                if (profile != null && profile.IsValid()) grid.Rows.Add(profile.Enabled, profile.ExecutablePath, profile.DeviceId,
                    profile.DpiValue > 0 ? ValueMode : StageMode, profile.DpiValue > 0 ? profile.DpiValue : profile.DpiStage, profile.PollingRate);
            grid.DataError += delegate(object sender, DataGridViewDataErrorEventArgs e) { e.ThrowException = false; };
            grid.CellValueChanged += delegate(object sender, DataGridViewCellEventArgs e) {
                if (e.RowIndex >= 0 && e.ColumnIndex >= 0 && grid.Columns[e.ColumnIndex].Name != "resolved") UpdateResolution(grid.Rows[e.RowIndex]);
            };
            Controls.Add(grid);
            var buttons = new FlowLayoutPanel { Dock = DockStyle.Bottom, Height = 78, Padding = new Padding(8), FlowDirection = FlowDirection.LeftToRight };
            AddButton(buttons, "添加应用…", AddApplication);
            AddButton(buttons, "浏览 exe…", BrowseApplication);
            AddButton(buttons, "删除规则", delegate { if (grid.CurrentRow != null) grid.Rows.Remove(grid.CurrentRow); });
            AddButton(buttons, "游戏 800 DPI / 4000 Hz", delegate { ApplyPreset(800, 4000); });
            AddButton(buttons, "办公 1600 DPI / 125 Hz", delegate { ApplyPreset(1600, 125); });
            AddButton(buttons, "保存", SaveProfiles);
            AddButton(buttons, "取消", delegate { DialogResult = DialogResult.Cancel; Close(); });
            Controls.Add(buttons);
            var names = new TextBox { Dock = DockStyle.Bottom, Height = 105, ReadOnly = true, Multiline = true, ScrollBars = ScrollBars.Vertical, BackColor = SystemColors.Control, BorderStyle = BorderStyle.None };
            var labels = new List<string>();
            foreach (var device in this.devices)
            {
                var stages = new List<string>();
                if (device.DpiStages != null)
                    for (int i = 0; i < device.DpiStages.Length; i++)
                    {
                        string value = device.DpiStages[i].ToString();
                        if (device.DpiStagesY != null && i < device.DpiStagesY.Length && device.DpiStagesY[i] != device.DpiStages[i]) value += "/" + device.DpiStagesY[i].ToString();
                        stages.Add((i + 1).ToString() + "=" + value);
                    }
                labels.Add(device.DisplayName + " (" + device.Transport + ") · DPI 档位 " +
                    (stages.Count == 0 ? "未知" : string.Join(" / ", stages.ToArray())) + " · 当前 " + device.PollingRate.ToString() + " Hz\r\n" + device.DeviceId + (device.IsConnected ? "" : " (未连接)"));
            }
            names.Text = labels.Count == 0 ? "当前没有玄熊猫设备；已保存规则仍可编辑。设备连接并读到档位后自动匹配。" : string.Join("\r\n", labels.ToArray());
            Controls.Add(names); grid.BringToFront();
            foreach (DataGridViewRow row in grid.Rows) UpdateResolution(row);
        }
        private static void AddButton(FlowLayoutPanel panel, string text, Action action)
        {
            var button = new Button { Text = text, AutoSize = true, Height = 29 };
            button.Click += delegate { action(); }; panel.Controls.Add(button);
        }
        private ApplicationMouseProfile ReadRow(DataGridViewRow row)
        {
            int target, rate;
            string mode = Convert.ToString(row.Cells["mode"].Value);
            if ((mode != StageMode && mode != ValueMode) || !int.TryParse(Convert.ToString(row.Cells["target"].Value), out target) ||
                !int.TryParse(Convert.ToString(row.Cells["rate"].Value), out rate)) return null;
            return new ApplicationMouseProfile { ExecutablePath = Convert.ToString(row.Cells["exe"].Value), DeviceId = Convert.ToString(row.Cells["device"].Value),
                DpiStage = mode == StageMode ? target : 0, DpiValue = mode == ValueMode ? target : 0, PollingRate = rate,
                Enabled = Convert.ToBoolean(row.Cells["enabled"].Value) };
        }
        private void UpdateResolution(DataGridViewRow row)
        {
            var profile = ReadRow(row);
            string status = "请填写有效规则";
            if (profile != null && profile.IsValid())
            {
                status = "设备未连接，等待匹配";
                foreach (var device in devices)
                    if (device.DeviceId == profile.DeviceId && device.IsConnected)
                    {
                        int stage = profile.ResolveDpiStage(device);
                        status = !ApplicationMouseProfile.SupportsPollingRate(device, profile.PollingRate) ? "设备不支持此回报率" :
                            stage == 0 ? "未找到匹配的 DPI 档位" : "第 " + stage.ToString() + " 档 · " + device.DpiStages[stage - 1].ToString() + " DPI";
                        break;
                    }
            }
            row.Cells["resolved"].Value = status; row.Cells["resolved"].ToolTipText = status;
        }
        private void ApplyPreset(int dpi, int hz)
        {
            if (grid.CurrentRow == null) return;
            grid.EndEdit(); var row = grid.CurrentRow;
            row.Cells["mode"].Value = ValueMode; row.Cells["target"].Value = dpi; row.Cells["rate"].Value = hz;
            UpdateResolution(row);
        }
        private string PickExecutable()
        {
            using (var picker = new OpenFileDialog { Filter = "应用程序 (*.exe)|*.exe", CheckFileExists = true })
                return picker.ShowDialog(this) == DialogResult.OK ? picker.FileName : null;
        }
        private void AddApplication()
        {
            var endpoints = (DataGridViewComboBoxColumn)grid.Columns["device"];
            if (endpoints.Items.Count == 0) { MessageBox.Show(this, "请先连接可识别的玄熊猫设备。", Text); return; }
            string path = PickExecutable(); if (path == null) return;
            int index = grid.Rows.Add(true, path, endpoints.Items[0], ValueMode, 1600, 125);
            grid.CurrentCell = grid.Rows[index].Cells["target"]; UpdateResolution(grid.Rows[index]);
        }
        private void BrowseApplication()
        {
            if (grid.CurrentRow == null) return;
            string path = PickExecutable(); if (path != null) grid.CurrentRow.Cells["exe"].Value = path;
        }
        private void SaveProfiles()
        {
            if (!grid.EndEdit()) return;
            var profiles = new List<ApplicationMouseProfile>();
            foreach (DataGridViewRow row in grid.Rows)
            {
                var profile = ReadRow(row);
                if (profile == null || !profile.IsValid())
                { MessageBox.Show(this, "请填写完整 exe 路径、设备端点、选择方式和正整数。档位为 1~8；DPI 为 1~26000，运行时必须匹配实际档位。", Text); return; }
                foreach (var previous in profiles)
                    if (previous.DeviceId == profile.DeviceId && string.Equals(previous.ExecutablePath, profile.ExecutablePath, StringComparison.OrdinalIgnoreCase))
                    { MessageBox.Show(this, "同一应用与设备端点只保留一条规则。", Text); return; }
                profiles.Add(profile);
            }
            var previousProfiles = new List<ApplicationMouseProfile>(service.Profiles);
            try
            {
                service.Profiles.Clear(); service.Profiles.AddRange(profiles); service.Save();
                DialogResult = DialogResult.OK; Close();
            }
            catch (Exception ex)
            {
                service.Profiles.Clear(); service.Profiles.AddRange(previousProfiles);
                MessageBox.Show(this, "保存失败：" + ex.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }
}