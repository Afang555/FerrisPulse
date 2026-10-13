# build_release_zip.ps1
$zipPath = "d:\电量管家\FerrisPulse_v2.0_Portable.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

$filesToPack = @(
    "d:\电量管家\FerrisPulse.exe",
    "d:\电量管家\README.md",
    "d:\电量管家\CHANGELOG.md",
    "d:\电量管家\更新日志.txt",
    "d:\电量管家\使用说明与常见问题.txt"
)

Write-Host "Compressing Release artifacts to $zipPath..."
Compress-Archive -Path $filesToPack -DestinationPath $zipPath -CompressionLevel Optimal

if (Test-Path $zipPath) {
    $item = Get-Item $zipPath
    Write-Host "[SUCCESS] Archive created: $($item.FullName) ($($item.Length) bytes)"
    exit 0
} else {
    Write-Host "[ERROR] Failed to create zip file."
    exit 1
}
