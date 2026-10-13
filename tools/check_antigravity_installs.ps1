# check_antigravity_installs.ps1
$list = @()

$candidates = @(
    "D:\LEGION Y9000X\Downloads\Antigravity IDE.exe",
    "D:\LEGION Y9000X\Downloads\antigravity-hans-windows-amd64.exe",
    "E:\BaiduNetdiskDownload\antigravity-zh.exe",
    "C:\Users\LEGION Y9000X\AppData\Local\Programs\antigravity\Antigravity.exe"
)

foreach ($c in $candidates) {
    if (Test-Path $c) {
        $item = Get-Item $c
        $list += [PSCustomObject]@{
            Path = $c
            SizeMB = [math]::Round($item.Length / 1MB, 2)
            Modified = $item.LastWriteTime
        }
    }
}

$list | Format-Table -AutoSize
