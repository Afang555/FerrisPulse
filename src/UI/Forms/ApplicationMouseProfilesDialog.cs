// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
// Editable per-application Metapanda endpoint rules. No hardware writes.
// Preserve C# 5 / .NET 4 and UTF-8 BOM; caller pauses scheduler while dialog is open.
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

        public ApplicationMouseProfilesDialog(List<MouseBatteryInfo> devices)
            : this(devices, CreateLoadedService()) { }

        private static ApplicationMouseProfileService CreateLoadedService()
        {
            var result = new ApplicationMouseProfileService(); result.Load(); return result;
        }

        public ApplicationMouseProfilesDialog(List<MouseBatteryInfo> devices, ApplicationMouseProfileService service)
        {
            if (service == null) throw new ArgumentNullException("service");
            this.service = service;
            this.devices = new List<MouseBatteryInfo>();
            if (devices != null)
                foreach (var device in devices)
                    if (device != null && device.DeviceId != null && device.DeviceId.StartsWith("Metapanda:", StringComparison.Ordinal)) this.devices.Add(device);
            Text = "按应用切换鼠标设置";
            StartPosition = FormStartPosition.CenterParent;
            Size = new Size(1000, 530); MinimumSize = new Size(800, 400);
            Font = new Font("Microsoft YaHei UI", 9F);
            var description = new Label { Dock = DockStyle.Top, Height = 65, Padding = new Padding(10),
                Text = "完整 exe 路径匹配；同一应用可为不同鼠标端点分别设定规则。双击单元格修改。\r\n仅玄熊猫已验证端点可自动切换；当前状态和 DPI 档位未知时不发送。退出应用后恢复进入前的桌面设置。" };
            Controls.Add(description);
            grid.Dock = DockStyle.Fill;
            grid.AllowUserToAddRows = false; grid.AllowUserToDeleteRows = false;
            grid.AutoGenerateColumns = false; grid.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
            grid.MultiSelect = false; grid.RowHeadersVisible = false;
            grid.Columns.Add(new DataGridViewCheckBoxColumn { Name = "enabled", HeaderText = "启用", Width = 50 });
            grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "exe", HeaderText = "应用 exe 完整路径", AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill, FillWeight = 55 });
            var endpoints = new DataGridViewComboBoxColumn { Name = "device", HeaderText = "目标设备端点", AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill, FillWeight = 45, FlatStyle = FlatStyle.Flat };
            foreach (var device in this.devices) if (!endpoints.Items.Contains(device.DeviceId)) endpoints.Items.Add(device.DeviceId);
            foreach (var profile in service.Profiles)
                if (profile != null && profile.IsValid() && !endpoints.Items.Contains(profile.DeviceId)) endpoints.Items.Add(profile.DeviceId);
            grid.Columns.Add(endpoints);
            grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "stage", HeaderText = "DPI 档位 (从1起)", Width = 115 });
            var rates = new DataGridViewComboBoxColumn { Name = "rate", HeaderText = "回报率 Hz", Width = 100, FlatStyle = FlatStyle.Flat };
            rates.Items.Add(125); rates.Items.Add(1000); grid.Columns.Add(rates);
            foreach (var profile in service.Profiles)
                if (profile != null && profile.IsValid()) grid.Rows.Add(profile.Enabled, profile.ExecutablePath, profile.DeviceId, profile.DpiStage, profile.PollingRate);
            grid.DataError += delegate(object sender, DataGridViewDataErrorEventArgs e) { e.ThrowException = false; };
            Controls.Add(grid); grid.BringToFront();
            var buttons = new FlowLayoutPanel { Dock = DockStyle.Bottom, Height = 48, Padding = new Padding(8), FlowDirection = FlowDirection.LeftToRight };
            AddButton(buttons, "添加应用…", AddApplication);
            AddButton(buttons, "浏览 exe…", BrowseApplication);
            AddButton(buttons, "删除规则", delegate { if (grid.CurrentRow != null) grid.Rows.Remove(grid.CurrentRow); });
            AddButton(buttons, "保存", SaveProfiles);
            AddButton(buttons, "取消", delegate { DialogResult = DialogResult.Cancel; Close(); });
            Controls.Add(buttons); buttons.BringToFront();
            var names = new Label { Dock = DockStyle.Bottom, Height = 75, Padding = new Padding(8), AutoEllipsis = true };
            var labels = new List<string>();
            foreach (var device in this.devices)
            {
                var stages = new List<string>();
                if (device.DpiStages != null)
                    for (int i = 0; i < device.DpiStages.Length; i++)
                        stages.Add((i + 1).ToString() + "=" + device.DpiStages[i].ToString());
                labels.Add(device.DisplayName + " (" + device.Transport + ") · DPI档位 " +
                    (stages.Count == 0 ? "未知" : string.Join(" / ", stages.ToArray())) +
                    " · 当前 " + device.PollingRate.ToString() + "Hz\r\n" + device.DeviceId + (device.IsConnected ? "" : " (未连接)"));
            }
            names.Text = labels.Count == 0 ? "当前没有玄熊猫设备；已保存的规则仍可编辑，设备重新连接且状态已知后生效。" : string.Join("\r\n", labels.ToArray());
            Controls.Add(names); names.BringToFront();
            grid.BringToFront();
        }

        private static void AddButton(FlowLayoutPanel panel, string text, Action action)
        {
            var button = new Button { Text = text, AutoSize = true, Height = 29 };
            button.Click += delegate { action(); }; panel.Controls.Add(button);
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
            int index = grid.Rows.Add(true, path, endpoints.Items[0], 1, 125);
            grid.CurrentCell = grid.Rows[index].Cells["stage"];
        }
        private void BrowseApplication()
        {
            if (grid.CurrentRow == null) return;
            string path = PickExecutable(); if (path != null) grid.CurrentRow.Cells["exe"].Value = path;
        }
        private void SaveProfiles()
        {
            grid.EndEdit();
            var profiles = new List<ApplicationMouseProfile>();
            foreach (DataGridViewRow row in grid.Rows)
            {
                int stage, rate;
                if (!int.TryParse(Convert.ToString(row.Cells["stage"].Value), out stage) || !int.TryParse(Convert.ToString(row.Cells["rate"].Value), out rate))
                { MessageBox.Show(this, "DPI 档位必须为正整数，回报率必须为 125 或 1000。", Text); return; }
                var profile = new ApplicationMouseProfile { ExecutablePath = Convert.ToString(row.Cells["exe"].Value), DeviceId = Convert.ToString(row.Cells["device"].Value),
                    DpiStage = stage, PollingRate = rate, Enabled = Convert.ToBoolean(row.Cells["enabled"].Value) };
                if (!profile.IsValid()) { MessageBox.Show(this, "请填写完整 exe 路径、玄熊猫目标端点、有效档位和回报率。", Text); return; }
                foreach (var device in devices)
                    if (device.DeviceId == profile.DeviceId && device.DpiStages != null && device.DpiStages.Length > 0 &&
                        (stage > device.DpiStages.Length || device.DpiStages[stage - 1] <= 0))
                    { MessageBox.Show(this, "目标设备没有该 DPI 档位。", Text); return; }
                // Executable paths ignore case; endpoint IDs retain exact identity.
                bool duplicate = false;
                foreach (var previous in profiles)
                    if (previous.DeviceId == profile.DeviceId && string.Equals(previous.ExecutablePath, profile.ExecutablePath, StringComparison.OrdinalIgnoreCase)) duplicate = true;
                if (duplicate) { MessageBox.Show(this, "同一应用与设备端点只保留一条规则。", Text); return; }
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
