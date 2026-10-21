# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
# Regression: captured reports, malformed responses and endpoint isolation.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path "$root/src/Hardware/MetapandaProtocol.cs")) { throw 'FAIL: Metapanda codec is missing' }
$scratch = Join-Path $root 'tools/scratch'
[IO.Directory]::CreateDirectory($scratch) | Out-Null
$runner = @"
using System;
using RazerBatteryTray;
class MetapandaTests {
 static void Check(bool value, string name) { if (!value) { Console.Error.WriteLine("FAIL: " + name); Environment.Exit(1); } }
 static byte[] Hex(string s) { byte[] b=new byte[s.Length/2]; for(int i=0;i<b.Length;i++) b[i]=Convert.ToByte(s.Substring(i*2,2),16); return b; }
 static string Hex(byte[] b) { return b==null ? "<null>" : BitConverter.ToString(b).Replace("-", "").ToLowerInvariant(); }
 static void Main() {
  Check(Hex(MetapandaProtocol.BuildDpiStage(1))=="08070000040200550000000000000000eb", "captured stage 1");
  Check(Hex(MetapandaProtocol.BuildDpiStage(2))=="08070000040201540000000000000000eb", "captured stage 2");
  Check(Hex(MetapandaProtocol.BuildPollingRate(1000))=="08070000000201540000000000000000ef", "captured 1000Hz");
  Check(Hex(MetapandaProtocol.BuildPollingRate(125))=="080700000002084d0000000000000000ef", "captured 125Hz");
  Check(MetapandaProtocol.BuildDpiStage(0)==null && MetapandaProtocol.BuildDpiStage(9)==null, "invalid stage");
  Check(Hex(MetapandaProtocol.BuildPollingRate(4000))=="08070000000220350000000000000000ef", "captured 4000Hz");
  Check(Hex(MetapandaProtocol.BuildPollingRate(2000))=="08070000000210450000000000000000ef", "captured 2000Hz");
  Check(Hex(MetapandaProtocol.BuildPollingRate(500))=="08070000000202530000000000000000ef", "captured 500Hz");
  Check(Hex(MetapandaProtocol.BuildPollingRate(250))=="08070000000204510000000000000000ef", "captured 250Hz");
  Check(MetapandaProtocol.BuildPollingRate(8000)==null, "unverified rate prohibited");
  byte[] request=MetapandaProtocol.BuildDpiStage(1);
  Check(MetapandaProtocol.MatchesResponse(request,(byte[])request.Clone()), "captured exact ACK");
  Check(!MetapandaProtocol.MatchesResponse(request,MetapandaProtocol.BuildDpiStage(2)), "wrong value ACK");
  Check(!MetapandaProtocol.MatchesResponse(request,MetapandaProtocol.BuildPollingRate(125)), "wrong address ACK");
  byte[] corrupt=(byte[])request.Clone(); corrupt[16]++;
  Check(!MetapandaProtocol.MatchesResponse(request,corrupt), "bad checksum");
  Check(!MetapandaProtocol.MatchesResponse(request,new byte[16]), "truncated ACK");
  Check(!MetapandaProtocol.MatchesResponse(request,null), "timeout");
  byte[] r0=Hex("08080000000a084d025300550055005592");
  byte[] r10=Hex("080800000a0a01540f0f00371f1f001732");
  byte[] memory=new byte[20];
  Check(MetapandaProtocol.CopyMemoryResponse(MetapandaProtocol.BuildReadMemory(0,10),r0,memory), "captured memory 0");
  Check(MetapandaProtocol.CopyMemoryResponse(MetapandaProtocol.BuildReadMemory(10,10),r10,memory), "captured memory 10");
  Check(!MetapandaProtocol.CopyMemoryResponse(MetapandaProtocol.BuildReadMemory(0,10),r10,memory), "wrong memory address");
  MouseBatteryInfo state=new MouseBatteryInfo();
  Check(MetapandaProtocol.DecodeSettings(memory,state), "decode actual settings");
  Check(state.PollingRate==125 && state.DpiStage==1 && state.DpiStageCount==2 && state.Dpi==800 && state.DpiStages[1]==1600, "captured state values");
  memory[0]=0x20; memory[1]=0x35;
  Check(MetapandaProtocol.DecodeSettings(memory,state) && state.PollingRate==4000,"decode 4K readback");
  memory[0]=0x10; memory[1]=0x45;
  Check(MetapandaProtocol.DecodeSettings(memory,state) && state.PollingRate==2000,"decode 2K readback");
  memory[4]=1; memory[5]=0x54;
  Check(MetapandaProtocol.DecodeSettings(memory,state) && state.Dpi==1600, "stage readback changes DPI");
  memory[14]=0x11; memory[15]=0x26;
  Check(!MetapandaProtocol.DecodeSettings(memory,new MouseBatteryInfo()), "unverified extended DPI encoding stays unknown");
  memory[14]=0; memory[15]=0x37;
  memory[5]++;
  Check(!MetapandaProtocol.DecodeSettings(memory,new MouseBatteryInfo()), "internal setting checksum");
  int battery; bool charging;
  Check(MetapandaProtocol.DecodeBattery(Hex("0804000000025f01106100000000000076"),out battery,out charging) && battery==95 && charging, "captured battery");
  Check(!MetapandaDeviceHelper.SetDpiStage("Metapanda:missing",1), "missing endpoint never falls back");
  Check(!MetapandaDeviceHelper.SetPollingRate("VGN:3554:F5AB",1000), "other brand never falls back");
  Check(MetapandaDeviceHelper.QueryDevice(null)==null, "null identity never selects device");
  Check(!MetapandaDeviceHelper.IsKnownDevicePath(@"\\?\hid#vid_3554&pid_f5ad&mi_01"), "unknown sibling PID not controlled");
  Check(MetapandaDeviceHelper.QueryDevice(@"Metapanda:\\?\hid#vid_3554&pid_f5a9&mi_01#missing")==null, "same-model missing endpoint never falls back");
  Console.WriteLine("PASS Metapanda captured protocol, state and endpoint rejection");
 }
}
"@
$runnerPath = Join-Path $scratch 'metapanda-test-runner.cs'
[IO.File]::WriteAllText($runnerPath, $runner, (New-Object Text.UTF8Encoding($true)))
$out = Join-Path $scratch 'metapanda-test-runner.exe'
$sources = @('src/Services/BatteryDisplayTracker.cs','src/Services/DiagnosticLog.cs','src/Hardware/MetapandaProtocol.cs','src/Hardware/MetapandaDeviceHelper.cs','src/Hardware/RazerDeviceHelper.cs','src/Models/MouseBatteryInfo.cs','src/Models/DeviceCategory.cs','src/Models/RazerDeviceHardwareState.cs') | ForEach-Object { Join-Path $root $_ }
& 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe' /nologo /langversion:5 /codepage:65001 /target:exe /main:MetapandaTests /r:System.Drawing.dll /r:System.Windows.Forms.dll "/out:$out" $sources $runnerPath
if ($LASTEXITCODE -ne 0) { throw 'Metapanda test compilation failed' }
& $out
if ($LASTEXITCODE -ne 0) { throw 'Metapanda tests failed' }
