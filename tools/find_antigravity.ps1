# find_antigravity.ps1
Write-Host "--- Antigravity Processes ---"
Get-Process | Where-Object { $_.ProcessName -like "*antigravity*" -or $_.Path -like "*antigravity*" } | Select-Object Id, ProcessName, Path

Write-Host "--- Desktop .lnk files ---"
$desktops = @(
    "D:\LEGION Y9000X\Desktop",
    "C:\Users\LEGION Y9000X\Desktop",
    [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
) | Select-Object -Unique

$wsh = New-Object -ComObject WScript.Shell
foreach ($d in $desktops) {
    if (Test-Path $d) {
        Write-Host "In Desktop: $d"
        Get-ChildItem $d -Filter "*.lnk" | ForEach-Object {
            try {
                $sc = $wsh.CreateShortcut($_.FullName)
                Write-Host "  $($_.Name) -> Target: $($sc.TargetPath)"
            } catch {
                Write-Host "  $($_.Name)"
            }
        }
    }
}
