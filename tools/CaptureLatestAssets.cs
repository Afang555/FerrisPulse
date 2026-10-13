using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;
using RazerBatteryTray;

class CaptureLatestAssets
{
    [STAThread]
    static void Main()
    {
        string outDir = Path.GetFullPath(@"promo\assets\screenshots");
        if (!Directory.Exists(outDir)) Directory.CreateDirectory(outDir);

        Console.WriteLine("=================================================");
        Console.WriteLine("FerrisPulse 2.0 Pixel-Perfect Immersive Dark Capture");
        Console.WriteLine("Output Directory: " + outDir);
        Console.WriteLine("=================================================");

        // ─────────────────────────────────────────
        // 1. Razer DeathAdder V4 Pro (Mouse 8000Hz)
        // ─────────────────────────────────────────
        try
        {
            MainForm formMouse = new MainForm();
            formMouse.PauseBackgroundRefresh = true;
            formMouse.StartPosition = FormStartPosition.Manual;
            formMouse.Location = new Point(100, 100);
            formMouse.Show();
            StopTimers(formMouse);

            MouseBatteryInfo mouseInfo = new MouseBatteryInfo
            {
                DeviceId = "Razer:1532:00B9",
                Brand = "Razer",
                Category = DeviceCategory.Mouse,
                DeviceName = "Razer DeathAdder V4 Pro",
                CustomName = "Razer DeathAdder V4 Pro",
                BatteryPercent = 98,
                IsConnected = true,
                IsCharging = false,
                PollingRate = 8000,
                SupportedPollingRates = new int[] { 1000, 2000, 4000, 8000 },
                Dpi = 3200,
                DpiStage = 4,
                DpiStageCount = 5,
                DpiStages = new int[] { 400, 800, 1600, 3200, 6400 },
                Transport = "2.4G 极速无线",
                LastUpdated = DateTime.Now
            };

            SetDeviceView(formMouse, mouseInfo);
            SaveCroppedModernDarkWindow(formMouse, "FerrisPulse · 灵脉", Path.Combine(outDir, "latest_mouse_v4pro.png"), true, false);
            formMouse.Close();
            Console.WriteLine("✓ Captured latest_mouse_v4pro.png");
        }
        catch (Exception ex) { Console.WriteLine("Mouse error: " + ex.ToString()); }

        // ─────────────────────────────────────────
        // 2. NuPhy WH80 (Keyboard Dedicated Console)
        // ─────────────────────────────────────────
        try
        {
            MainForm formKb = new MainForm();
            formKb.PauseBackgroundRefresh = true;
            formKb.StartPosition = FormStartPosition.Manual;
            formKb.Location = new Point(100, 100);
            formKb.Show();
            StopTimers(formKb);

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

            SetDeviceView(formKb, kbInfo);

            MethodInfo applyNuphy = typeof(MainForm).GetMethod("ApplyNuphySettingsToUI", BindingFlags.NonPublic | BindingFlags.Instance);
            if (applyNuphy != null) applyNuphy.Invoke(formKb, null);

            SaveCroppedModernDarkWindow(formKb, "FerrisPulse · 灵脉", Path.Combine(outDir, "latest_keyboard_nuphy.png"), true, false);
            formKb.Close();
            Console.WriteLine("✓ Captured latest_keyboard_nuphy.png");
        }
        catch (Exception ex) { Console.WriteLine("Keyboard error: " + ex.ToString()); }

        // ─────────────────────────────────────────
        // 3. Xbox / XInput Gamepad (Tactile Feedback)
        // ─────────────────────────────────────────
        try
        {
            MainForm formPad = new MainForm();
            formPad.PauseBackgroundRefresh = true;
            formPad.StartPosition = FormStartPosition.Manual;
            formPad.Location = new Point(100, 100);
            formPad.Show();
            StopTimers(formPad);

            MouseBatteryInfo padInfo = new MouseBatteryInfo
            {
                DeviceId = "Gamepad:XInput:0",
                Brand = "Xbox",
                Category = DeviceCategory.Gamepad,
                DeviceName = "Xbox Wireless Controller",
                CustomName = "Xbox Wireless Controller",
                BatteryPercent = 85,
                IsConnected = true,
                IsCharging = false,
                Transport = "Bluetooth / XInput 遥测",
                LastUpdated = DateTime.Now
            };

            SetDeviceView(formPad, padInfo);
            SaveCroppedModernDarkWindow(formPad, "FerrisPulse · 灵脉", Path.Combine(outDir, "latest_gamepad_xinput.png"), true, false);
            formPad.Close();
            Console.WriteLine("✓ Captured latest_gamepad_xinput.png");
        }
        catch (Exception ex) { Console.WriteLine("Gamepad error: " + ex.ToString()); }

        // ─────────────────────────────────────────
        // 4. Game Process Manager (CS2, Valorant, etc.)
        // ─────────────────────────────────────────
        try
        {
            List<string> mockGames = new List<string>
            {
                "cs2.exe",
                "valorant.exe",
                "apex.exe",
                "naraka.exe",
                "blackmythwukong.exe"
            };

            GameProcessManagerForm gameForm = new GameProcessManagerForm(1.0f, mockGames, true, null);
            gameForm.StartPosition = FormStartPosition.Manual;
            gameForm.Location = new Point(100, 100);
            gameForm.Show();

            SaveCroppedModernDarkWindow(gameForm, "FerrisPulse · 电竞游戏进程管理与自动捕获", Path.Combine(outDir, "latest_game_manager.png"), false, false);
            gameForm.Close();
            Console.WriteLine("✓ Captured latest_game_manager.png");
        }
        catch (Exception ex) { Console.WriteLine("Game Manager error: " + ex.ToString()); }

        // ─────────────────────────────────────────
        // 5. Add Device Wizard
        // ─────────────────────────────────────────
        try
        {
            AddDeviceWizardForm wizForm = new AddDeviceWizardForm(1.0f);
            wizForm.StartPosition = FormStartPosition.Manual;
            wizForm.Location = new Point(100, 100);
            wizForm.Show();

            SaveCroppedModernDarkWindow(wizForm, "添加与配置外设向导", Path.Combine(outDir, "latest_device_wizard.png"), false, false);
            wizForm.Close();
            Console.WriteLine("✓ Captured latest_device_wizard.png");
        }
        catch (Exception ex) { Console.WriteLine("Wizard error: " + ex.ToString()); }

        // ─────────────────────────────────────────
        // 6. Device Priority Form
        // ─────────────────────────────────────────
        try
        {
            List<MouseBatteryInfo> prioList = new List<MouseBatteryInfo>
            {
                new MouseBatteryInfo { DeviceId = "Razer:1532:00B9", CustomName = "炼狱蝰蛇 V4 Pro", DeviceName = "Razer DeathAdder V4 Pro", Category = DeviceCategory.Mouse, BatteryPercent = 98, IsConnected = true },
                new MouseBatteryInfo { DeviceId = "NuPhy:WH80:Wireless", CustomName = "NuPhy WH80 三模键盘", DeviceName = "NuPhy WH80", Category = DeviceCategory.Keyboard, BatteryPercent = 100, IsConnected = true },
                new MouseBatteryInfo { DeviceId = "Gamepad:XInput:0", CustomName = "Xbox Wireless Controller", DeviceName = "Xbox Controller", Category = DeviceCategory.Gamepad, BatteryPercent = 85, IsConnected = true }
            };

            DevicePriorityForm prioForm = new DevicePriorityForm(prioList, 1.0f);
            prioForm.StartPosition = FormStartPosition.Manual;
            prioForm.Location = new Point(100, 100);
            prioForm.Show();

            SaveCroppedModernDarkWindow(prioForm, "设备优先级管理 (拖拽排序)", Path.Combine(outDir, "latest_device_priority.png"), false, false);
            prioForm.Close();
            Console.WriteLine("✓ Captured latest_device_priority.png");
        }
        catch (Exception ex) { Console.WriteLine("Priority error: " + ex.ToString()); }

        // ─────────────────────────────────────────
        // 7. SWR Update Notice Form
        // ─────────────────────────────────────────
        try
        {
            UpdateInfo updateInfo = new UpdateInfo
            {
                LatestVersion = "v2.1.0",
                ReleaseDate = "2026-10-05",
                DownloadUrl = "https://gitee.com/Ferris-echo/ferris-pulse",
                Changelog = new List<string>
                {
                    "• 【外设支持】扩展支持罗技、雷柏、NuPhy 及主流国产品牌外设，支持蓝牙耳机电量显示",
                    "• 【游戏调度】支持全屏游戏自动切换高回报率与游戏进程守护，配备无感 OSD 与提示音",
                    "• 【按键测速】内置独占全键无冲测速仪 (NKRO)，毫秒级统计击键并发与延迟",
                    "• 【自动更新】新增在线检查更新与无感热替换，发现新版一键自动升级",
                    "• 【原生美学】Win11 深度暗黑质感，三大托盘图标风格，支持设备自定义改名"
                }
            };

            UpdateNoticeForm updateForm = new UpdateNoticeForm(updateInfo, "v2.0.0");
            updateForm.StartPosition = FormStartPosition.Manual;
            updateForm.Location = new Point(100, 100);
            updateForm.Show();

            SaveCroppedModernDarkWindow(updateForm, "发现新版本", Path.Combine(outDir, "update_notice_dark_fixed.png"), false, false);
            updateForm.Close();
            Console.WriteLine("✓ Captured update_notice_dark_fixed.png");
        }
        catch (Exception ex) { Console.WriteLine("Update Form error: " + ex.ToString()); }

        // ─────────────────────────────────────────
        // 8. OSD 8000Hz (Borderless)
        // ─────────────────────────────────────────
        try
        {
            DpiOsdForm osdRate = new DpiOsdForm(1.0f);
            osdRate.ShowRate(8000, "电竞游戏独占 · 极速 8000Hz 已激活", "Razer");
            osdRate.StartPosition = FormStartPosition.Manual;
            osdRate.Location = new Point(200, 200);
            Application.DoEvents();
            Thread.Sleep(300);

            Bitmap bmpOsd = new Bitmap(osdRate.Width, osdRate.Height);
            osdRate.DrawToBitmap(bmpOsd, new Rectangle(0, 0, osdRate.Width, osdRate.Height));
            bmpOsd.Save(Path.Combine(outDir, "latest_osd_rate_8000hz.png"), ImageFormat.Png);
            osdRate.Close();
            Console.WriteLine("✓ Captured latest_osd_rate_8000hz.png");
        }
        catch (Exception ex) { Console.WriteLine("OSD error: " + ex.ToString()); }

        Console.WriteLine("\n=== ALL REAL WIN11 IMMERSIVE DARK ASSETS CAPTURED SUCCESSFULLY! ===");
    }

