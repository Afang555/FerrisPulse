# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
# Catch failed one-shot game settings, stale restores, lost baselines and false exits on unknown focus.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$binary=if($env:FERRISPULSE_TEST_ASSEMBLY){$env:FERRISPULSE_TEST_ASSEMBLY}else{Join-Path $root 'FerrisPulse.exe'}
$asm=[Reflection.Assembly]::LoadFrom($binary)
if(-not $asm.GetType('RazerBatteryTray.MetapandaGameSession')){throw 'FAIL: retryable serialized game session is missing'}
$work=Join-Path $root 'tools\scratch\game-stability-tests';[IO.Directory]::CreateDirectory($work)|Out-Null
Copy-Item -LiteralPath $binary -Destination (Join-Path $work 'FerrisPulse.exe') -Force
$code=@'
using System;
using RazerBatteryTray;
class GameStabilityTests {
 static void Check(bool ok,string msg){if(!ok)throw new Exception(msg);}
 static MouseBatteryInfo Device(){return new MouseBatteryInfo{DeviceId="Metapanda:test-a",IsConnected=true,DpiStage=2,DpiStageCount=2,Dpi=1600,DpiY=1600,DpiStages=new int[]{800,1600},DpiStagesY=new int[]{800,1600},PollingRate=125,SupportedPollingRates=new int[]{125,250,500,1000,2000,4000}};}
 static void Main(){
  var focus=new GameFocusTracker();
  focus.Observe("valorant-1",true,true);Check(!focus.Ready,"first sample must debounce");
  focus.Observe("valorant-1",true,true);Check(focus.Active&&focus.Ready,"return to game must settle");
  for(int i=0;i<5;i++)focus.Observe("valorant-1",true,true);Check(focus.Active,"background flashing must not change focus");
  focus.Observe("",false,false);Check(focus.Active&&!focus.Ready,"unknown foreground must not mean exit");
  focus.Observe("wechat-2",true,false);Check(focus.Active&&!focus.Ready,"transient focus must debounce");
  focus.Observe("wechat-2",true,false);Check(!focus.Active&&focus.Ready,"actual stable switch should leave game");
  focus.Observe("valorant-1",true,true);focus.Observe("valorant-1",true,true);Check(focus.Active,"switch back failed");
  var session=new MetapandaGameSession();var d=Device();int writes=0;bool current=true,fail=true;
  Func<bool> guard=delegate{return current;};
  Func<string,int,int,bool> apply=delegate(string id,int stage,int hz){writes++;if(fail){fail=false;return false;}d.DpiStage=stage;d.PollingRate=hz;return true;};
  Check(!session.Update(d,true,true,true,1,4000,guard,apply)&&session.HasSession(d.DeviceId),"failure lost retry/baseline");
  Check(session.Update(d,true,true,true,1,4000,guard,apply)&&d.DpiStage==1&&d.PollingRate==4000&&writes==2,"next stable tick must retry");
  d.DpiStage=2;d.PollingRate=125;
  Check(session.Update(d,true,true,true,1,4000,guard,apply)&&writes==3&&d.DpiStage==1,"active mode drift was not corrected");
  current=false;Check(!session.Update(d,false,true,true,1,4000,guard,apply)&&writes==3,"stale restore wrote hardware");
  current=true;
  Func<string,int,int,bool> interrupted=delegate(string id,int stage,int hz){writes++;d.DpiStage=stage;d.PollingRate=hz;current=false;return true;};
  Check(!session.Update(d,false,true,true,1,4000,guard,interrupted)&&session.HasSession(d.DeviceId),"focus change during write discarded baseline");
  current=true;Check(session.Update(d,true,true,true,1,4000,guard,apply)&&d.DpiStage==1&&d.PollingRate==4000,"late restore won over reentry");
  d.IsConnected=false;Check(!session.Update(d,false,true,true,1,4000,guard,apply)&&session.HasSession(d.DeviceId),"sleep discarded restore baseline");d.IsConnected=true;
  Check(session.Update(d,false,true,true,1,4000,guard,apply)&&d.DpiStage==2&&d.PollingRate==125&&!session.HasSession(d.DeviceId),"exit did not restore original baseline");
  d=Device();d.PollingRate=500;
  Check(session.Update(d,true,true,false,1,4000,guard,apply)&&d.PollingRate==500,"DPI-only mode changed rate");
  d.PollingRate=1000;
  Check(session.Update(d,false,true,false,1,4000,guard,apply)&&d.DpiStage==2&&d.PollingRate==1000,"restore overwrote uncontrolled rate");
  Check(session.Update(d,true,true,true,1,4000,guard,apply),"reenter");
  d.DpiStages=new int[]{1600,800};d.DpiStagesY=new int[]{1600,800};d.DpiStage=2;
  Check(session.Update(d,false,true,true,1,4000,guard,apply)&&d.DpiStage==1,"restore did not follow original X/Y through reorder");
  Console.WriteLine("PASS focus debounce, background flash invariance, retries, stale restore cancellation, drift repair and baseline preservation");
 }
}
'@
$source=Join-Path $work 'GameStabilityTests.cs'; $out=Join-Path $work 'GameStabilityTests.exe'
[IO.File]::WriteAllText($source,$code,(New-Object Text.UTF8Encoding($true)))
& 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe' /nologo /langversion:5 /target:exe /codepage:65001 ('/r:'+(Join-Path $work 'FerrisPulse.exe')) ('/out:'+$out) $source
if($LASTEXITCODE -ne 0){throw 'Game stability test compilation failed'}
& $out;if($LASTEXITCODE -ne 0){throw 'Game stability regression failed'}
