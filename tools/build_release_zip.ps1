# build_release_zip.ps1
# 自动化发布打包脚本（产物已被 .gitignore 忽略，仅供 GitHub/Gitee Releases 附件上传）
param([string]$Version = "2.0.0")
$rootDir = (Resolve-Path "$PSScriptRoot\..").Path
$cleanVer = $Version.TrimStart('v', 'V')
$zipPath = Join-Path $rootDir "FerrisPulse_v${cleanVer}_Portable.zip"

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

$filesToPack = @(
    (Join-Path $rootDir "FerrisPulse.exe"),
    (Join-Path $rootDir "README.md"),
    (Join-Path $rootDir "LICENSE"),
    (Join-Path $rootDir "CHANGELOG.md")
)

$faq = Join-Path $rootDir "docs\FAQ.txt"
if (Test-Path $faq) { $filesToPack += $faq }
$legacyChangelog = Join-Path $rootDir "docs\CHANGELOG_LEGACY.txt"
if (Test-Path $legacyChangelog) { $filesToPack += $legacyChangelog }

Write-Host "Compressing Release artifacts to $zipPath..."
Compress-Archive -Path $filesToPack -DestinationPath $zipPath -CompressionLevel Optimal

if (Test-Path $zipPath) {
    $item = Get-Item $zipPath
    Write-Host "[SUCCESS] Archive created: $($item.FullName) ($($item.Length) bytes)"
    Write-Host "[NOTE] Binary zip is git-ignored and intended for GitHub Releases."
    exit 0
} else {
    Write-Host "[ERROR] Failed to create zip file."
    exit 1
}
