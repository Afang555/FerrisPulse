# verify_shortcuts.ps1
$wsh = New-Object -ComObject WScript.Shell
$desktop = "D:\LEGION Y9000X\Desktop"

Get-ChildItem $desktop -Filter "*.lnk" | ForEach-Object {
    if ($_.Name -like "*FerrisPulse*" -or $_.Name -like "*Antigravity*") {
        $sc = $wsh.CreateShortcut($_.FullName)
        $exists = Test-Path $sc.TargetPath
        Write-Host "$($_.Name):"
        Write-Host "   TargetPath: $($sc.TargetPath)"
        Write-Host "   TargetExists: $exists"
    }
}
