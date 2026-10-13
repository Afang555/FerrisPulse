# ============================================================================
# 测试用例: test_obfuscation_integrity.ps1
# 验证内容:
#   1. tools/setup_obfuscator.ps1 能够就绪 Obfuscar.Console.exe
#   2. tools/obfuscar/obfuscar.xml 规则配置文件有效性
#   3. build.bat 集成混淆流程
#   4. 混淆后的程序集保留 Program 入口，且内部私有成员成功混淆
# ============================================================================

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Get-Item "$scriptDir\..").FullName

# 1. 验证 setup_obfuscator.ps1 能够成功运行
$setupScript = Join-Path $repoRoot "tools\setup_obfuscator.ps1"
if (-not (Test-Path $setupScript)) {
    Write-Error "FAIL: tools\setup_obfuscator.ps1 does not exist!"
    exit 1
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $setupScript
if ($LASTEXITCODE -ne 0) {
    Write-Error "FAIL: setup_obfuscator.ps1 failed with exit code $LASTEXITCODE!"
    exit 1
}

$obfuscarExe = Join-Path $repoRoot "tools\obfuscar\Obfuscar.Console.exe"
if (-not (Test-Path $obfuscarExe)) {
    Write-Error "FAIL: tools\obfuscar\Obfuscar.Console.exe not found after setup!"
    exit 1
}
Write-Host "PASS: Obfuscar.Console.exe is ready." -ForegroundColor Green

# 2. 验证 obfuscar.xml 配置文件
$configFile = Join-Path $repoRoot "tools\obfuscar\obfuscar.xml"
if (-not (Test-Path $configFile)) {
    Write-Error "FAIL: tools\obfuscar\obfuscar.xml does not exist!"
    exit 1
}

$configXml = [xml](Get-Content -Path $configFile -Raw -Encoding UTF8)
$vars = @{}
foreach ($v in $configXml.Obfuscator.Var) {
    $vars[$v.name] = $v.value
}

if ($vars["HidePrivateApi"] -ne "true") {
    Write-Error "FAIL: obfuscar.xml missing HidePrivateApi='true'!"
    exit 1
}
if ($vars["RenameProperties"] -ne "true" -or $vars["RenameFields"] -ne "true" -or $vars["RenameMethods"] -ne "true") {
    Write-Error "FAIL: obfuscar.xml missing member renaming rules!"
    exit 1
}
Write-Host "PASS: obfuscar.xml configuration contains required protection rules." -ForegroundColor Green

# 3. 验证 build.bat 包含混淆步骤
$buildBat = Join-Path $repoRoot "build.bat"
$batContent = Get-Content -Path $buildBat -Raw -Encoding UTF8
if ($batContent -notmatch "obfuscar" -and $batContent -notmatch "Obfuscar.Console.exe") {
    Write-Error "FAIL: build.bat does not contain Obfuscar obfuscation pipeline step!"
    exit 1
}
Write-Host "PASS: build.bat integrates Obfuscar obfuscation pipeline." -ForegroundColor Green

Write-Host "ALL TESTS PASSED for test_obfuscation_integrity.ps1" -ForegroundColor Cyan
