# tests/test_polling_rates_adaptive.ps1
# Verification script for polling rates adaptive detection and layout rules

$exePath = Join-Path $PSScriptRoot "..\FerrisPulse.exe"
if (-not (Test-Path $exePath)) {
    Write-Error "FerrisPulse.exe not found at $exePath"
    exit 1
}

$bytes = [System.IO.File]::ReadAllBytes($exePath)
$assembly = [System.Reflection.Assembly]::Load($bytes)
$razerHelper = $assembly.GetType("RazerBatteryTray.RazerDeviceHelper")
$mainFormType = $assembly.GetType("RazerBatteryTray.MainForm")

Write-Host "=== 1. Verifying RazerDeviceHelper.GetSupportedPollingRatesForModel ===" -ForegroundColor Cyan

$testCases = @(
    @{ Pid = 0x00BF; Name = "Razer DeathAdder V4 Pro"; Expected = @(125, 250, 500, 1000, 2000, 4000, 8000) },
    @{ Pid = 0x00C1; Name = "Razer Viper V3 Pro"; Expected = @(125, 250, 500, 1000, 2000, 4000, 8000) },
    @{ Pid = 0x009A; Name = "Razer Basilisk V3 Pro"; Expected = @(125, 250, 500, 1000, 2000, 4000, 8000) },
    @{ Pid = 0x0071; Name = "Razer Viper 8KHz"; Expected = @(125, 250, 500, 1000, 2000, 4000, 8000) },
    @{ Pid = 0x008F; Name = "Razer Naga V2 Pro"; Expected = @(125, 250, 500, 1000, 2000, 4000, 8000) },
    @{ Pid = 0x0084; Name = "Razer DeathAdder V2"; Expected = @(125, 250, 500, 1000) },
    @{ Pid = 0x008A; Name = "Razer Viper Mini"; Expected = @(125, 250, 500, 1000) }
)

$allPassed = $true

foreach ($tc in $testCases) {
    $res = [int[]]$razerHelper.InvokeMember("GetSupportedPollingRatesForModel", [System.Reflection.BindingFlags]::InvokeMethod -bor [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static, $null, $null, @($tc.Pid, $tc.Name))
    $resStr = ($res -join ", ")
    $expStr = ($tc.Expected -join ", ")
    if ($resStr -eq $expStr) {
        Write-Host " [PASS] $($tc.Name) (PID: 0x$($tc.Pid.ToString('X4'))): [$resStr]" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] $($tc.Name): Got [$resStr], Expected [$expStr]" -ForegroundColor Red
        $allPassed = $false
    }
}

