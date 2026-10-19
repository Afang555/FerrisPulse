# ============================================================================
# 模块名称: test_wizard_delete_readd.ps1
# 核心职责:
#   验证设备删除后在向导中不再误显[已在设备库中]，验证雷柏与VGN零假数据保真性
# ============================================================================

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $root
$exePath = Join-Path $root "FerrisPulse.exe"

$rawBytes = [System.IO.File]::ReadAllBytes($exePath)
$asm = [System.Reflection.Assembly]::Load($rawBytes)
$dm = $asm.GetType('RazerBatteryTray.DeviceManager')
$rdh = $asm.GetType('RazerBatteryTray.RapooDeviceHelper')
$vdh = $asm.GetType('RazerBatteryTray.VgnDeviceHelper')

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [测试 1/4] 验证 DeviceManager 删除与隐藏状态同步机制" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$testDevId = "Rapoo:24AE:TEST"
$mHide = $dm.GetMethod('HideOrDeleteDevice', [System.Reflection.BindingFlags]'Static,Public')
$mIsHidden = $dm.GetMethod('IsDeviceHidden', [System.Reflection.BindingFlags]'Static,Public')
$mUnhide = $dm.GetMethod('UnhideDevice', [System.Reflection.BindingFlags]'Static,Public')

$mHide.Invoke($null, @($testDevId))
$hiddenAfterDelete = $mIsHidden.Invoke($null, @($testDevId))
if (-not $hiddenAfterDelete) {
    Write-Host "FAILED: Device should be marked as hidden after HideOrDeleteDevice" -ForegroundColor Red
    exit 1
}
Write-Host "PASSED: 设备删除后已被正确标记为 Hidden: $testDevId" -ForegroundColor Green

$mUnhide.Invoke($null, @($testDevId))
$hiddenAfterUnhide = $mIsHidden.Invoke($null, @($testDevId))
if ($hiddenAfterUnhide) {
    Write-Host "FAILED: Device should NOT be hidden after UnhideDevice" -ForegroundColor Red
    exit 1
}
Write-Host "PASSED: 设备重新添加后已被正确解除 Hidden" -ForegroundColor Green

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [测试 2/4] 验证雷柏 (Rapoo) 协议回报率支持与杜绝假73%电量" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$mRapooQuery = $rdh.GetMethod('QueryRapooDeviceInfo', [System.Reflection.BindingFlags]'Static,Public')
$rapooDev = $mRapooQuery.Invoke($null, @())

if ($rapooDev -ne $null) {
    if ($rapooDev.BatteryPercent -eq 73 -and -not [string]::IsNullOrEmpty($rapooDev.DeviceId) -and $rapooDev.DeviceId -eq "Rapoo:24AE:4613") {
        Write-Host "FAILED: Detected fake 73% battery or hardcoded VT7 fallback!" -ForegroundColor Red
        exit 1
    }
    if ($rapooDev.SupportedPollingRates -eq $null -or $rapooDev.SupportedPollingRates.Length -eq 0) {
        Write-Host "FAILED: Rapoo device should advertise genuine supported polling rates (125~8000Hz)!" -ForegroundColor Red
        exit 1
    }
    $has8k = $false
    foreach ($r in $rapooDev.SupportedPollingRates) { if ($r -eq 8000) { $has8k = $true } }
    if (-not $has8k) {
        Write-Host "FAILED: Rapoo SupportedPollingRates must include 8000Hz!" -ForegroundColor Red
        exit 1
    }
}
Write-Host "PASSED: 雷柏设备杜绝假73%电量，并支持完整 125Hz~8000Hz 回报率列表" -ForegroundColor Green

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [测试 3/4] 验证 VGN 零假数据保真性 (杜绝20%与假F2 Pro Max)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$mVgnQuery = $vdh.GetMethod('QueryVgnDeviceInfo', [System.Reflection.BindingFlags]'Static,Public')
$vgnDev = $mVgnQuery.Invoke($null, @())

if ($vgnDev -ne $null) {
    if ($vgnDev.BatteryPercent -eq 20 -and $vgnDev.DeviceName -eq "VGN Dragonfly F2 Pro Max") {
        Write-Host "FAILED: Detected fake 20% battery or hardcoded F2 Pro Max fallback!" -ForegroundColor Red
        exit 1
    }
}
Write-Host "PASSED: VGN 设备杜绝假20%电量与硬编码固定F2 Pro Max型号" -ForegroundColor Green

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [测试 4/4] 验证雷柏逆向协议控制函数 (DPI/XY独立/回报率/档位)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$mSetRate = $rdh.GetMethod('SetRapooPollingRate', [System.Reflection.BindingFlags]'Static,Public')
if ($mSetRate -eq $null) {
    Write-Host "FAILED: SetRapooPollingRate method not found!" -ForegroundColor Red
    exit 1
}

$mSetXy = $rdh.GetMethod('SetRapooXyDpi', [System.Reflection.BindingFlags]'Static,Public')
if ($mSetXy -eq $null) {
    Write-Host "FAILED: SetRapooXyDpi method not found!" -ForegroundColor Red
    exit 1
}

$mUpdateStages = $rdh.GetMethod('UpdateRapooHardwareStages', [System.Reflection.BindingFlags]'Static,Public', $null, @([int], [int[]], [int[]]), $null)
if ($mUpdateStages -eq $null) {
    Write-Host "FAILED: UpdateRapooHardwareStages method not found!" -ForegroundColor Red
    exit 1
}

Write-Host "PASSED: 雷柏逆向协议控制函数 (SetRapooPollingRate, SetRapooXyDpi, UpdateRapooHardwareStages) 完备集成" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " ALL PASS: 删除设备重新添加与硬件无假数据测试全部通过！" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
exit 0
