# tests\test_tray_window_restore_animation.ps1
# 验证托盘左键点击唤醒窗口时，窗口状态遵循系统级还原动画规范 (Minimized -> SW_RESTORE -> Normal)
$ErrorActionPreference = "Stop"

$asmPath = Join-Path $PSScriptRoot "..\FerrisPulse.exe"
if (-not (Test-Path $asmPath)) { $asmPath = "FerrisPulse.exe" }
$fullPath = (Resolve-Path $asmPath).Path

# 采用全内存加载模式，严禁独占锁定 exe 文件句柄
$bytes = [System.IO.File]::ReadAllBytes($fullPath)
$asm = [System.Reflection.Assembly]::Load($bytes)

$tMainForm = $asm.GetType("RazerBatteryTray.MainForm")
if ($tMainForm -eq $null) {
    Write-Host "FAIL: Type RazerBatteryTray.MainForm not found" -ForegroundColor Red
    exit 1
}

# 实例化 MainForm(false) - 非自启动模式
$form = [Activator]::CreateInstance($tMainForm, @($false))
[System.Windows.Forms.Form]$winForm = $form

# 触发句柄与窗口加载
$handle = $winForm.Handle
$winForm.Visible = $true

Write-Host "Initial Form State: Visible=$($winForm.Visible), WindowState=$($winForm.WindowState)"

# 1. 测试 ToggleWindow 隐藏行为：窗口应保持 Normal 状态就地 Hide()，严禁设为 Minimized 导致从底部 Dock 栏飞出
$toggleMethod = $tMainForm.GetMethod("ToggleWindow", [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance)
if ($toggleMethod -eq $null) {
    Write-Host "FAIL: Method ToggleWindow not found" -ForegroundColor Red
    exit 1
}

$toggleMethod.Invoke($winForm, $null)
Write-Host "After Toggle (Hide): Visible=$($winForm.Visible), WindowState=$($winForm.WindowState)"

if ($winForm.Visible -ne $false) {
    Write-Host "FAIL: Form is still visible after ToggleWindow hide" -ForegroundColor Red
    exit 1
}

if ($winForm.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
    Write-Host "FAIL: Form WindowState must NOT be Minimized while hidden to prevent flying out from taskbar/dock" -ForegroundColor Red
    exit 1
}

# 2. 测试再次 ToggleWindow（原地弹出窗口）：触发 ShowWindow() -> Windows 原生 DWM 展开 -> Visible
$toggleMethod.Invoke($winForm, $null)
Write-Host "After Toggle (Show): Visible=$($winForm.Visible), WindowState=$($winForm.WindowState)"

if ($winForm.Visible -ne $true) {
    Write-Host "FAIL: Form did not become visible after ToggleWindow show" -ForegroundColor Red
    exit 1
}

if ($winForm.WindowState -ne [System.Windows.Forms.FormWindowState]::Normal) {
    Write-Host "FAIL: Form WindowState did not restore to Normal after show" -ForegroundColor Red
    exit 1
}

$winForm.Close()
$winForm.Dispose()

Write-Host "PASS: Tray window restore animation state machine verified successfully." -ForegroundColor Green
exit 0