    private static void SetDeviceView(MainForm form, MouseBatteryInfo dev)
    {
        FieldInfo selField = typeof(MainForm).GetField("selectedDevice", BindingFlags.NonPublic | BindingFlags.Instance);
        if (selField != null) selField.SetValue(form, dev);

        FieldInfo actField = typeof(MainForm).GetField("activeDevices", BindingFlags.NonPublic | BindingFlags.Instance);
        if (actField != null) actField.SetValue(form, new List<MouseBatteryInfo> { dev });

        FieldInfo lastField = typeof(MainForm).GetField("lastInfo", BindingFlags.NonPublic | BindingFlags.Instance);
        if (lastField != null) lastField.SetValue(form, dev);

        MethodInfo updateUiMethod = typeof(MainForm).GetMethod("UpdateUI", BindingFlags.NonPublic | BindingFlags.Instance);
        if (updateUiMethod != null) updateUiMethod.Invoke(form, new object[] { dev, false });
    }

    private static void StopTimers(MainForm form)
    {
        FieldInfo tmrField = typeof(MainForm).GetField("updateTimer", BindingFlags.NonPublic | BindingFlags.Instance);
        if (tmrField != null)
        {
            System.Windows.Forms.Timer t = (System.Windows.Forms.Timer)tmrField.GetValue(form);
            if (t != null) t.Stop();
        }
        FieldInfo bootField = typeof(MainForm).GetField("bootPollTimer", BindingFlags.NonPublic | BindingFlags.Instance);
        if (bootField != null)
        {
            System.Windows.Forms.Timer t = (System.Windows.Forms.Timer)bootField.GetValue(form);
            if (t != null) t.Stop();
        }
    }

