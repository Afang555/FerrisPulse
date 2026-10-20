# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
# Catch refresh overwriting chosen shortcuts, unsupported stale choices and six-rate truncation.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot -Parent
$binary=if($env:FERRISPULSE_TEST_ASSEMBLY){$env:FERRISPULSE_TEST_ASSEMBLY}else{Join-Path $root 'FerrisPulse.exe'}
$asm=[Reflection.Assembly]::Load([IO.File]::ReadAllBytes($binary))
$t=$asm.GetType('RazerBatteryTray.MainForm',$true); $it=$asm.GetType('RazerBatteryTray.MouseBatteryInfo',$true)
$flags=[Reflection.BindingFlags]'Instance,NonPublic'
$run=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run',$true)
$saved=if($run){$run.GetValue('FerrisPulse')}else{$null}
$id='Metapanda:\\?\hid#vid_3554&pid_f5ac&mi_01#shortcut-test-'+[Guid]::NewGuid().ToString('N')
$form=[Activator]::CreateInstance($t,@($false))
try{
 $null=$form.Handle; $info=[Activator]::CreateInstance($it); $info.DeviceId=$id; $info.Brand='Metapanda'; $info.Category=[Enum]::Parse($asm.GetType('RazerBatteryTray.DeviceCategory'),'Mouse')
 $info.DpiStages=[int[]]@(800,1600); $info.DpiStage=2; $info.DpiStageCount=2; $info.Dpi=1600; $info.PollingRate=250
 $info.SupportedPollingRates=[int[]]@(125,250,500,1000,2000,4000); $info.IsConnected=$true
 $t.GetField('selectedDevice',$flags).SetValue($form,$info)
 $update=$t.GetMethod('UpdatePerformanceSection',$flags); $save=$t.GetMethod('SaveCustomPollingRates',$flags)
 $null=$update.Invoke($form,@($info,[Drawing.Color]::Cyan))
 $values=$t.GetField('pollingRateValues',$flags)
 if(($values.GetValue($form)-join ',') -ne '125,1000,4000'){throw 'FAIL: default quick choices must be 125,1000,4000'}
 $null=$save.Invoke($form,@($id,[int[]]@(250,500,2000)))
 foreach($n in 1..3){$null=$update.Invoke($form,@($info,[Drawing.Color]::Cyan))}
 if(($values.GetValue($form)-join ',') -ne '250,500,2000'){throw 'FAIL: device refresh reset saved user shortcuts'}
 $null=$save.Invoke($form,@($id,[int[]]@(125,8000,4000,125)))
 $null=$update.Invoke($form,@($info,[Drawing.Color]::Cyan))
 if(($values.GetValue($form)-join ',') -ne '125,4000'){throw 'FAIL: unsupported or duplicate shortcuts accepted'}
 $null=$save.Invoke($form,@($id,[int[]]@(125,250,500,1000,2000,4000)))
 $null=$update.Invoke($form,@($info,[Drawing.Color]::Cyan))
 if(($values.GetValue($form)-join ',') -ne '125,250,500,1000,2000,4000'){throw 'FAIL: six-rate selection dropped 125 Hz'}
 if($info.PollingRate -ne 250 -or ($info.DpiStages -join ',') -ne '800,1600'){throw 'FAIL: editing shortcuts changed hardware state'}
 Write-Output 'PASS persistent editable rate shortcuts, capability filtering, six-rate retention and unchanged DPI/hardware'
}finally{
 $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\FerrisPulse\CustomPollingRates',$true)
 if($key){$key.DeleteValue($id.Replace('\','_').Replace('/','_'),$false);$key.Dispose()}
 $form.Dispose(); if($run){if($null -ne $saved){$run.SetValue('FerrisPulse',$saved)}else{$run.DeleteValue('FerrisPulse',$false)};$run.Dispose()}
}
