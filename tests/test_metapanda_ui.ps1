# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
# Metapanda UI routing contract: prevent cross-device writes and false success.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$hardware = [IO.File]::ReadAllText((Join-Path $root 'src/UI/Forms/MainForm.Hardware.cs'))
$ui = [IO.File]::ReadAllText((Join-Path $root 'src/UI/Forms/MainForm.UI.cs'))
function Assert-Contains($text, $value, $message) {
    if (-not $text.Contains($value)) { throw $message }
}
function Get-Method($text, $name) {
    $match = [regex]::Match($text, '(?m)^        (?:private|public) [^\r\n]+ ' + $name + '\(')
    if (-not $match.Success) { throw "Missing method: $name" }
    $start = $text.IndexOf('{', $match.Index)
    $depth = 1; $end = $start + 1
    while ($depth -gt 0 -and $end -lt $text.Length) {
        if ($text[$end] -eq '{') { $depth++ }
        if ($text[$end] -eq '}') { $depth-- }
        $end++
    }
    return $text.Substring($start, $end - $start)
}
foreach ($name in @('SetDpiFromUI', 'SetPollingRateFromUI', 'ApplyGamePollingRate', 'RestoreDesktopPollingRate', 'ApplyGameDpiStage', 'RestoreDesktopDpiStage', 'StartGameMonitor')) {
    Assert-Contains (Get-Method $hardware $name) 'MetapandaDeviceHelper.IsMetapanda(curDev)' "$name must route Metapanda before vendor fallback"
}
Assert-Contains (Get-Method $ui 'SwitchDpiStageByIndex') 'MetapandaDeviceHelper.IsMetapanda(curDev)' 'Stage buttons need an exact Metapanda route'
Assert-Contains (Get-Method $hardware 'TrySetMetapandaDpiStage') 'if (!SetUnownedMetapandaDpiStage(curDev.DeviceId, targetStage, out confirmed)) return false;' 'Failed DPI writes must never update state'
Assert-Contains (Get-Method $hardware 'TrySetMetapandaDpiStage') 'curDev.DpiStages.Length' 'DPI stage values must come from the selected device'
Assert-Contains (Get-Method $hardware 'SetMetapandaPollingRateFromUI') 'if (!SetUnownedMetapandaPollingRate(curDev.DeviceId, hz, out confirmed)) return;' 'Failed rate writes must never update state'
Assert-Contains (Get-Method $hardware 'StartGameMonitor') 'HasActiveMetapandaApplicationProfile(curDev.DeviceId)' 'App profiles must take precedence over game fallback'
Assert-Contains (Get-Method $ui 'OpenDpiManagementDialog') '仅支持切换已有 DPI 档位' 'DPI management must explain stage-only support'
Assert-Contains (Get-Method $hardware 'UpdatePerformanceSection') 'isMetapandaMouse ? (info.SupportedPollingRates' 'Only confirmed Metapanda rates may be offered'
Assert-Contains (Get-Method $hardware 'UpdatePerformanceSection') 'isMetapandaMouse ? baseSupported' 'Saved custom rate choices must not expose unsupported rates'
Assert-Contains (Get-Method $ui 'UpdatePollingRateDisplayStates') 'currentActiveHz = selectedDevice.PollingRate;' 'Hardware badge must show confirmed state'
Assert-Contains (Get-Method $ui 'RelayoutDpiButtons') 'int count = Math.Min(5, dpiStageList.Count);' 'Unknown DPI tables must not index a fabricated stage'
foreach ($file in @('src/UI/Forms/MainForm.Hardware.cs','src/UI/Forms/MainForm.UI.cs','tests/test_metapanda_ui.ps1')) {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $root $file))
    if ($bytes[0] -ne 239 -or $bytes[1] -ne 187 -or $bytes[2] -ne 191) { throw "Missing UTF-8 BOM: $file" }
}
Write-Host 'PASS: Metapanda manual/game UI routing and capability contracts'

