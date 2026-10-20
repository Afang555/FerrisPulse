# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
# Catch missing/replaced voltage samples, culture-dependent CSV and unbounded logs.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$binary=if($env:FERRISPULSE_TEST_ASSEMBLY){$env:FERRISPULSE_TEST_ASSEMBLY}else{Join-Path $root 'FerrisPulse.exe'}
$asm=[Reflection.Assembly]::LoadFrom($binary)
$type=$asm.GetType('RazerBatteryTray.DiagnosticLog')
if(-not $type){throw 'FAIL: persistent diagnostic and battery history recorder is missing'}
$work=Join-Path $root ('tools\scratch\diagnostic-tests\'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work)|Out-Null
$ctor=$type.GetConstructor([Type[]]@([string],[int],[int]))
$log=$ctor.Invoke([object[]]@([string]$work,[int]1048576,[int]3))
$state=New-Object RazerBatteryTray.MouseBatteryInfo
$state.DeviceId='Metapanda:private-hid-path'; $state.IsConnected=$true; $state.BatteryPercent=84; $state.ExactBatteryPercent=84.5
$state.Dpi=1600; $state.DpiY=1600; $state.DpiStage=2; $state.DpiStageCount=2; $state.PollingRate=125
$raw=[byte[]](0x08,0x04,0,0,0,2,0x55,0,0x0f,0xc6,0,0,0,0,0,0,0x1d)
$culture=[Threading.Thread]::CurrentThread.CurrentCulture
try{
 [Threading.Thread]::CurrentThread.CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo('de-DE')
 foreach($n in 1..12){if(-not $log.RecordBattery($state,$raw,'activity',503)){throw 'sample write failed'}}
 $state.BatteryPercent=88; $state.ExactBatteryPercent=88.75; $raw[9]=0xd7; $raw[16]=0x0c
 if(-not $log.RecordBattery($state,$raw,'manual',507)){throw 'changed sample write failed'}
}finally{[Threading.Thread]::CurrentThread.CurrentCulture=$culture}
$csv=Get-Content -LiteralPath (Join-Path $work 'battery.csv') -Raw
$rows=@($csv|ConvertFrom-Csv)
if($rows.Count -ne 13){throw 'FAIL: repeated samples must be retained, not just latest value'}
if($rows[0].voltage_mv -ne '4038' -or $rows[0].device_level -ne '85' -or $rows[0].estimate_percent -ne '84.5' -or $rows[-1].estimate_percent -ne '88.75'){throw 'FAIL: original voltage and independently expected estimates missing'}
if($rows[-1].dpi_x -ne '1600' -or $rows[-1].polling_hz -ne '125' -or $rows[-1].reason -ne 'manual' -or $rows[-1].elapsed_ms -ne '507'){throw 'FAIL: reproduction context missing'}
if($csv.Contains('private-hid-path')){throw 'FAIL: raw device path leaked'}
if(-not $log.Write('setting','target=3 result=confirmed')){throw 'event write failed'}
$smallDir=Join-Path $work 'rotation'
$small=$ctor.Invoke([object[]]@([string]$smallDir,[int]1024,[int]3))
foreach($n in 1..120){if(-not $small.Write('test',('sample='+$n+' '+('x'*80)))){throw 'rotation failed'}}
$files=@(Get-ChildItem -LiteralPath $smallDir -File)
if($files.Count -gt 3 -or @($files|Where-Object Length -gt 1024).Count){throw 'FAIL: logs exceeded configured count/size bound'}
if(-not ((Get-Content -LiteralPath (Join-Path $smallDir 'diagnostic.log') -Raw).Contains('sample=120'))){throw 'FAIL: rotation lost latest event'}
$blocked=Join-Path $work 'blocked'; [IO.File]::WriteAllText($blocked,'file')
$unwritable=$ctor.Invoke([object[]]@([string]$blocked,[int]1024,[int]3))
if($unwritable.Write('test','must not crash')){throw 'FAIL: write failure should be reported safely'}
Write-Output 'PASS persistent battery samples, invariant CSV, privacy, rotation and safe I/O failure'