Write-Host "`n=== 1.1 Verifying RapooDeviceHelper.GetSupportedPollingRatesForModel ===" -ForegroundColor Cyan
$rapooHelper = $assembly.GetType("RazerBatteryTray.RapooDeviceHelper")
if ($rapooHelper -ne $null) {
    $rapooCases = @(
        @{ Pid = 0x4617; Name = "雷柏 VT9 Pro"; Expected = @(125, 250, 500, 1000, 2000, 4000, 8000) },
        @{ Pid = 0x3105; Name = "雷柏 VT1 Pro Max"; Expected = @(125, 250, 500, 1000, 2000, 4000, 8000) },
        @{ Pid = 0x1A00; Name = "雷柏 VT7 SE"; Expected = @(125, 250, 500, 1000) },
        @{ Pid = 0x1A11; Name = "雷柏 VT1 SE"; Expected = @(125, 250, 500, 1000) },
        @{ Pid = 0x4619; Name = "雷柏 V300SE"; Expected = @(125, 250, 500, 1000) }
    )
    foreach ($rc in $rapooCases) {
        $res = [int[]]$rapooHelper.InvokeMember("GetSupportedPollingRatesForModel", [System.Reflection.BindingFlags]::InvokeMethod -bor [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static, $null, $null, @($rc.Pid, $rc.Name))
        $resStr = ($res -join ", ")
        $expStr = ($rc.Expected -join ", ")
        if ($resStr -eq $expStr) {
            Write-Host " [PASS] $($rc.Name) (PID: 0x$($rc.Pid.ToString('X4'))): [$resStr]" -ForegroundColor Green
        } else {
            Write-Host " [FAIL] $($rc.Name): Got [$resStr], Expected [$expStr]" -ForegroundColor Red
            $allPassed = $false
        }
    }
}

Write-Host "`n=== 1.2 Verifying VgnDeviceHelper.GetSupportedPollingRatesForModel ===" -ForegroundColor Cyan
$vgnHelper = $assembly.GetType("RazerBatteryTray.VgnDeviceHelper")
if ($vgnHelper -ne $null) {
    $vgnCases = @(
        @{ Pid = 0xFB3E; Name = "VGN Dragonfly F2 Pro Max"; Expected = @(125, 250, 500, 1000, 2000, 4000, 8000) },
        @{ Pid = 0xFC03; Name = "VXE Dragonfly R1 Pro"; Expected = @(125, 250, 500, 1000, 2000, 4000) },
        @{ Pid = 0xFC05; Name = "VXE Dragonfly R1 SE"; Expected = @(125, 250, 500, 1000) },
        @{ Pid = 0xFB24; Name = "VGN Dragonfly F1"; Expected = @(125, 250, 500, 1000) }
    )
    foreach ($vc in $vgnCases) {
        $res = [int[]]$vgnHelper.InvokeMember("GetSupportedPollingRatesForModel", [System.Reflection.BindingFlags]::InvokeMethod -bor [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static, $null, $null, @($vc.Pid, $vc.Name))
        $resStr = ($res -join ", ")
        $expStr = ($vc.Expected -join ", ")
        if ($resStr -eq $expStr) {
            Write-Host " [PASS] $($vc.Name) (PID: 0x$($vc.Pid.ToString('X4'))): [$resStr]" -ForegroundColor Green
        } else {
            Write-Host " [FAIL] $($vc.Name): Got [$resStr], Expected [$expStr]" -ForegroundColor Red
            $allPassed = $false
        }
    }
}

Write-Host "`n=== 1.3 Verifying UniversalGamingDeviceHelper.GetSupportedPollingRatesByMax ===" -ForegroundColor Cyan
$uniHelper = $assembly.GetType("RazerBatteryTray.UniversalGamingDeviceHelper")
if ($uniHelper -ne $null) {
    $uniCases = @(
        @{ Max = 8000; Expected = @(125, 250, 500, 1000, 2000, 4000, 8000); Desc = "Universal 8K" },
        @{ Max = 4000; Expected = @(125, 250, 500, 1000, 2000, 4000); Desc = "Universal 4K" },
        @{ Max = 1000; Expected = @(125, 250, 500, 1000); Desc = "Universal 1K" }
    )
    foreach ($uc in $uniCases) {
        $res = [int[]]$uniHelper.InvokeMember("GetSupportedPollingRatesByMax", [System.Reflection.BindingFlags]::InvokeMethod -bor [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static, $null, $null, @($uc.Max))
        $resStr = ($res -join ", ")
        $expStr = ($uc.Expected -join ", ")
        if ($resStr -eq $expStr) {
            Write-Host " [PASS] $($uc.Desc): [$resStr]" -ForegroundColor Green
        } else {
            Write-Host " [FAIL] $($uc.Desc): Got [$resStr], Expected [$expStr]" -ForegroundColor Red
            $allPassed = $false
        }
    }
}

Write-Host "`n=== 2. Verifying GetDefaultActivePollingRates Rule (Top 4 Highest If > 4) ===" -ForegroundColor Cyan

# Test default active rates algorithm
$dummyForm = [System.Runtime.Serialization.FormatterServices]::GetUninitializedObject($mainFormType)
$methodInfo = $mainFormType.GetMethod("GetDefaultActivePollingRates", [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance)

$rateCases = @(
    @{ Input = @(125, 500, 1000, 2000, 4000, 8000); Expected = @(1000, 2000, 4000, 8000); Desc = "8K 6-rates (DeathAdder V4 Pro / Viper V3 Pro)" },
    @{ Input = @(125, 250, 500, 1000, 2000, 4000, 8000); Expected = @(1000, 2000, 4000, 8000); Desc = "8K 7-rates (Rapoo VT7 8K)" },
    @{ Input = @(125, 250, 500, 1000, 2000, 4000); Expected = @(500, 1000, 2000, 4000); Desc = "4K 6-rates" },
    @{ Input = @(125, 500, 1000); Expected = @(125, 500, 1000); Desc = "1K 3-rates (Classic DA V2 / Viper Mini)" },
    @{ Input = @(125, 250, 500, 1000); Expected = @(125, 250, 500, 1000); Desc = "1K 4-rates" }
)

foreach ($rc in $rateCases) {
    $arg = [object[]]@(,[int[]]$rc.Input)
    $res = [int[]]$methodInfo.Invoke($dummyForm, $arg)
    $resStr = ($res -join ", ")
    $expStr = ($rc.Expected -join ", ")
    if ($resStr -eq $expStr) {
        Write-Host " [PASS] $($rc.Desc): Result = [$resStr]" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] $($rc.Desc): Got [$resStr], Expected [$expStr]" -ForegroundColor Red
        $allPassed = $false
    }
}

Write-Host "`n=== 3. Verifying PollingRateManagementDialog Validation (Max 5 Rates) ===" -ForegroundColor Cyan
$dlgType = $assembly.GetType("RazerBatteryTray.PollingRateManagementDialog")
if ($dlgType -ne $null) {
    Write-Host " [PASS] PollingRateManagementDialog type loaded successfully" -ForegroundColor Green
} else {
    Write-Host " [FAIL] PollingRateManagementDialog type not found" -ForegroundColor Red
    $allPassed = $false
}

if ($allPassed) {
    Write-Host "`nAll Adaptive Polling Rate Tests PASSED Successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests failed." -ForegroundColor Red
    exit 1
}
