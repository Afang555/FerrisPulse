# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
# A busy scheduler gate must delay feedback, never discard it.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
$root=Split-Path $PSScriptRoot -Parent
$binary=if($env:FERRISPULSE_TEST_ASSEMBLY){$env:FERRISPULSE_TEST_ASSEMBLY}else{Join-Path $root 'FerrisPulse.exe'}
$asm=[Reflection.Assembly]::Load([IO.File]::ReadAllBytes($binary))
$t=$asm.GetType('RazerBatteryTray.MainForm',$true)
$flags=[Reflection.BindingFlags]'Instance,NonPublic'
$run=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run',$true)
$saved=$run.GetValue('FerrisPulse')
$form=[Activator]::CreateInstance($t,@($false))
try{
 $null=$form.Handle
 $t.GetField('metapandaProfileTimer',$flags).GetValue($form).Stop()
 $gate=$t.GetField('metapandaProfileGate',$flags).GetValue($form)
 $helper=@"
using System;using System.Threading;
public class HeldProfileGate : IDisposable {
 readonly object gate; readonly ManualResetEvent acquired=new ManualResetEvent(false),release=new ManualResetEvent(false); readonly Thread worker;
 public HeldProfileGate(object value){gate=value;worker=new Thread(delegate(){lock(gate){acquired.Set();release.WaitOne();}});worker.IsBackground=true;worker.Start();if(!acquired.WaitOne(1000))throw new Exception("gate not acquired");}
 public void Dispose(){release.Set();worker.Join(1000);acquired.Dispose();release.Dispose();}
}
"@
 Add-Type -TypeDefinition $helper
 $held=New-Object HeldProfileGate($gate)
 try{
  $active=$t.GetMethod('HasActiveMetapandaApplicationProfile',$flags).Invoke($form,@('Metapanda:test'))
  Write-Output "Reproduced: empty service reports ownership=$active while scheduler lock is held"
  $queue=$t.GetMethod('QueueMetapandaManualFeedback',$flags)
  if(!$queue){throw 'Confirmed feedback can be discarded when the scheduler lock is busy'}
  $script:count=0;$action=[Action]{$script:count++}
  $null=$queue.Invoke($form,@('Metapanda:test',$action))
  [Windows.Forms.Application]::DoEvents()
  if($script:count -ne 0){throw 'Feedback bypassed the ownership check while busy'}
 }finally{$held.Dispose()}
 $deadline=[DateTime]::UtcNow.AddSeconds(2)
 while($script:count -eq 0 -and [DateTime]::UtcNow -lt $deadline){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 10}
 if($script:count -ne 1){throw 'First-click feedback was lost instead of retried after the lock was released'}
 $null=$queue.Invoke($form,@('Metapanda:test',$action))
 if($script:count -ne 2){throw 'Uncontended feedback should publish immediately'}
 $held=New-Object HeldProfileGate($gate)
 try{
  $null=$queue.Invoke($form,@('Metapanda:test',[Action]{$script:count+=1}))
  $null=$queue.Invoke($form,@('Metapanda:test',[Action]{$script:count+=10}))
 }finally{$held.Dispose()}
 $deadline=[DateTime]::UtcNow.AddSeconds(2)
 while($script:count -eq 2 -and [DateTime]::UtcNow -lt $deadline){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 10}
 if($script:count -ne 12){throw 'Pending feedback must coalesce to the latest operation for that endpoint'}
 $service=$t.GetField('metapandaProfiles',$flags).GetValue($form)
 $rule=[Activator]::CreateInstance($asm.GetType('RazerBatteryTray.ApplicationMouseProfile'))
 $rule.DeviceId='Metapanda:test';$rule.ExecutablePath='C:\Games\owner.exe';$rule.DpiStage=1;$rule.PollingRate=125
 $service.Profiles.Add($rule)
 $it=$asm.GetType('RazerBatteryTray.MouseBatteryInfo')
 $d=[Activator]::CreateInstance($it);$d.DeviceId='Metapanda:test';$d.IsConnected=$true;$d.DpiStage=1;$d.DpiStages=[int[]]@(800);$d.PollingRate=125
 $lt=[System.Collections.Generic.List``1].MakeGenericType($it);$list=[Activator]::CreateInstance($lt);$list.Add($d)
 $service.Update('C:\Games\owner.exe',$list,[Func[string,int,int,bool]]{return $false})
 if(!$service.HasActiveProfile('Metapanda:test')){throw 'Ownership fixture did not acquire endpoint'}
 $null=$queue.Invoke($form,@('Metapanda:test',[Action]{$script:count+=100}))
 if($script:count -ne 12){throw 'Manual feedback must yield to an actually active application profile'}
 Write-Output 'PASS first-click confirmation survives scheduler contention without a second click'
}finally{$form.Dispose();if($null -eq $saved){$run.DeleteValue('FerrisPulse',$false)}else{$run.SetValue('FerrisPulse',$saved)};$run.Dispose()}