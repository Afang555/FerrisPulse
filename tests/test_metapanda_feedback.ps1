# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
# Confirmed HID state must replace stale UI references without a background refresh.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot -Parent
$binary=if($env:FERRISPULSE_TEST_ASSEMBLY){$env:FERRISPULSE_TEST_ASSEMBLY}else{Join-Path $root 'FerrisPulse.exe'}
$asm=[Reflection.Assembly]::Load([IO.File]::ReadAllBytes($binary))
$t=$asm.GetType('RazerBatteryTray.MainForm',$true)
$it=$asm.GetType('RazerBatteryTray.MouseBatteryInfo',$true)
$ct=$asm.GetType('RazerBatteryTray.DeviceCategory',$true)
$flags=[Reflection.BindingFlags]'Instance,NonPublic'
function Device($stage,$timestamp,$battery=85){
 $d=[Activator]::CreateInstance($it);$d.DeviceId='Metapanda:\\?\hid#vid_3554&pid_f5ac&mi_01#feedback-missing-endpoint';$d.Brand='Metapanda';$d.Category=[Enum]::Parse($ct,'Mouse');$d.IsConnected=$true;$d.DpiStages=[int[]]@(800,1600);$d.DpiStagesY=[int[]]@(800,1600);$d.DpiStageCount=2;$d.DpiStage=$stage;$d.Dpi=$d.DpiStages[$stage-1];$d.DpiY=$d.Dpi;$d.PollingRate=125;$d.BatteryPercent=$battery;$d.ExactBatteryPercent=$battery;$d.LastUpdated=$timestamp;return $d
}
$runKey=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run',$true)
$savedRun=if($runKey){$runKey.GetValue('FerrisPulse')}else{$null}
$form=[Activator]::CreateInstance($t,@($false))
try {
 $null=$form.Handle
 $listType=[System.Collections.Generic.List``1].MakeGenericType($it)
 $list=[Activator]::CreateInstance($listType)
 $old=Device 2 ([DateTime]::Now.AddSeconds(-20));$old.CustomName='My Mouse';$old.IsPrimary=$true;$list.Add($old)
 $t.GetField('activeDevices',$flags).SetValue($form,$list)
 $t.GetField('selectedDevice',$flags).SetValue($form,$old)
 $t.GetField('lastInfo',$flags).SetValue($form,$old)
 $after=Device 1 ([DateTime]::Now) 84
 $publish=$t.GetMethod('PublishMetapandaConfirmedState',$flags)
 if(!$publish){throw 'Confirmed hardware state has no immediate complete UI publication path'}
 $sw=[Diagnostics.Stopwatch]::StartNew();$null=$publish.Invoke($form,@($after));$sw.Stop()
 $selected=$t.GetField('selectedDevice',$flags).GetValue($form)
 if($selected.DpiStage -ne 1 -or $selected.Dpi -ne 800){throw 'Current selection kept the old device object'}
 if($t.GetField('lastInfo',$flags).GetValue($form).Dpi -ne 800 -or $list[0].Dpi -ne 800){throw 'Tray/list retained the old DPI'}
 if($selected.CustomName -ne 'My Mouse' -or !$selected.IsPrimary){throw 'Confirmed readback lost device preferences'}
 if($selected.BatteryPercent -ne 84 -or $t.GetField('lblBatteryBig',$flags).GetValue($form).Text -notmatch '84' -or $t.GetField('lastInfo',$flags).GetValue($form).BatteryPercent -ne 84){throw 'Confirmed battery did not reach current selection, label and tray state'}
 $buttons=$t.GetField('btnDpiStages',$flags).GetValue($form)
 if(!$buttons[0].Selected -or $buttons[1].Selected){throw 'DPI buttons were not synchronized immediately'}
 $staleList=[Activator]::CreateInstance($listType);$staleList.Add((Device 2 ([DateTime]::Now.AddSeconds(-10))))
 $null=$t.GetMethod('ApplyDeviceStatus',$flags).Invoke($form,@($staleList,$false))
 if($t.GetField('selectedDevice',$flags).GetValue($form).Dpi -ne 800){throw 'Older full-scan snapshot overwrote confirmed DPI'}
 $newList=[Activator]::CreateInstance($listType);$newList.Add((Device 2 ([DateTime]::Now.AddSeconds(1)) 83))
 $null=$t.GetMethod('ApplyDeviceStatus',$flags).Invoke($form,@($newList,$false))
 if($t.GetField('selectedDevice',$flags).GetValue($form).Dpi -ne 1600){throw 'Newer physical change must still be observed'}
 if($t.GetField('lblBatteryBig',$flags).GetValue($form).Text -notmatch '83' -or $t.GetField('lastInfo',$flags).GetValue($form).BatteryPercent -ne 83){throw 'Fresh battery scan was frozen by an earlier DPI confirmation'}
 $null=$publish.Invoke($form,@($after))
 if($t.GetField('selectedDevice',$flags).GetValue($form).Dpi -ne 1600){throw 'Late older write callback overwrote newer physical state'}
 if($t.GetField('selectedDevice',$flags).GetValue($form).BatteryPercent -ne 83){throw 'Late older write callback overwrote fresh battery'}
 $observed=$t.GetMethod('PublishMetapandaObservedState',$flags)
 if(!$observed){throw 'Activity refresh has no timestamp-safe UI publication path'}
 $physical=Device 1 ([DateTime]::Now.AddSeconds(2)) 82
 $null=$observed.Invoke($form,@($physical))
 if($t.GetField('selectedDevice',$flags).GetValue($form).Dpi -ne 800 -or $t.GetField('lblBatteryBig',$flags).GetValue($form).Text -notmatch '82'){throw 'Activity observation did not update DPI and battery together'}
 $null=$observed.Invoke($form,@($after))
 if($t.GetField('selectedDevice',$flags).GetValue($form).BatteryPercent -ne 82){throw 'Late activity observation rolled battery backward'}
 if($sw.ElapsedMilliseconds -gt 1000){throw 'UI publication must not wait for HID or the refresh timer'}
 Write-Output "PASS immediate confirmed UI feedback, stale-scan isolation, fresh physical state; publish=$($sw.ElapsedMilliseconds)ms"
}finally{
 $form.Dispose()
 if($runKey){if($null -ne $savedRun){$runKey.SetValue('FerrisPulse',$savedRun)}else{$runKey.DeleteValue('FerrisPulse',$false)};$runKey.Dispose()}
}
