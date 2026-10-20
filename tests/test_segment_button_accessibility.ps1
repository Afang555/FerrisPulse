# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$work=[IO.Path]::GetFullPath((Join-Path $root 'tools\scratch\button-tests'))
[IO.Directory]::CreateDirectory($work)|Out-Null
$binary=if($env:FERRISPULSE_TEST_ASSEMBLY){$env:FERRISPULSE_TEST_ASSEMBLY}else{Join-Path $root 'FerrisPulse.exe'}
Copy-Item $binary (Join-Path $work 'FerrisPulse.exe') -Force
$code=@"
using System;using System.Windows.Forms;using RazerBatteryTray;
class ButtonTests{[STAThread]static void Main(){using(var b=new ModernSegmentButton()){int calls=0;b.Text="800";b.Click+=delegate{calls++;};b.AccessibilityObject.DoDefaultAction();if(calls!=1){Console.Error.WriteLine("FAIL accessible button action did not reach the real Click event");Environment.Exit(1);}b.Selected=true;if((b.AccessibilityObject.State&AccessibleStates.Pressed)==0){Console.Error.WriteLine("FAIL selected state is not exposed");Environment.Exit(1);}b.Enabled=false;b.AccessibilityObject.DoDefaultAction();if(calls!=1){Console.Error.WriteLine("FAIL disabled action invoked a click");Environment.Exit(1);}Console.WriteLine("PASS accessible real click, selected state and disabled behavior");}}}
"@
[IO.File]::WriteAllText((Join-Path $work 'ButtonTests.cs'),$code,(New-Object Text.UTF8Encoding($true)))
$source=Join-Path $work 'ButtonTests.cs'
$exe=Join-Path $work 'ButtonTests.exe'
$reference='/r:'+(Join-Path $work 'FerrisPulse.exe')
& 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe' /nologo /codepage:65001 /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:Accessibility.dll $reference ('/out:'+$exe) $source
if($LASTEXITCODE -ne 0){throw 'Compilation failed'}
& $exe
if($LASTEXITCODE -ne 0){throw 'Accessible click regression failed'}