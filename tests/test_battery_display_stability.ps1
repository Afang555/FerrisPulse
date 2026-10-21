# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
# Catch unknown-as-low notifications, upward jitter and invalid minima poisoning a discharge session.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$binary=if($env:FERRISPULSE_TEST_ASSEMBLY){$env:FERRISPULSE_TEST_ASSEMBLY}else{Join-Path $root 'FerrisPulse.exe'}
$asm=[Reflection.Assembly]::LoadFrom($binary)
$trackerType=$asm.GetType('RazerBatteryTray.BatteryDisplayTracker')
if(-not $trackerType){throw 'FAIL: valid-only battery display history is missing'}
$tracker=[Activator]::CreateInstance($trackerType)
$infoType=$asm.GetType('RazerBatteryTray.MouseBatteryInfo')
$policy=$asm.GetType('RazerBatteryTray.BatteryAlertPolicy')
function Sample([int]$percent,[bool]$charging=$false,[bool]$sleeping=$false,[string]$id='mouse-a'){
 $d=[Activator]::CreateInstance($infoType);$d.DeviceId=$id;$d.IsConnected=$true;$d.BatteryPercent=$percent;$d.ExactBatteryPercent=$percent;$d.IsCharging=$charging;$d.IsSleeping=$sleeping;return $d
}
foreach($p in @(84,83,84,85)){$d=Sample $p;$tracker.Apply($d);$expected=if($p -eq 84 -and $null -eq $previous){84}else{83};if($d.BatteryPercent -ne $expected){throw 'FAIL: rebound raised the discharge minimum'};$previous=$d.BatteryPercent}
$d=Sample -1;$tracker.Apply($d)
if($d.BatteryPercent -ne 83 -or -not $d.IsBatteryReadingStale){throw 'FAIL: unknown sample erased last valid display'}
if($policy.GetMethod('CanAlert').Invoke($null,@($d))){throw 'FAIL: unknown/stale battery triggered a warning'}
foreach($p in @(0,1)){$d=Sample $p $false $true;$tracker.Apply($d);if($d.BatteryPercent -ne 83 -or -not $d.IsBatteryReadingStale){throw 'FAIL: sleeping zero poisoned the minimum'}}
$d=Sample 84;$tracker.Apply($d);if($d.BatteryPercent -ne 83){throw 'FAIL: wake reset the discharge minimum'}
$d=Sample 50 $false $false 'mouse-b';$tracker.Apply($d);if($d.BatteryPercent -ne 50){throw 'FAIL: endpoint histories leaked'}
$d=Sample 90 $true;$tracker.Apply($d);if($d.BatteryPercent -ne 90){throw 'FAIL: charge did not reset discharge floor'}
$d=Sample 89;$tracker.Apply($d);if($d.BatteryPercent -ne 89){throw 'FAIL: post-charge cycle kept previous low floor'}
foreach($p in @(-1,101)){if($policy.GetMethod('CanAlert').Invoke($null,@((Sample $p)))){throw 'FAIL: invalid battery considered low'}}
foreach($p in @(0,1,20)){if(-not $policy.GetMethod('CanAlert').Invoke($null,@((Sample $p)))){throw 'FAIL: a valid awake low reading must remain alertable'}}
foreach($d in @((Sample 5 $true),(Sample 5 $false $true),(Sample 50))){if($policy.GetMethod('CanAlert').Invoke($null,@($d))){throw 'FAIL: charge/sleep/non-low alert'}}
Write-Output 'PASS valid-only discharge minimum, charge reset, endpoint isolation and low battery eligibility'
