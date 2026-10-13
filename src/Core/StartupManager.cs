// ============================================================================
// 模块名称: StartupManager.cs
// 所属区域: Core (核心管理层)
// 核心职责:
//   高鲁棒性开机自启动管理引擎：
//   1. 统一管理 HKCU\...\Run 注册表键与 Windows 10/11 StartupApproved\Run 启动仲裁
//   2. 修复时序倒挂 Bug：先安全迁移旧版启动项，最后才清理历史无用键名
//   3. 创建与同步带有 AppUserModelID (AUMID) 的 Windows 开始菜单与桌面快捷方式
// 依赖关系: NativeMethods.cs
//
// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️:
// 1. [契约同步更新]: 任何 AI Agent 在新增或修改自启动逻辑与注册表项时，【必须】同步更新上方说明。
// 2. [C# 5 兼容铁律]: 严禁使用 C# 6+ 语法。
// 3. [编码格式锁定]: 本文件必须严格保存为【UTF-8 with BOM】编码。
// ============================================================================

using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;

namespace RazerBatteryTray
{
    public static class StartupManager
    {
        public const string AppName = "FerrisPulse";
        public static readonly string[] LegacyAppNames = new string[] { "RazerBatteryTray", "RazerBattery", "RazerTray" };
        public const string RunRegistryKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        public const string StartupApprovedRunKey = @"Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run";
        public const string AppUserModelId = "FerrisPulse.App";

