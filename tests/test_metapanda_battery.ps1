# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
# Captured coarse percentage must not hide changes in the verified P1 voltage curve.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$binary=if($env:FERRISPULSE_TEST_ASSEMBLY){$env:FERRISPULSE_TEST_ASSEMBLY}else{Join-Path $root 'FerrisPulse.exe'}
$work=Join-Path $root 'tools/scratch/battery-tests'
[IO.Directory]::CreateDirectory($work)|Out-Null
Copy-Item -LiteralPath $binary -Destination (Join-Path $work 'FerrisPulse.exe') -Force
$code=@"
using System;
using System.Reflection;
using RazerBatteryTray;
class BatteryTests {
 static void Check(bool value,string message){if(!value){Console.Error.WriteLine("FAIL: "+message);Environment.Exit(1);}}
 static byte[] Hex(string text){byte[] bytes=new byte[text.Length/2];for(int i=0;i<bytes.Length;i++)bytes[i]=Convert.ToByte(text.Substring(i*2,2),16);return bytes;}
 static byte[] Report(int coarse,int voltage,bool charging){byte[] b=new byte[17];b[0]=8;b[1]=4;b[5]=2;b[6]=(byte)coarse;b[7]=(byte)(charging?1:0);b[8]=(byte)(voltage>>8);b[9]=(byte)voltage;Finish(b);return b;}
 static void Finish(byte[] b){int sum=0;for(int i=0;i<16;i++)sum+=b[i];b[16]=unchecked((byte)(0x55-sum));}
 static void Value(byte[] b,int expected,bool expectedCharging,string name){int percent;bool charging;Check(MetapandaProtocol.DecodeBattery(b,out percent,out charging)&&percent==expected&&charging==expectedCharging,name);}
 static void Main(){
  Value(Hex("08040000000255000fc60000000000001d"),84,false,"4038mV captured packet must update coarse 85 to voltage estimate 84");
  Value(Hex("08040000000255000fd70000000000000c"),88,false,"4055mV must differ even though the coarse byte is still 85");
  Value(Hex("08040000000255000fca00000000000019"),85,false,"4042mV live readback");
  Value(Hex("0804000000025f01106100000000000076"),95,true,"charging retains the device level rather than treating charge voltage as full");
  Value(Report(85,0,false),85,false,"missing voltage retains verified legacy percentage");
  Value(Report(85,3050,false),0,false,"empty endpoint is a valid zero percent");
  Value(Report(85,3420,false),5,false,"low endpoint");
  Value(Report(85,3600,false),20,false,"20 percent endpoint");
  Value(Report(85,4000,false),75,false,"75 percent endpoint");
  Value(Report(85,4020,false),80,false,"80 percent endpoint");
  Value(Report(85,4040,false),85,false,"85 percent endpoint");
  Value(Report(85,4110,false),100,false,"full endpoint");
  int previous=-1;
  for(int mv=2500;mv<=4500;mv++){int p;bool c;Check(MetapandaProtocol.DecodeBattery(Report(85,mv,false),out p,out c)&&p>=previous&&p>=0&&p<=100,"monotone bounded curve");previous=p;}
  int percent;bool charging;
  Check(!MetapandaProtocol.DecodeBattery(Report(85,1,false),out percent,out charging)&&percent==-1&&!charging,"invalid nonzero voltage stays unknown");
  Check(!MetapandaProtocol.DecodeBattery(Report(85,65535,false),out percent,out charging),"invalid upper voltage");
  byte[] invalid=Report(85,4038,false);invalid[16]++;Check(!MetapandaProtocol.DecodeBattery(invalid,out percent,out charging),"bad checksum");
  Check(!MetapandaProtocol.DecodeBattery(new byte[16],out percent,out charging),"truncated packet");
  invalid=Report(85,4038,false);invalid[7]=2;Finish(invalid);Check(!MetapandaProtocol.DecodeBattery(invalid,out percent,out charging),"unknown charge flag");
  MethodInfo exact=typeof(MetapandaProtocol).GetMethod("DecodeBattery",new Type[]{typeof(byte[]),typeof(int).MakeByRefType(),typeof(bool).MakeByRefType(),typeof(double).MakeByRefType()});
  Check(exact!=null,"precise estimate overload exists");object[] args=new object[]{Report(85,4038,false),0,false,0.0};Check((bool)exact.Invoke(null,args)&&Math.Abs((double)args[3]-84.5)<0.000001,"precise estimate is preserved");
  Console.WriteLine("PASS voltage-aware Metapanda battery, charging/legacy fallback, invalid frames and bounded curve");
 }
}
"@
$source=Join-Path $work 'BatteryTests.cs'
$exe=Join-Path $work 'BatteryTests.exe'
[IO.File]::WriteAllText($source,$code,(New-Object Text.UTF8Encoding($true)))
& 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe' /nologo /target:exe /codepage:65001 ('/r:'+(Join-Path $work 'FerrisPulse.exe')) ('/out:'+$exe) $source
if($LASTEXITCODE -ne 0){throw 'Battery test compilation failed'}
& $exe
if($LASTEXITCODE -ne 0){throw 'Battery regression failed'}
