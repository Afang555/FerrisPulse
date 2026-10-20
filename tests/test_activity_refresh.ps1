# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
# Catch movement flood, stale slow intervals and overlapping device reads.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$binary=if($env:FERRISPULSE_TEST_ASSEMBLY){$env:FERRISPULSE_TEST_ASSEMBLY}else{Join-Path $root 'FerrisPulse.exe'}
$asm=[Reflection.Assembly]::LoadFrom($binary)
$type=$asm.GetType('RazerBatteryTray.ActivityRefreshSchedule')
if(-not $type){throw 'FAIL: activity-driven bounded refresh scheduler is missing'}
$s=[Activator]::CreateInstance($type)
if(-not $s.TryBegin(10000,$false,$false)){throw 'initial refresh missing'}
if($s.TryBegin(20000,$true,$true)){throw 'overlapping refresh allowed'}
$s.Complete()
if($s.TryBegin(10999,$true,$true)){throw 'movement flood not throttled'}
if(-not $s.TryBegin(11000,$true,$false)){throw 'visible window still waits for slow battery timer'}
$s.Complete()
if($s.TryBegin(12000,$false,$false)){throw 'idle device should use slower polling'}
if(-not $s.TryBegin(12000,$false,$true)){throw 'mouse activity did not accelerate next read'}
$s.Complete()
if(-not $s.TryBegin(17000,$false,$false)){throw 'idle five-second heartbeat missing'}
$s.Complete()
Write-Output 'PASS visible/activity refresh latency, idle cadence, flood throttle and single in-flight read'