    private static void SaveCroppedModernDarkWindow(Form form, string title, string path, bool hasMin = false, bool hasMax = false)
    {
        Application.DoEvents();
        Thread.Sleep(200);

        // 1. Draw entire Form to bitmap
        Bitmap fullBmp = new Bitmap(form.Width, form.Height);
        form.DrawToBitmap(fullBmp, new Rectangle(0, 0, form.Width, form.Height));

        // 2. Locate client area bounds dynamically
        int clientTop = 26;
        int clientLeft = 3;

        for (int y = 0; y < fullBmp.Height / 3; y++)
        {
            Color c = fullBmp.GetPixel(fullBmp.Width / 2, y);
            // Match dark background #121317 or #18191e
            if (c.R >= 14 && c.R <= 26 && c.G >= 14 && c.G <= 28 && c.B >= 18 && c.B <= 32)
            {
                clientTop = y;
                break;
            }
        }
        for (int x = 0; x < fullBmp.Width / 4; x++)
        {
            Color c = fullBmp.GetPixel(x, clientTop + 20);
            if (c.R >= 14 && c.R <= 26 && c.G >= 14 && c.G <= 28 && c.B >= 18 && c.B <= 32)
            {
                clientLeft = x;
                break;
            }
        }

        int clientW = Math.Min(form.ClientSize.Width, fullBmp.Width - clientLeft);
        int clientH = Math.Min(form.ClientSize.Height, fullBmp.Height - clientTop);

        Rectangle clientRect = new Rectangle(clientLeft, clientTop, clientW, clientH);
        using (Bitmap clientOnly = fullBmp.Clone(clientRect, fullBmp.PixelFormat))
        {
            // 3. Compose with authentic Win11 Dark Title Bar
            int titleH = 34;
            using (Bitmap modernDarkWindow = new Bitmap(clientW, clientH + titleH))
            {
                using (Graphics g = Graphics.FromImage(modernDarkWindow))
                {
                    g.SmoothingMode = SmoothingMode.AntiAlias;
                    g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;

                    // Fill Win11 Immersive Dark Caption (#0c0c0e)
                    using (SolidBrush bgBrush = new SolidBrush(Color.FromArgb(12, 12, 14)))
                    {
                        g.FillRectangle(bgBrush, 0, 0, modernDarkWindow.Width, titleH);
                    }

                    // Draw app icon
                    int titleTextX = 14;
                    if (File.Exists("app.png"))
                    {
                        using (Image appImg = Image.FromFile("app.png"))
                        {
                            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                            g.DrawImage(appImg, new Rectangle(11, 8, 18, 18));
                            titleTextX = 36;
                        }
                    }

                    // Draw Window Title Text
                    using (Font titleFont = new Font("Microsoft YaHei UI", 9F, FontStyle.Regular))
                    using (SolidBrush textBrush = new SolidBrush(Color.FromArgb(235, 235, 235)))
                    {
                        g.DrawString(title, titleFont, textBrush, titleTextX, 8);
                    }

                    // Draw Win11 Window Controls (- □ ✕)
                    int btnW = 46;
                    int rightX = modernDarkWindow.Width;
                    using (Pen pen = new Pen(Color.FromArgb(200, 200, 200), 1.0f))
                    {
                        if (hasMin)
                        {
                            int minX = rightX - (hasMax ? btnW * 3 : btnW * 2) + 18;
                            g.DrawLine(pen, minX, 17, minX + 10, 17);
                        }
                        if (hasMax)
                        {
                            int maxX = rightX - btnW * 2 + 18;
                            g.DrawRectangle(pen, maxX, 12, 10, 10);
                        }
                        // Close button (✕)
                        int closeX = rightX - btnW + 18;
                        g.DrawLine(pen, closeX, 12, closeX + 10, 22);
                        g.DrawLine(pen, closeX + 10, 12, closeX, 22);
                    }

                    // Draw client area seamlessly below caption
                    g.DrawImage(clientOnly, 0, titleH);
                }

                modernDarkWindow.Save(path, ImageFormat.Png);
            }
        }
        fullBmp.Dispose();
    }
}
