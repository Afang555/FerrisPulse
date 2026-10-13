# restore_ide_shortcut.ps1
$wsh = New-Object -ComObject WScript.Shell
$desktop = "D:\LEGION Y9000X\Desktop"

$ideExe = "D:\LEGION Y9000X\Downloads\Antigravity IDE.exe"
$ideDir = "D:\LEGION Y9000X\Downloads"

# 找到 Antigravity IDE 的快捷方式并将其精准重定向回 Antigravity IDE.exe
Get-ChildItem $desktop -Filter "*Antigravity*IDE*.lnk" | ForEach-Object {
    $sc = $wsh.CreateShortcut($_.FullName)
    $sc.TargetPath = $ideExe
    $sc.WorkingDirectory = $ideDir
    $sc.IconLocation = "$ideExe,0"
    $sc.Save()
    Write-Host "[RESTORED] $($_.Name) -> $ideExe"
}

# 确保普通的 Antigravity 快捷方式指向 2.0
Get-ChildItem $desktop -Filter "*Antigravity*.lnk" | ForEach-Object {
    if ($_.Name -notlike "*IDE*") {
        $ag2Exe = "C:\Users\LEGION Y9000X\AppData\Local\Programs\antigravity\Antigravity.exe"
        $sc = $wsh.CreateShortcut($_.FullName)
        $sc.TargetPath = $ag2Exe
        $sc.WorkingDirectory = "C:\Users\LEGION Y9000X\AppData\Local\Programs\antigravity"
        $sc.IconLocation = "$ag2Exe,0"
        $sc.Save()
        Write-Host "[VERIFIED 2.0] $($_.Name) -> $ag2Exe"
    }
}
