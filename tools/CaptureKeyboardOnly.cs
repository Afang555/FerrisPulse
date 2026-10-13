using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;
using RazerBatteryTray;

class CaptureKeyboardOnly
{
    [STAThread]
    static void Main()
    {
        string outDir = Path.GetFullPath(@"promo\assets\screenshots");
        MainForm form = new MainForm();
        form.StartPosition = FormStartPosition.Manual;
        form.Location = new Point(100, 100);
        form.Show();
        Application.DoEvents();

        // Stop all timers
        FieldInfo tmrField = typeof(MainForm).GetField("updateTimer", BindingFlags.NonPublic | BindingFlags.Instance);
        if (tmrField != null) {
            System.Windows.Forms.Timer t = (System.Windows.Forms.Timer)tmrField.GetValue(form);
            if (t != null) t.Stop();
        }
        FieldInfo bootField = typeof(MainForm).GetField("bootPollTimer", BindingFlags.NonPublic | BindingFlags.Instance);
        if (bootField != null) {
            System.Windows.Forms.Timer t = (System.Windows.Forms.Timer)bootField.GetValue(form);
            if (t != null) t.Stop();
        }

        NuphyDeviceHelper.CachedHardwareSettings = new NuphyDeviceHelper.NuphyHardwareSettings
        {
            SleepEnabled = true,
            WinLock = false,
            BacklightEnabled = true,
            BacklightBrightness = 100,
            SidelightEnabled = true,
            SidelightBrightness = 100
        };

        MouseBatteryInfo kbInfo = new MouseBatteryInfo
        {
            DeviceId = "NuPhy:WH80:Wireless",
            Brand = "NuPhy",
            Category = DeviceCategory.Keyboard,
            DeviceName = "NuPhy WH80 三模磁轴键盘",
            CustomName = "NuPhy WH80 三模键盘",
            BatteryPercent = 100,
            IsConnected = true,
            IsCharging = false,
            Transport = "2.4G 专属协议遥测",
            LastUpdated = DateTime.Now
        };

        FieldInfo selField = typeof(MainForm).GetField("selectedDevice", BindingFlags.NonPublic | BindingFlags.Instance);
        if (selField != null) selField.SetValue(form, kbInfo);

        FieldInfo actField = typeof(MainForm).GetField("activeDevices", BindingFlags.NonPublic | BindingFlags.Instance);
        if (actField != null) actField.SetValue(form, new List<MouseBatteryInfo> { kbInfo });

        MethodInfo updateUIMethod = typeof(MainForm).GetMethod("UpdateUI", BindingFlags.NonPublic | BindingFlags.Instance);
        updateUIMethod.Invoke(form, new object[] { kbInfo, false });

        MethodInfo applyNuphy = typeof(MainForm).GetMethod("ApplyNuphySettingsToUI", BindingFlags.NonPublic | BindingFlags.Instance);
        if (applyNuphy != null) applyNuphy.Invoke(form, null);

        Application.DoEvents();
        Thread.Sleep(300);
        Application.DoEvents();

        Bitmap bmp = new Bitmap(form.Width, form.Height);
        form.DrawToBitmap(bmp, new Rectangle(0, 0, form.Width, form.Height));
        bmp.Save(Path.Combine(outDir, "latest_keyboard_nuphy.png"), ImageFormat.Png);
        Console.WriteLine("✓ Nuphy captured successfully!");

        form.Close();
    }
}