        /// <summary>
        /// 检测当前系统是否已为 FerrisPulse 配置了开机自启动
        /// 遵循安全迁移原则：先检查新名称，若不存在再检查历史旧名称，绝对不在此做删除
        /// </summary>
        public static bool IsAutoStartConfigured()
        {
            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(RunRegistryKey, false))
                {
                    if (key != null)
                    {
                        var val = key.GetValue(AppName);
                        if (val != null) return true;

                        foreach (var legacyName in LegacyAppNames)
                        {
                            if (key.GetValue(legacyName) != null) return true;
                        }
                    }
                }
            }
            catch { }
            return false;
        }

        /// <summary>
        /// 安全获取宿主程序的绝对路径，彻底防御测试进程（如 PowerShell、NUnit 等）反射调用时的污染
        /// </summary>
        public static string GetApplicationExecutablePath()
        {
            try
            {
                string currentExe = Application.ExecutablePath;
                if (!string.IsNullOrEmpty(currentExe))
                {
                    string fileName = Path.GetFileName(currentExe);
                    if (fileName.Equals("FerrisPulse.exe", StringComparison.OrdinalIgnoreCase))
                    {
                        return currentExe;
                    }
                }

                // 若当前为 PowerShell 或测试宿主进程，回退到当前基目录下的 FerrisPulse.exe
                string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                if (!string.IsNullOrEmpty(baseDir))
                {
                    string candidate = Path.Combine(baseDir, "FerrisPulse.exe");
                    if (File.Exists(candidate))
                    {
                        return candidate;
                    }
                }

                // 尝试从程序集所在目录探查
                string asmLocation = typeof(StartupManager).Assembly.Location;
                if (!string.IsNullOrEmpty(asmLocation))
                {
                    string asmDir = Path.GetDirectoryName(asmLocation);
                    string candidate2 = Path.Combine(asmDir, "FerrisPulse.exe");
                    if (File.Exists(candidate2))
                    {
                        return candidate2;
                    }
                }
            }
            catch { }
            return Application.ExecutablePath;
        }

        /// <summary>
        /// 开启或关闭开机自启动，并协同同步 Windows 10/11 的 StartupApproved 策略
        /// </summary>
        public static bool SetAutoStart(bool enabled, out string errorMessage)
        {
            errorMessage = null;
            try
            {
                using (var runKey = Registry.CurrentUser.OpenSubKey(RunRegistryKey, true))
                {
                    if (runKey == null)
                    {
                        errorMessage = "无法打开注册表 Run 键";
                        return false;
                    }

                    if (enabled)
                    {
                        string exePath = GetApplicationExecutablePath();
                        string commandLine = "\"" + exePath + "\" --autostart";
                        runKey.SetValue(AppName, commandLine);

                        // 协同修复 Windows 10/11 任务管理器的 StartupApproved 禁用锁定
                        try
                        {
                            using (var approvedKey = Registry.CurrentUser.OpenSubKey(StartupApprovedRunKey, true))
                            {
                                if (approvedKey != null)
                                {
                                    byte[] val = approvedKey.GetValue(AppName) as byte[];
                                    if (val != null && val.Length > 0 && val[0] == 0x03) // 0x03 表示在任务管理器中被禁用
                                    {
                                        // 恢复为启用（第一字节为 0x02），或直接移除交由 Windows 重新接管
                                        val[0] = 0x02;
                                        approvedKey.SetValue(AppName, val, RegistryValueKind.Binary);
                                    }
                                }
                            }
                        }
                        catch { }

                        // 只有在新键名成功写入后，才清理旧键名，杜绝时序倒挂
                        CleanupLegacyRunKeys(runKey);
                    }
                    else
                    {
                        runKey.DeleteValue(AppName, false);
                        CleanupLegacyRunKeys(runKey);

                        try
                        {
                            using (var approvedKey = Registry.CurrentUser.OpenSubKey(StartupApprovedRunKey, true))
                            {
                                if (approvedKey != null)
                                {
                                    approvedKey.DeleteValue(AppName, false);
                                    foreach (var legacy in LegacyAppNames)
                                    {
                                        try { approvedKey.DeleteValue(legacy, false); } catch { }
                                    }
                                }
                            }
                        }
                        catch { }
                    }
                }
                return true;
            }
            catch (Exception ex)
            {
                errorMessage = ex.Message;
                return false;
            }
        }

        /// <summary>
        /// 刷新并保持注册表中的自启动命令行与当前执行文件绝对路径一致
        /// </summary>
        public static void SyncAutoStartRegistry()
        {
            if (!IsAutoStartConfigured()) return;

            string errMsg;
            SetAutoStart(true, out errMsg);
        }

        /// <summary>
        /// 安全清理历史版本的旧名称键值
        /// </summary>
        private static void CleanupLegacyRunKeys(RegistryKey runKey)
        {
            if (runKey == null) return;
            foreach (var legacyName in LegacyAppNames)
            {
                try { runKey.DeleteValue(legacyName, false); } catch { }
            }
        }

        /// <summary>
        /// 创建并同步 Windows 开始菜单与桌面图标，绑定 AUMID 以保证原生 Toast 横幅通知完全正常
        /// </summary>
        public static void EnsureAppShortcutWithAumid()
        {
            try
            {
                NativeMethods.SetCurrentProcessExplicitAppUserModelID(AppUserModelId);

                string startMenu = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), @"Microsoft\Windows\Start Menu\Programs");
                if (!Directory.Exists(startMenu)) Directory.CreateDirectory(startMenu);
                string lnkPath = Path.Combine(startMenu, "FerrisPulse · 灵脉.lnk");
                string targetExe = GetApplicationExecutablePath();
                string dir = Path.GetDirectoryName(targetExe);
                string icoPath = Path.Combine(dir, "app.ico");
                if (!File.Exists(icoPath)) icoPath = targetExe;

                // 清理旧版本的快捷方式
                string oldLnkPath = Path.Combine(startMenu, "RazerBatteryTray.lnk");
                if (File.Exists(oldLnkPath))
                {
                    try { File.Delete(oldLnkPath); } catch { }
                }

                try
                {
                    string desktop = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
                    string oldDesktopLnk = Path.Combine(desktop, "RazerBatteryTray.lnk");
                    if (File.Exists(oldDesktopLnk)) { File.Delete(oldDesktopLnk); }
                }
                catch { }

                if (File.Exists(lnkPath))
                {
                    try { File.Delete(lnkPath); } catch { }
                }

                IShellLinkW link = (IShellLinkW)new ShellLink();
                link.SetPath(targetExe);
                link.SetWorkingDirectory(dir);
                link.SetIconLocation(icoPath, 0);
                link.SetDescription("FerrisPulse · 灵脉 外设电量感知引擎");

                IPropertyStore store = (IPropertyStore)link;
                PROPERTYKEY key = new PROPERTYKEY();
                key.fmtid = new Guid("{9F4C2855-9F79-4BDE-A8E1-E1DE34EB1AE8}");
                key.pid = 5;

                PROPVARIANT pv = new PROPVARIANT();
                pv.vt = 31; // VT_LPWSTR
                pv.pwszVal = Marshal.StringToCoTaskMemUni(AppUserModelId);
                try
                {
                    store.SetValue(ref key, ref pv);
                    store.Commit();
                }
                finally
                {
                    Marshal.FreeCoTaskMem(pv.pwszVal);
                }

                IPersistFile file = (IPersistFile)link;
                file.Save(lnkPath, true);

                // 不在用户桌面创建任何快捷方式，保持用户桌面纯净无侵扰（Toast 通知仅需开始菜单 AUMID 链接）

                try { NativeMethods.SHChangeNotify(0x7FFFFFFF, 0x1000, IntPtr.Zero, IntPtr.Zero); } catch { }

                // 注册 HKCU 提示信息保证通知中心标题与图标呈现
                try
                {
                    using (var appKey = Registry.CurrentUser.CreateSubKey(@"Software\Classes\AppUserModelId\" + AppUserModelId))
                    {
                        if (appKey != null)
                        {
                            appKey.SetValue("DisplayName", "FerrisPulse · 灵脉");
                            appKey.SetValue("IconUri", icoPath);
                            appKey.SetValue("IconBackgroundColor", "00000000");
                        }
                    }
                    using (var notifKey = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\" + AppUserModelId))
                    {
                        if (notifKey != null)
                        {
                            notifKey.SetValue("ShowInActionCenter", 1, RegistryValueKind.DWord);
                            notifKey.SetValue("Enabled", 1, RegistryValueKind.DWord);
                        }
                    }
                }
                catch { }
            }
            catch { }
        }

        /// <summary>
        /// 首次运行策略：若当前非开机自启动且尚未初始化过桌面快捷方式，则创建一次并标记已初始化。
        /// 若用户后续手动删除桌面图标，则判定为用户偏好，绝不死灰复燃。
        /// </summary>
        public static void EnsureDesktopShortcutFirstRun(bool isAutoStart)
        {
            if (isAutoStart) return;

            try
            {
                bool initialized = ConfigManager.GetBool(ConfigManager.DesktopShortcutInitialized, false);
                if (!initialized)
                {
                    CreateDesktopShortcut(false);
                    ConfigManager.SetBool(ConfigManager.DesktopShortcutInitialized, true);
                }
            }
            catch { }
        }

        /// <summary>
        /// 在用户桌面创建带有高清矢量图标与工作目录绑定的快捷方式
        /// </summary>
        public static bool CreateDesktopShortcut(bool showNotice = false)
        {
            try
            {
                string desktop = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
                if (string.IsNullOrEmpty(desktop) || !Directory.Exists(desktop))
                {
                    return false;
                }

                string lnkPath = Path.Combine(desktop, "FerrisPulse · 灵脉.lnk");
                string targetExe = GetApplicationExecutablePath();
                if (string.IsNullOrEmpty(targetExe) ||
                    targetExe.IndexOf("powershell", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    targetExe.IndexOf("cmd.exe", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    string fallback = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "FerrisPulse.exe");
                    if (File.Exists(fallback))
                    {
                        targetExe = fallback;
                    }
                    else
                    {
                        return false;
                    }
                }

                string dir = Path.GetDirectoryName(targetExe);
                string icoPath = Path.Combine(dir, "app.ico");

                IShellLinkW link = (IShellLinkW)new ShellLink();
                link.SetPath(targetExe);
                link.SetWorkingDirectory(dir);
                if (File.Exists(icoPath))
                {
                    link.SetIconLocation(icoPath, 0);
                }
                else
                {
                    link.SetIconLocation(targetExe, 0);
                }
                link.SetDescription("FerrisPulse · 灵脉 外设电量感知引擎");

                IPropertyStore store = (IPropertyStore)link;
                PROPERTYKEY key = new PROPERTYKEY();
                key.fmtid = new Guid("{9F4C2855-9F79-4BDE-A8E1-E1DE34EB1AE8}");
                key.pid = 5;

                PROPVARIANT pv = new PROPVARIANT();
                pv.vt = 31; // VT_LPWSTR
                pv.pwszVal = Marshal.StringToCoTaskMemUni(AppUserModelId);
                try
                {
                    store.SetValue(ref key, ref pv);
                    store.Commit();
                }
                finally
                {
                    Marshal.FreeCoTaskMem(pv.pwszVal);
                }

                IPersistFile file = (IPersistFile)link;
                file.Save(lnkPath, true);

                try { NativeMethods.SHChangeNotify(0x7FFFFFFF, 0x1000, IntPtr.Zero, IntPtr.Zero); } catch { }
                return true;
            }
            catch
            {
                return false;
            }
        }
    }
}
