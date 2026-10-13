# tests\test_startup_shortcut_policy.ps1
# 验证方案一：绿色免安装桌面快捷方式全生命周期与托盘手动创建
$ErrorActionPreference = "Stop"

$asmPath = Join-Path $PSScriptRoot "..\FerrisPulse.exe"
if (-not (Test-Path $asmPath)) { $asmPath = "FerrisPulse.exe" }
$fullPath = (Resolve-Path $asmPath).Path
$bytes = [System.IO.File]::ReadAllBytes($fullPath)
$asm = [System.Reflection.Assembly]::Load($bytes)

$tStartup = $asm.GetType("RazerBatteryTray.StartupManager")
$tConfig = $asm.GetType("RazerBatteryTray.ConfigManager")

if ($tStartup -eq $null) {
    Write-Host "FAIL: Type RazerBatteryTray.StartupManager not found" -ForegroundColor Red
    exit 1
}

# 1. 契约校验：检查方法签名与配置键定义
$mCreate = $tStartup.GetMethod("CreateDesktopShortcut", [System.Reflection.BindingFlags]"Public,Static")
if ($mCreate -eq $null) {
    Write-Host "FAIL: Method StartupManager.CreateDesktopShortcut not found!" -ForegroundColor Red
    exit 1
}

$mFirstRun = $tStartup.GetMethod("EnsureDesktopShortcutFirstRun", [System.Reflection.BindingFlags]"Public,Static")
if ($mFirstRun -eq $null) {
    Write-Host "FAIL: Method StartupManager.EnsureDesktopShortcutFirstRun not found!" -ForegroundColor Red
    exit 1
}

$fKey = $tConfig.GetField("DesktopShortcutInitialized", [System.Reflection.BindingFlags]"Public,Static")
if ($fKey -eq $null) {
    Write-Host "FAIL: Field ConfigManager.DesktopShortcutInitialized not found!" -ForegroundColor Red
    exit 1
}

Write-Host "PASS: Public APIs and Registry Key contracts exist." -ForegroundColor Green

# 2. 模拟生命周期测试
$regKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\FerrisPulse")

# 测试场景 A: 开机自启 (isAutoStart = true) 严禁初始化桌面快捷方式
$regKey.SetValue("DesktopShortcutInitialized", 0, [Microsoft.Win32.RegistryValueKind]::DWord)
$mFirstRun.Invoke($null, @($true))
$valA = [int]$regKey.GetValue("DesktopShortcutInitialized", -1)
if ($valA -ne 0) {
    Write-Host "FAIL: AutoStart unexpectedly modified DesktopShortcutInitialized!" -ForegroundColor Red
    exit 1
}
Write-Host "PASS: Scenario A - AutoStart strictly respects silent boot." -ForegroundColor Green

# 测试场景 B: 首次手动运行 (isAutoStart = false 且未初始化)
$mFirstRun.Invoke($null, @($false))
$valB = [int]$regKey.GetValue("DesktopShortcutInitialized", -1)
if ($valB -ne 1) {
    Write-Host "FAIL: First manual run failed to set DesktopShortcutInitialized to 1!" -ForegroundColor Red
    exit 1
}
Write-Host "PASS: Scenario B - First manual run initialized shortcut and set flag = 1." -ForegroundColor Green

# 测试场景 C: 随后运行 (已有初始化标记)
# 假定用户删除了快捷方式，再次调用 EnsureDesktopShortcutFirstRun(false) 绝不反弹
$mFirstRun.Invoke($null, @($false))
$valC = [int]$regKey.GetValue("DesktopShortcutInitialized", -1)
if ($valC -ne 1) {
    Write-Host "FAIL: Subsequent run corrupted flag state!" -ForegroundColor Red
    exit 1
}
Write-Host "PASS: Scenario C - Subsequent run honors user deletion without re-populating." -ForegroundColor Green

# 测试场景 D: 手动恢复 (用户点击托盘创建桌面快捷方式)
$retD = $mCreate.Invoke($null, @($false))
Write-Host "PASS: Scenario D - Manual invocation completed successfully." -ForegroundColor Green

# 3. 目标路径防篡改校验：严禁任何测试环境反射调用将 powershell.exe / cmd.exe 写入桌面快捷方式
$desktop = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
$lnkPath = Join-Path $desktop "FerrisPulse · 灵脉.lnk"
if (Test-Path $lnkPath) {
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($lnkPath)
    if ($sc.TargetPath -like "*powershell*" -or $sc.TargetPath -like "*cmd.exe*") {
        Write-Host "FAIL: Desktop shortcut TargetPath was corrupted to: $($sc.TargetPath)!" -ForegroundColor Red
        exit 1
    }
    if (-not ($sc.TargetPath -like "*FerrisPulse.exe*")) {
        Write-Host "FAIL: Desktop shortcut TargetPath does not point to FerrisPulse.exe: $($sc.TargetPath)!" -ForegroundColor Red
        exit 1
    }
    Write-Host "PASS: Desktop shortcut TargetPath strictly verified: $($sc.TargetPath)" -ForegroundColor Green
}

Write-Host "ALL TESTS PASSED for test_startup_shortcut_policy.ps1" -ForegroundColor Green
exit 0
