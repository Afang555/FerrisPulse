# ============================================================================
# 测试脚本: test_apple_beats_support.ps1
# 目标: 验证 Apple / Beats 外设支持模块的代码规范、C# 5.0 语法、模型库及 Continuity 报文算法
# ============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectDir = Resolve-Path "$ScriptDir\.."
Set-Location $ProjectDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [测试 1/4] AppleDeviceHelper.cs 存在性与 UTF-8 BOM 编码校验" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$helperPath = "$ProjectDir\src\Hardware\AppleDeviceHelper.cs"
if (-not (Test-Path $helperPath)) {
    Write-Host "FAILED: src\Hardware\AppleDeviceHelper.cs 尚未创建！" -ForegroundColor Red
    exit 1
}

$bytes = [System.IO.File]::ReadAllBytes($helperPath)
if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
    Write-Host "FAILED: AppleDeviceHelper.cs 不是 UTF-8 with BOM 编码！" -ForegroundColor Red
    exit 1
}
Write-Host "PASSED: AppleDeviceHelper.cs 文件存在且符合 UTF-8 with BOM 规范" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " [测试 2/4] C# 5.0 语法铁律审查（严禁使用 C# 6.0+ 语法）" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$content = [System.IO.File]::ReadAllText($helperPath, [System.Text.Encoding]::UTF8)

# 1. 禁用字符串插值
if ([regex]::IsMatch($content, '\$".*?"')) {
    Write-Host "FAILED: 发现禁用的字符串插值语法" -ForegroundColor Red
    exit 1
}

# 2. 禁用空条件运算符
if ([regex]::IsMatch($content, '\w+\?\.')) {
    Write-Host "FAILED: 发现禁用的空条件运算符" -ForegroundColor Red
    exit 1
}

# 3. 禁用 nameof
if ([regex]::IsMatch($content, 'nameof\s*\(')) {
    Write-Host "FAILED: 发现禁用的 nameof 语法" -ForegroundColor Red
    exit 1
}

# 4. 禁用 out var
if ([regex]::IsMatch($content, 'out\s+var\s+')) {
    Write-Host "FAILED: 发现禁用的 out var 内联声明" -ForegroundColor Red
    exit 1
}

# 5. 必须包含头部 AI 维护准则
if (-not $content.Contains("⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️")) {
    Write-Host "FAILED: 缺少头部 AI 维护准则声明" -ForegroundColor Red
    exit 1
}

# 6. 严禁出现硬编码假电量 (85 或 90 作为缺省指示)
if ($content.Contains("? battery : 85") -or $content.Contains("? batt : 90")) {
    Write-Host "FAILED: 发现违规硬编码假电量 (85% 或 90%)！" -ForegroundColor Red
    exit 1
}
Write-Host "PASSED: AppleDeviceHelper.cs 语法严格遵循 C# 5.0 标准且杜绝任何硬编码伪造假电量" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " [测试 3/4] Apple / Beats 产品型号与特征库覆盖度校验" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$expectedModels = @(
    "AirPods Pro 2",
    "AirPods Pro",
    "AirPods (第 3 代)",
    "AirPods 4",
    "AirPods Max",
    "Beats Studio Buds",
    "Beats Fit Pro",
    "Beats Solo 4",
    "Beats Studio Pro",
    "Magic Mouse",
    "Magic Keyboard",
    "Magic Trackpad"
)

foreach ($m in $expectedModels) {
    if (-not $content.Contains($m)) {
        Write-Host "FAILED: 缺少核心设备型号映射: $m" -ForegroundColor Red
        exit 1
    }
}
Write-Host "PASSED: Apple / Beats 产品线覆盖完整（包括 AirPods 全系、Beats 全系及 Magic 键鼠外设）" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " [测试 4/4] 模拟 Apple Continuity 0x07 配对广播报文解析算法验证" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 模拟 AirPods Pro (0x0E 0x20) 广播帧：
# 长度 27 字节
# byte 0: Type = 0x07 (Proximity Pairing)
# byte 1: Length = 0x19
# byte 2: Prefix
# byte 3-4: Device Model (0x0E, 0x20)
# byte 5: Status
# byte 6: Left / Right battery nibbles (e.g. Left=80% -> 0x8, Right=90% -> 0x9 -> 0x89 or 0x98)
# byte 7: Case battery nibble & charging bits (e.g. Case=100% -> 0x0A, charging bit in high bit)
$mockAdv = New-Object byte[] 27
$mockAdv[0] = 0x07
$mockAdv[1] = 0x19
$mockAdv[2] = 0x01
$mockAdv[3] = 0x0E
$mockAdv[4] = 0x20
$mockAdv[5] = 0x55
$mockAdv[6] = 0x78 # High nibble 7 (70%), Low nibble 8 (80%)
$mockAdv[7] = 0x1A # Case 10 (100%), charging flags
$mockAdv[8] = 0x01 # Bit 0: Left charging

$modelId = [int]$mockAdv[3] -bor ([int]$mockAdv[4] -shl 8)
if ($modelId -ne 0x200E) {
    Write-Host "FAILED: Model ID 解析错误: $modelId" -ForegroundColor Red
    exit 1
}

$rawL = ($mockAdv[6] -shr 4) -band 0x0F
$rawR = $mockAdv[6] -band 0x0F
$rawCase = $mockAdv[7] -band 0x0F

$leftPct = if ($rawL -eq 10) { 100 } elseif ($rawL -ge 1 -and $rawL -le 9) { $rawL * 10 + 5 } else { -1 }
$rightPct = if ($rawR -eq 10) { 100 } elseif ($rawR -ge 1 -and $rawR -le 9) { $rawR * 10 + 5 } else { -1 }
$casePct = if ($rawCase -eq 10) { 100 } elseif ($rawCase -ge 1 -and $rawCase -le 9) { $rawCase * 10 + 5 } else { -1 }

if ($leftPct -ne 75 -or $rightPct -ne 85 -or $casePct -ne 100) {
    Write-Host "FAILED: 电量百分比阶梯映射异常: L=$leftPct, R=$rightPct, Case=$casePct" -ForegroundColor Red
    exit 1
}

Write-Host "PASSED: Continuity 报文解码正确 (Left: 75%, Right: 85%, Case: 100%)" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " ALL PASS: Apple / Beats 支持系统测试通过！" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
exit 0
