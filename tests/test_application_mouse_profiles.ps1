# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
# C# 5 / .NET 4 behavior harness; UTF-8 BOM required.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$work = Join-Path ([IO.Path]::GetTempPath()) ('FerrisPulseProfiles-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
$harness = @'
using System;
using System.IO;
using System.Collections.Generic;
using RazerBatteryTray;
namespace RazerBatteryTray {
 public class MouseBatteryInfo { public string DeviceId, DisplayName, Transport; public bool IsConnected; public int DpiStage,PollingRate; public int[] DpiStages, DpiStagesY, SupportedPollingRates; }
}
class ProfileTests {
 static void Check(bool b,string m) { if(!b) throw new Exception(m); }
 static ApplicationMouseProfile Rule(string id) { return new ApplicationMouseProfile {ExecutablePath=@"C:\Games\game.exe",DeviceId=id,DpiStage=2,PollingRate=1000,Enabled=true}; }
 static MouseBatteryInfo Device(string id) { return new MouseBatteryInfo {DeviceId=id,IsConnected=true,DpiStage=1,PollingRate=125,DpiStages=new int[]{800,1600}}; }
 static int Main(string[] args) { try {
 // A prior success cannot suppress correction after an observed physical/settings change.
 var drift=new ApplicationMouseProfileService(Path.Combine(args[0],"drift.xml"));
 drift.Profiles.Add(Rule("Metapanda:drift"));
 var driftDevice=Device("Metapanda:drift");
 var driftDevices=new List<MouseBatteryInfo>{driftDevice}; int driftCalls=0;
 Func<string,int,int,bool> driftApply=delegate(string id,int stage,int hz) {
   driftCalls++; driftDevice.DpiStage=stage; driftDevice.PollingRate=hz; return true;
 };
 drift.Update(@"C:\Games\game.exe",driftDevices,driftApply);
 drift.Update(@"C:\Games\game.exe",driftDevices,driftApply);
 Check(driftCalls==1,"matching fresh observation suppresses duplicate writes");
 driftDevice.DpiStage=1;
 drift.Update(@"C:\Games\game.exe",driftDevices,driftApply);
 Check(driftCalls==2 && driftDevice.DpiStage==2,"observed DPI drift reapplies cached profile");
 driftDevice.PollingRate=125;
 drift.Update(@"C:\Games\game.exe",driftDevices,driftApply);
 Check(driftCalls==3 && driftDevice.PollingRate==1000,"observed rate drift reapplies cached profile");
 drift.RestoreAll(driftDevices,driftApply);
 Check(driftDevice.DpiStage==1 && driftDevice.PollingRate==125,"drift correction preserves original desktop snapshot");
 string file=Path.Combine(args[0],"profiles.xml");
 var s=new ApplicationMouseProfileService(file); s.Profiles.Add(Rule("Metapanda:A")); s.Profiles.Add(Rule("Metapanda:B"));
 Check(s.Resolve(@"c:\games\GAME.EXE","Metapanda:A")!=null,"case insensitive complete path");
 Check(s.Resolve(@"D:\Games\game.exe","Metapanda:A")==null,"same basename must not match");
 Check(s.Resolve(@"C:\Games\game.exe","Metapanda:a")==null,"endpoint key exact");
 s.Profiles.Add(new ApplicationMouseProfile {ExecutablePath="game.exe",DeviceId="Metapanda:A",DpiStage=1,PollingRate=125,Enabled=true});
 s.Profiles.Add(new ApplicationMouseProfile {ExecutablePath=@"C:\bad.exe",DeviceId="VGN:A",DpiStage=1,PollingRate=125,Enabled=true});
 s.Save(); var copy=new ApplicationMouseProfileService(file); copy.Load();
 Check(copy.Profiles.Count==2,"invalid entries rejected on save/load");
 Check(copy.Resolve(@"C:\Games\game.exe","Metapanda:B").DpiStage==2,"per endpoint persisted");
 int calls=0; string last=""; bool success=false;
 var devices=new List<MouseBatteryInfo>{Device("Metapanda:A"),Device("VGN:A")};
 Func<string,int,int,bool> apply=delegate(string id,int stage,int hz) {
   calls++;last=id+":"+stage+":"+hz;
   if(success) foreach(var device in devices) if(device.DeviceId==id) {device.DpiStage=stage;device.PollingRate=hz;}
   return success;
 };
 s.Update(@"C:\Games\game.exe",devices,apply); Check(calls==1 && s.HasActiveProfile("Metapanda:A"),"failed apply owns device and may retry");
 success=true; s.Update(@"C:\Games\game.exe",devices,apply); Check(calls==2 && last=="Metapanda:A:2:1000","retry failed callback");
 s.Update(@"C:\Games\game.exe",devices,apply); Check(calls==2,"successful duplicate suppressed");
 success=false; s.Update(@"C:\other.exe",devices,apply); Check(calls==3 && s.HasActiveProfile("Metapanda:A"),"restore failure retains ownership");
 success=true; s.Update(@"C:\other.exe",devices,apply); Check(calls==4 && last=="Metapanda:A:1:125" && !s.HasActiveProfile("Metapanda:A"),"restore desktop and release");
 devices[0].DpiStage=0; s.Update(@"C:\Games\game.exe",devices,apply); Check(calls==4,"unknown desktop blocks automatic control");
 devices[0].DpiStage=1; devices[0].DpiStages=new int[]{800}; s.Update(@"C:\Games\game.exe",devices,apply); Check(calls==4,"absent stage blocks control");
 devices[0].DpiStages=new int[]{800,1600}; s.Update(@"C:\Games\game.exe",devices,apply); Check(calls==5,"known valid stages activate");
 devices[0].IsConnected=false; s.Update(@"C:\other.exe",devices,apply); Check(calls==5 && !s.HasActiveProfile("Metapanda:A"),"disconnect forgets endpoint without write");
 // A failed restore may partially change hardware. Returning to the previous profile must reapply.
 devices[0].IsConnected=true; devices[0].DpiStage=1; devices[0].PollingRate=125; s.Update(@"C:\Games\game.exe",devices,apply);
 success=false; s.Update(@"C:\other.exe",devices,apply); int failedRestoreCalls=calls;
 success=true; s.Update(@"C:\Games\game.exe",devices,apply);
 Check(calls==failedRestoreCalls+1 && last=="Metapanda:A:2:1000","return to profile after partial restore retries");
 int activeCalls=calls; s.Update(null,devices,apply); Check(calls==activeCalls && s.HasActiveProfile("Metapanda:A"),"foreground query failure retains ownership");
 s.Profiles[0].Enabled=false; s.Update(@"C:\Games\game.exe",devices,apply);
 Check(!s.HasActiveProfile("Metapanda:A") && last=="Metapanda:A:1:125","disabling active rule restores desktop");
 s.Profiles[0].Enabled=true;
 devices.Add(Device("Metapanda:B")); s.Update(@"C:\Games\game.exe",devices,apply);
 Check(last=="Metapanda:B:2:1000" && s.HasActiveProfile("Metapanda:A") && s.HasActiveProfile("Metapanda:B"),"identical devices remain isolated");
 s.Profiles[1].PollingRate=8000; s.Update(@"C:\Games\game.exe",devices,apply);
 Check(!s.HasActiveProfile("Metapanda:B") && s.HasActiveProfile("Metapanda:A"),"invalid rate releases only target endpoint");
 s.Update(@"C:\other.exe",devices,delegate {throw new IOException("fake disconnected write");});
 Check(s.HasActiveProfile("Metapanda:A"),"callback exception retains pending restore");
 s.Update(@"C:\other.exe",devices,apply); Check(!s.HasActiveProfile("Metapanda:A"),"exception restore retried");
 s.Update(@"C:\Games\game.exe",devices,apply); int exitCalls=calls;
 s.RestoreAll(devices,apply);
 Check(calls==exitCalls+1 && last=="Metapanda:A:1:125" && !s.HasActiveProfile("Metapanda:A"),"explicit exit restores active snapshot");
 copy.Save(); copy.Load(); Check(copy.Profiles.Count==2,"atomic replacement preserves valid rules");
 File.WriteAllText(file,"<!DOCTYPE p [<!ENTITY x SYSTEM 'file:///C:/Windows/win.ini'>]><profiles>&x;</profiles>");
 copy.Load(); Check(copy.Profiles.Count==0,"unsafe/corrupt XML handled as no rules");
 using(var dialog = new ApplicationMouseProfilesDialog(devices,s)) {
  dialog.PerformLayout(); System.Windows.Forms.DataGridView table=null; System.Windows.Forms.FlowLayoutPanel buttons=null;
  foreach(System.Windows.Forms.Control control in dialog.Controls) {
   if(control is System.Windows.Forms.DataGridView) table=(System.Windows.Forms.DataGridView)control;
   if(control is System.Windows.Forms.FlowLayoutPanel) buttons=(System.Windows.Forms.FlowLayoutPanel)control;
  }
  Check(table!=null && buttons!=null && table.Bottom<=buttons.Top,"rule table must not cover save/add buttons");
 }
 Console.WriteLine("PASS: application profiles exact matching, persistence, validation, restore/retry, disconnect, duplicate suppression"); return 0;
 } catch(Exception e){Console.Error.WriteLine(e);return 1;} }
}
'@
$source=Join-Path $work 'ProfileTests.cs'
[IO.File]::WriteAllText($source,$harness,(New-Object Text.UTF8Encoding($true)))
$files=@('src/Models/ApplicationMouseProfile.cs','src/Services/ApplicationMouseProfileService.cs','src/UI/Forms/ApplicationMouseProfilesDialog.cs') | ForEach-Object {Join-Path $root $_}
foreach($file in $files) { if(!(Test-Path $file)) {throw "Missing profiles feature: $file"} }
$csc=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$exe=Join-Path $work 'ProfileTests.exe'
& $csc /nologo /codepage:65001 /r:System.Windows.Forms.dll /r:System.Drawing.dll "/out:$exe" $source $files
if($LASTEXITCODE -ne 0){throw 'Profile harness compilation failed'}
& $exe $work
if($LASTEXITCODE -ne 0){throw 'Profile behavior tests failed'}
} finally { Remove-Item -LiteralPath $work -Recurse -Force }
