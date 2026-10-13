# fix_shortcuts.ps1
$ErrorActionPreference = "Continue"

# 1. 修复电量管家 (FerrisPulse) 快捷方式
$exePath = (Resolve-Path "FerrisPulse.exe").Path
$workDir = (Resolve-Path ".").Path
$icoPath = (Resolve-Path "app.ico").Path

$desktops = @(
    "D:\LEGION Y9000X\Desktop",
    "C:\Users\LEGION Y9000X\Desktop",
    [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
) | Select-Object -Unique

$wsh = New-Object -ComObject WScript.Shell

foreach ($d in $desktops) {
    if (Test-Path $d) {
        $fpLnk = Join-Path $d "FerrisPulse · 灵脉.lnk"
        $sc = $wsh.CreateShortcut($fpLnk)
        $sc.TargetPath = $exePath
        $sc.WorkingDirectory = $workDir
        if (Test-Path $icoPath) {
            $sc.IconLocation = "$icoPath,0"
        }
        $sc.Description = "FerrisPulse · 灵脉 外设电量感知引擎"
        $sc.Save()
        Write-Host "[FIXED] FerrisPulse shortcut updated at: $fpLnk -> $exePath"
    }
}

# 2. 修复反重力 (Antigravity) 快捷方式
$antigravityExe = "C:\Users\LEGION Y9000X\AppData\Local\Programs\antigravity\Antigravity.exe"
if (Test-Path $antigravityExe) {
    $agDir = "C:\Users\LEGION Y9000X\AppData\Local\Programs\antigravity"
    
    # 2.1 修复桌面上指向旧 Downloads 路径的快捷方式
    foreach ($d in $desktops) {
        if (Test-Path $d) {
            $agLnks = Get-ChildItem $d -Filter "*Antigravity*.lnk" -ErrorAction SilentlyContinue
            foreach ($lnk in $agLnks) {
                $sc = $wsh.CreateShortcut($lnk.FullName)
                Write-Host "Updating $($lnk.Name) from '$($sc.TargetPath)' to '$antigravityExe'..."
                $sc.TargetPath = $antigravityExe
                $sc.WorkingDirectory = $agDir
                $sc.IconLocation = "$antigravityExe,0"
                $sc.Save()
                Write-Host "[FIXED] Antigravity shortcut updated: $($lnk.FullName)"
            }
        }
    }
    
    # 2.2 如果 Downloads 目录确实缺少 antigravity-hans-windows-amd64.exe，创建软链接或复制一份，彻底杜绝任何历史遗留失效
    $dlDir = "D:\LEGION Y9000X\Downloads"
    if (Test-Path $dlDir) {
        $oldTarget = Join-Path $dlDir "antigravity-hans-windows-amd64.exe"
        if (-not (Test-Path $oldTarget)) {
            Write-Host "Creating hardlink or copy in Downloads to ensure zero 404: $oldTarget"
            Copy-Item $antigravityExe $oldTarget -Force
            Write-Host "[RESTORED] Downloads executable restored: $oldTarget"
        }
    }
}

Write-Host "All shortcuts repaired successfully!"
