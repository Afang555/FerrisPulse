# Metapanda discovery integration boundaries, before production changes.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$manager = Get-Content (Join-Path $root 'src/Hardware/DeviceManager.cs') -Raw
$vgn = Get-Content (Join-Path $root 'src/Hardware/VgnDeviceHelper.cs') -Raw
if ($manager -notmatch 'MetapandaDeviceHelper.QueryDevices\(') { throw 'Metapanda devices are not enumerated independently.' }
if ($vgn -notmatch 'MetapandaDeviceHelper.IsKnownDevicePath\(devicePath\)') { throw 'VGN must not issue commands to known Metapanda endpoints.' }
$main = Get-Content (Join-Path $root 'src/UI/Forms/MainForm.cs') -Raw
if ($main -notmatch 'StartMetapandaApplicationProfiles\(\)') { throw 'Application profile scheduler not started.' }
$profiles = Get-Content (Join-Path $root 'src/UI/Forms/MainForm.Metapanda.cs') -Raw
if ($profiles -notmatch 'MouseBatteryInfo actual = MetapandaDeviceHelper.QueryDevice') { throw 'Profile baseline must use a fresh hardware read.' }
foreach ($setter in @('SetUnownedMetapandaDpiStage','SetUnownedMetapandaPollingRate')) {
    if ($profiles -notmatch ($setter + '[\s\S]+?lock \(metapandaProfileGate\)[\s\S]+?HasActiveProfile')) { throw 'Ownership decision must serialize with setting write.' }
}
$hardware = Get-Content (Join-Path $root 'src/UI/Forms/MainForm.Hardware.cs') -Raw
# Game baselines, retries and stale restores are exercised by test_game_mode_stability.ps1.
if ($profiles -notmatch 'RestoreAll\(') { throw 'Shutdown must restore profile-owned endpoints.' }
Write-Host 'PASS: discovery, ownership serialization, fresh snapshots and shutdown integration boundaries'

$tray = Get-Content (Join-Path $root 'src/UI/Forms/MainForm.Tray.cs') -Raw
if ($tray -notmatch 'AddMetapandaApplicationProfilesMenu\(\)') { throw 'Explorer tray recreation must retain application rule entry.' }
