# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
# Real compiled model/service/editor behavior, no HID traffic.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$work=Join-Path $root 'tools/scratch/flexible-tests'
[IO.Directory]::CreateDirectory($work) | Out-Null
$binary=if($env:FERRISPULSE_TEST_ASSEMBLY){$env:FERRISPULSE_TEST_ASSEMBLY}else{Join-Path $root 'FerrisPulse.exe'}
Copy-Item $binary (Join-Path $work 'FerrisPulse.exe') -Force
$harness=@"
using System;
using System.IO;
using System.Collections.Generic;
using System.Reflection;
using System.Windows.Forms;
using RazerBatteryTray;
class FlexibleTests {
 static void Check(bool b,string s){if(!b){Console.Error.WriteLine("FAIL: "+s);Environment.Exit(1);}}
 static void Dpi(ApplicationMouseProfile p,int v){var property=typeof(ApplicationMouseProfile).GetProperty("DpiValue");Check(property!=null,"DPI value mode exists");property.SetValue(p,v,null);}
 static int Dpi(ApplicationMouseProfile p){return (int)typeof(ApplicationMouseProfile).GetProperty("DpiValue").GetValue(p,null);}
 static ApplicationMouseProfile Rule(){var p=new ApplicationMouseProfile{ExecutablePath=@"C:\Games\game.exe",DeviceId="Metapanda:4k",DpiStage=0,PollingRate=4000};Dpi(p,800);return p;}
 static MouseBatteryInfo Device(){return new MouseBatteryInfo{DeviceId="Metapanda:4k",IsConnected=true,DpiStage=3,PollingRate=125,DpiStages=new int[]{800,1200,1600},DpiStagesY=new int[]{800,1200,1600},SupportedPollingRates=new int[]{125,250,500,1000,2000,4000}};}
 static void Main(string[] args){try{
 string file=Path.Combine(args[0],"profiles.xml");
 var service=new ApplicationMouseProfileService(file);var rule=Rule();Check(rule.IsValid(),"4K value rule is valid");
 rule.DpiStage=2;Check(!rule.IsValid(),"ambiguous stage and value rejected");rule.DpiStage=0;
 var d=Device();var devices=new List<MouseBatteryInfo>{d};service.Profiles.Add(rule);
 int calls=0,lastStage=0,lastRate=0;
 Func<string,int,int,bool> apply=delegate(string id,int stage,int rate){Check(id==d.DeviceId,"exact endpoint identity");calls++;lastStage=stage;lastRate=rate;d.DpiStage=stage;d.PollingRate=rate;return true;};
 service.Update(@"C:\Games\game.exe",devices,apply);Check(lastStage==1&&lastRate==4000,"game 800/4000 matches stage1");
 service.Update(@"C:\Games\game.exe",devices,apply);Check(calls==1,"suppress duplicate value writes");
 service.Update(@"C:\Office\office.exe",devices,apply);Check(lastStage==3&&lastRate==125&&!service.HasActiveProfile(d.DeviceId),"restore office 1600/125");
 Dpi(rule,1600);service.Update(@"C:\Games\game.exe",devices,apply);Check(lastStage==3,"1600 resolves third stage");
 d.DpiStages=new int[]{1600,800,1200};d.DpiStagesY=new int[]{1600,800,1200};service.Update(@"C:\Games\game.exe",devices,apply);Check(lastStage==1,"value mode follows reordered table");
 service.RestoreAll(devices,apply);Check(d.DpiStages[d.DpiStage-1]==1600&&d.PollingRate==125,"restore baseline DPI after stage table reorder");
 var missing=new ApplicationMouseProfileService(Path.Combine(args[0],"missing.xml"));var missingRule=Rule();Dpi(missingRule,2000);missing.Profiles.Add(missingRule);int before=calls;missing.Update(@"C:\Games\game.exe",devices,apply);Check(calls==before&&!missing.HasActiveProfile(d.DeviceId),"missing DPI never guesses a stage");
 Dpi(missingRule,1600);d.DpiStagesY[0]=800;missing.Update(@"C:\Games\game.exe",devices,apply);Check(calls==before,"symmetric DPI does not match independent Y");d.DpiStagesY[0]=1600;
 d.SupportedPollingRates=new int[]{125,1000};missing.Update(@"C:\Games\game.exe",devices,apply);Check(calls==before,"1K endpoint rejects 4000 before write");
 d.SupportedPollingRates=new int[]{125,250,500,1000,2000,4000};d.PollingRate=2000;
 missing.Update(@"C:\Games\game.exe",devices,apply);Check(lastRate==4000,"known 2000 baseline can enter profile");missing.RestoreAll(devices,apply);Check(lastRate==2000,"restore 2000 baseline");
 service.Save();var loaded=new ApplicationMouseProfileService(file);loaded.Load();Check(loaded.Profiles.Count==1&&Dpi(loaded.Profiles[0])==1600&&loaded.Profiles[0].DpiStage==0,"persist value rule");
 File.WriteAllText(file,"<profiles><profile exe='C:\\Games\\old.exe' device='Metapanda:4k' stage='2' rate='1000' enabled='true'/></profiles>");loaded.Load();Check(loaded.Profiles.Count==1&&loaded.Profiles[0].DpiStage==2&&Dpi(loaded.Profiles[0])==0,"old stage XML remains compatible");
 var uiService=new ApplicationMouseProfileService(Path.Combine(args[0],"ui.xml"));uiService.Profiles.Add(Rule());
 using(var dialog=new ApplicationMouseProfilesDialog(devices,uiService)){
 DataGridView grid=null;foreach(Control control in dialog.Controls)if(control is DataGridView)grid=(DataGridView)control;
 Check(grid!=null&&grid.Columns.Contains("mode")&&grid.Columns.Contains("target")&&grid.Columns.Contains("resolved"),"editor exposes explicit mode and resolved stage");
 grid.Rows[0].Cells["mode"].Value="档位编号";grid.Rows[0].Cells["target"].Value=2;grid.Rows[0].Cells["rate"].Value=250;
 typeof(ApplicationMouseProfilesDialog).GetMethod("SaveProfiles",BindingFlags.Instance|BindingFlags.NonPublic).Invoke(dialog,null);
 }
 uiService.Load();Check(uiService.Profiles.Count==1&&uiService.Profiles[0].DpiStage==2&&Dpi(uiService.Profiles[0])==0&&uiService.Profiles[0].PollingRate==250,"editor saves stage mode and six-rate selection");
 Console.WriteLine("PASS flexible DPI resolution, capability checks, 4K restore, XML compatibility and editor save");
 }catch(Exception ex){Console.Error.WriteLine(ex.Message);Environment.Exit(1);}}
}
"@
$source=Join-Path $work 'FlexibleTests.cs'
[IO.File]::WriteAllText($source,$harness,(New-Object Text.UTF8Encoding($true)))
$csc=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $csc /nologo /langversion:5 /codepage:65001 /r:System.Drawing.dll /r:System.Windows.Forms.dll "/r:$work/FerrisPulse.exe" "/out:$work/FlexibleTests.exe" $source
if($LASTEXITCODE -ne 0){throw 'Flexible tests compilation failed'}
& "$work/FlexibleTests.exe" $work
if($LASTEXITCODE -ne 0){throw 'Flexible tests failed'}