# Set FERRISPULSE_TEST_ASSEMBLY to a freshly compiled application for runtime UI QA.
if ($env:FERRISPULSE_TEST_ASSEMBLY) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $asm = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes($env:FERRISPULSE_TEST_ASSEMBLY))
    $mainType = $asm.GetType('RazerBatteryTray.MainForm', $true)
    $infoType = $asm.GetType('RazerBatteryTray.MouseBatteryInfo', $true)
    $categoryType = $asm.GetType('RazerBatteryTray.DeviceCategory', $true)
    $flags = [Reflection.BindingFlags]'Instance,NonPublic'
    $form = [Activator]::CreateInstance($mainType, @($false))
    try {
        $null = $form.Handle
        $info = [Activator]::CreateInstance($infoType)
        $info.Brand = 'Metapanda'
        $info.DeviceId = 'Metapanda:\\?\hid#vid_3554&pid_f5a9&mi_01#ui-test-missing-device'
        $info.Category = [Enum]::Parse($categoryType, 'Mouse')
        $info.IsConnected = $true
        $info.DpiStages = [int[]]@(400, 800, 1600)
        $info.DpiStage = 2
        $info.DpiStageCount = 3
        $info.Dpi = 800
        $info.PollingRate = 125
        $update = $mainType.GetMethod('UpdatePerformanceSection', $flags)
        $null = $update.Invoke($form, @($info, [Drawing.Color]::Cyan))
        $rates = $mainType.GetField('pollingRateValues', $flags).GetValue($form)
        if (($rates -join ',') -ne '125,1000') { throw 'Runtime UI exposed unsupported rates' }
        $info.DeviceId = 'Metapanda:\\?\hid#vid_3554&pid_f5ac&mi_01#ui-test-missing-device'
        $info.SupportedPollingRates = [int[]]@(125,250,500,1000,2000,4000)
        $mainType.GetField('selectedDevice', $flags).SetValue($form,$info)
        $null = $update.Invoke($form, @($info, [Drawing.Color]::Cyan))
        $rates = $mainType.GetField('pollingRateValues', $flags).GetValue($form)
        if (($rates -join ',') -ne '125,250,500,1000,2000,4000') { throw '4K UI must retain all six rates including 125 and 4000' }
        $buttons = $mainType.GetField('btnRates', $flags).GetValue($form)
        if ($buttons[5].Text -ne '4000 Hz') { throw 'All polling rate buttons must use the full numeric Hz format' }
        $stages = $mainType.GetField('dpiStageValues', $flags).GetValue($form)
        if (($stages -join ',') -ne '400,800,1600') { throw 'Runtime UI lost selected-device DPI stages' }
        $setter = $mainType.GetMethod('TrySetMetapandaDpiStage', $flags)
        if ($setter.Invoke($form, @($info, 1, $false))) { throw 'Missing-device write unexpectedly succeeded' }
        if ($info.Dpi -ne 800 -or $info.DpiStage -ne 2) { throw 'Failed stage write changed UI state' }
        $mainType.GetMethod('SetPollingRateFromUI').Invoke($form, @([int]1000))
        $deadline = [DateTime]::UtcNow.AddMilliseconds(400)
        while ([DateTime]::UtcNow -lt $deadline) {
            [Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 20
        }
        if ($info.PollingRate -ne 125) { throw 'Failed rate write changed hardware state in UI' }
        $info.DpiStages = [int[]]@()
        $info.DpiStageCount = 0
        $info.DpiStage = 0
        $info.Dpi = 0
        $null = $update.Invoke($form, @($info, [Drawing.Color]::Cyan))
        $info.DeviceId = 'Metapanda:\\?\hid#vid_3554&pid_f5ac&mi_01#ui-test-missing-device'
        $info.SupportedPollingRates = [int[]]@(125,250,500,1000,2000,4000)
        $mainType.GetField('selectedDevice', $flags).SetValue($form,$info)
        $null = $update.Invoke($form, @($info, [Drawing.Color]::Cyan))
        $rates = $mainType.GetField('pollingRateValues', $flags).GetValue($form)
        if (($rates -join ',') -ne '125,250,500,1000,2000,4000') { throw '4K UI must retain all six rates including 125 and 4000' }
        $buttons = $mainType.GetField('btnRates', $flags).GetValue($form)
        if ($buttons[5].Text -ne '4000 Hz') { throw 'All polling rate buttons must use the full numeric Hz format' }
        $stages = $mainType.GetField('dpiStageValues', $flags).GetValue($form)
        if ($stages.Length -ne 0) { throw 'Unknown DPI table reused another device stages' }
        Write-Host 'PASS: Runtime Metapanda controls, unknown state, and failed-write state isolation'
    } finally { $form.Dispose() }
} else {
    Write-Host 'SKIP: Runtime UI checks require FERRISPULSE_TEST_ASSEMBLY pointing to a fresh build'
}
foreach ($name in @('TrySetMetapandaDpiStage','SetMetapandaPollingRateFromUI','ApplyGamePollingRate','RestoreDesktopPollingRate')) {
    $method = Get-Method $hardware $name
    if ($name -in @('TrySetMetapandaDpiStage','SetMetapandaPollingRateFromUI')) {
        Assert-Contains $method 'QueueMetapandaManualFeedback(curDev.DeviceId' 'Manual feedback must survive scheduler contention'
        continue
    }
    if ($method -notmatch 'BeginInvoke\(new Action\(\(\) => \{\s*if \([^\r\n]*HasActiveMetapandaApplicationProfile\(curDev.DeviceId\)') { throw "$name must recheck profile ownership in its UI callback" }
    Assert-Contains $method 'HasActiveMetapandaApplicationProfile(curDev.DeviceId)' "$name callbacks must preserve profile-owned UI state"
    if ($method -match 'MetapandaDeviceHelper\.Set(?:DpiStage|PollingRate)\(') { throw "$name bypasses profile gate" }
}
if (($hardware + $ui) -match 'MetapandaDeviceHelper\.Set(?:DpiStage|PollingRate)\(') { throw 'All UI Metapanda writes must use execution-time ownership wrappers' }
Write-Host 'PASS: All Metapanda UI writes and success callbacks honor profile ownership'
