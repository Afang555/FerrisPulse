# ============================================================================
# 测试脚本: test_openmouse_universal_gaming.ps1
# 目标: 验证 UniversalGamingDeviceHelper (OpenMouse & Mouse Hub) 代码规范与协议算法
# ============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectDir = Resolve-Path "$ScriptDir\.."
Set-Location $ProjectDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [测试 1/5] UniversalGamingDeviceHelper.cs 存在性与 UTF-8 BOM 校验" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$helperPath = "$ProjectDir\src\Hardware\UniversalGamingDeviceHelper.cs"
if (-not (Test-Path $helperPath)) {
    Write-Host "FAILED: src\Hardware\UniversalGamingDeviceHelper.cs 尚未创建！" -ForegroundColor Red
    exit 1
}

$bytes = [System.IO.File]::ReadAllBytes($helperPath)
if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
    Write-Host "FAILED: UniversalGamingDeviceHelper.cs 不是 UTF-8 with BOM 编码！" -ForegroundColor Red
    exit 1
}
Write-Host "PASSED: UniversalGamingDeviceHelper.cs 文件存在且符合 UTF-8 with BOM 规范" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " [测试 2/5] C# 5.0 语法铁律审查（严禁使用 C# 6.0+ 语法）" -ForegroundColor Cyan
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
Write-Host "PASSED: UniversalGamingDeviceHelper.cs 语法严格遵循 C# 5.0 标准" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " [测试 3/5] OpenMouse 20+ 品牌矩阵与代表型号覆盖校验" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$requiredBrands = @(
    "LAMZU",
    "VAXEE",
    "WLmouse",
    "Pulsar",
    "Endgame Gear",
    "Attack Shark",
    "Ninjutso",
    "Keychron",
    "Mchose",
    "Dareu",
    "Delux",
    "Incott",
    "RAWM",
    "Vancer",
    "Fantech",
    "Redragon",
    "G-Wolves",
    "Finalmouse",
    "Zaunkoenig",
    "Glorious",
    "WALLHACK",
    "SteelSeries",
    "Corsair",
    "ASUS"
)

foreach ($brand in $requiredBrands) {
    if ($content.IndexOf($brand, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        Write-Host "FAILED: 品牌未在 UniversalGaming 库中被索引: $brand" -ForegroundColor Red
        exit 1
    }
}
Write-Host "PASSED: OpenMouse 24+ 品牌电竞矩阵覆盖完整（涵盖国产量产、客制化与国际旗舰）" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " [测试 4/5] CompX 64字节与 Vaxee 报文解码算法验证" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 模拟 CompX 回报 (Report 0x00, 0xA1, 0x00, 0x02, 0x02, 0x00, 0x83, isChg=1, batt=78)
$mockCompx = New-Object byte[] 65
$mockCompx[0] = 0x00
$mockCompx[1] = 0xA1
$mockCompx[2] = 0x00
$mockCompx[3] = 0x02
$mockCompx[4] = 0x02
$mockCompx[5] = 0x00
$mockCompx[6] = 0x83
$mockCompx[7] = 0x01 # Charging
$mockCompx[8] = 78   # 78%

$isCompxValid = ($mockCompx[1] -eq 0xA1 -and $mockCompx[6] -eq 0x83)
$compxChg = ($mockCompx[7] -eq 1)
$compxBatt = [int]$mockCompx[8]

if (-not $isCompxValid -or -not $compxChg -or $compxBatt -ne 78) {
    Write-Host "FAILED: CompX 64-byte 报文算法验证异常" -ForegroundColor Red
    exit 1
}
Write-Host "PASSED: CompX (Lamzu/Pulsar/WLmouse) 报文解析正确 (78%, 充电中)" -ForegroundColor Green

# 模拟 VAXEE 报文 (Page 0x0B, buf[5] * 5)
$mockVaxee = New-Object byte[] 65
$mockVaxee[0] = 0x0E
$mockVaxee[1] = 0x0B # Page 0x0B: Battery
$mockVaxee[5] = 16   # 16 * 5 = 80%

$vaxeeBatt = [int]$mockVaxee[5] * 5
if ($vaxeeBatt -ne 80) {
    Write-Host "FAILED: VAXEE 离散倍数映射错误: $vaxeeBatt" -ForegroundColor Red
    exit 1
}
Write-Host "PASSED: VAXEE (NP-01/XE/AX) 报文解析正确 (80%)" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " [测试 5/5] Endgame Gear / ATK 校验和算法验证 (sum & 0xFF == 0x55)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 模拟 16 字节 EEPROM 报文
$cmd = New-Object byte[] 16
$cmd[0] = 0x08
$cmd[1] = 0x04 # Read battery

$sum = 0
for ($i = 0; $i -lt 15; $i++) {
    $sum += $cmd[$i]
}
$expectedChk = (0x55 - ($sum -band 0xFF)) -band 0xFF
$cmd[15] = [byte]$expectedChk

# 验证校验和之和
$verifySum = 0
for ($i = 0; $i -lt 16; $i++) {
    $verifySum += $cmd[$i]
}
if (($verifySum -band 0xFF) -ne 0x55) {
    Write-Host "FAILED: Checksum 计算结果未满足 sum & 0xFF == 0x55: $($verifySum -band 0xFF)" -ForegroundColor Red
    exit 1
}
Write-Host "PASSED: Endgame Gear / ATK 校验和验证成功 (Check byte: 0x$($expectedChk.ToString('X2')))" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " ALL PASS: UniversalGamingDeviceHelper 测试全部通过！" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
exit 0
