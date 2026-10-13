# restore_desktop_shortcut.ps1
$desktop = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
$targetExe = "d:\电量管家\FerrisPulse.exe"
$lnkPath = Join-Path $desktop "FerrisPulse · 灵脉.lnk"
$icoPath = "d:\电量管家\app.ico"

$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut($lnkPath)
$sc.TargetPath = $targetExe
$sc.WorkingDirectory = "d:\电量管家"
if (Test-Path $icoPath) {
    $sc.IconLocation = "$icoPath,0"
} else {
    $sc.IconLocation = "$targetExe,0"
}
$sc.Description = "FerrisPulse · 灵脉 外设电量感知引擎"
$sc.Save()

Write-Host "[RESTORED] Desktop shortcut restored at: $lnkPath"
