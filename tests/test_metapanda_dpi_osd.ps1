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
function Device($stage,$timestamp){
 $d=[Activator]::CreateInstance($it);$d.DeviceId='Metapanda:\\?\hid#vid_3554&pid_f5ac&mi_01#feedback-missing-endpoint';$d.Brand='Metapanda';$d.Category=[Enum]::Parse($ct,'Mouse');$d.IsConnected=$true;$d.DpiStages=[int[]]@(800,1600);$d.DpiStagesY=[int[]]@(800,1600);$d.DpiStageCount=2;$d.DpiStage=$stage;$d.Dpi=$d.DpiStages[$stage-1];$d.DpiY=$d.Dpi;$d.PollingRate=125;$d.BatteryPercent=85;$d.LastUpdated=$timestamp;return $d
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
 $after=Device 1 ([DateTime]::Now)
 $publish=$t.GetMethod('PublishMetapandaConfirmedState',$flags)
 if(!$publish){throw 'Confirmed hardware state has no immediate complete UI publication path'}
 $t.GetField('dpiOsdEnabled',$flags).SetValue($form,$true)
 $manual=$t.GetMethod('PublishMetapandaManualDpiState',$flags)
 if(!$manual){throw 'Manual Metapanda DPI confirmation does not reach OSD notification'}
 $osd=$t.GetField('osdForm',$flags).GetValue($form)
 $visible=$asm.GetType('RazerBatteryTray.NativeMethods',$true).GetMethod('IsWindowVisible')
 $null=$manual.Invoke($form,@($after))
 if(!$visible.Invoke($null,@($osd.Handle))){throw 'Confirmed manual DPI must display the enabled OSD'}
 if($osd.GetType().GetField('currentDpi',$flags).GetValue($osd) -ne 800){throw 'OSD did not use confirmed hardware DPI'}
 if($osd.GetType().GetField('currentStage',$flags).GetValue($osd) -ne 1){throw 'OSD did not use confirmed stage'}
 $buttons=$t.GetField('btnDpiStages',$flags).GetValue($form)
 if(!$buttons[0].Selected -or $buttons[1].Selected){throw 'OSD and button highlighter disagree'}
 $osd.HideOsd();$t.GetField('dpiOsdEnabled',$flags).SetValue($form,$false)
 $after2=Device 2 ([DateTime]::Now.AddSeconds(1))
 $null=$manual.Invoke($form,@($after2))
 if($visible.Invoke($null,@($osd.Handle))){throw 'Disabled OSD option must remain silent'}
 $t.GetField('dpiOsdEnabled',$flags).SetValue($form,$true)
 $null=$manual.Invoke($form,@($after))
 if($visible.Invoke($null,@($osd.Handle))){throw 'Stale rejected confirmation must not show an obsolete OSD'}
 Write-Output 'PASS manual confirmed DPI OSD, matching button state, disabled preference and stale callback rejection'
}finally{
 if($osd){$osd.Dispose()}
 $form.Dispose()
 if($runKey){if($null -ne $savedRun){$runKey.SetValue('FerrisPulse',$savedRun)}else{$runKey.DeleteValue('FerrisPulse',$false)};$runKey.Dispose()}
}