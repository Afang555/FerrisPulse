# run_all_tests.ps1
$testFiles = Get-ChildItem (Join-Path $PSScriptRoot "..\tests\test_*.ps1")
$allPassed = $true
$summary = @()

foreach ($tf in $testFiles) {
    Write-Host ("[TESTING] " + $tf.Name) -ForegroundColor Cyan
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-ExecutionPolicy Bypass -NoProfile -File `"$($tf.FullName)`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    
    $p = [System.Diagnostics.Process]::Start($psi)
    $finished = $p.WaitForExit(8000) # 8秒看门狗超时，防止任何测试脚本无休止卡死
    if (-not $finished) {
        try { $p.Kill() } catch { }
        $allPassed = $false
        $summary += "[TIMEOUT (>8s)] " + $tf.Name
        Write-Host " -> TIMEOUT (>8s): 强制终止防卡死" -ForegroundColor Red
        continue
    }

    if ($p.ExitCode -eq 0) {
        $summary += "[PASS] " + $tf.Name
        Write-Host " -> OK" -ForegroundColor Green
    } else {
        $allPassed = $false
        $summary += "[FAIL (" + $p.ExitCode + ")] " + $tf.Name
        Write-Host " -> FAILED with code " + $p.ExitCode -ForegroundColor Red
    }
}

Write-Host "`n================ TEST SUITE SUMMARY ================" -ForegroundColor Yellow
$summary | ForEach-Object { Write-Host $_ }

if (-not $allPassed) {
    exit 1
} else {
    exit 0
}
