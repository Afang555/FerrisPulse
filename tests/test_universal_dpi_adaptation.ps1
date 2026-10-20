# Unit and regression test for Universal High-DPI Adaptive Form System
# Tests DpiScaleHelper, DpiAwareForm, AboutForm, and secondary dialogs
# ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️

Write-Host "Verifying Universal High-DPI Adaptive Form System..." -ForegroundColor Cyan

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Test 1: Verify DpiScaleHelper existence and mathematical accuracy
$binary = if ($env:FERRISPULSE_TEST_ASSEMBLY) { $env:FERRISPULSE_TEST_ASSEMBLY } else { Join-Path (Split-Path $PSScriptRoot -Parent) 'FerrisPulse.exe' }
$rawBytes = [System.IO.File]::ReadAllBytes($binary)
$asm = [System.Reflection.Assembly]::Load($rawBytes)
$helperType = $asm.GetType("RazerBatteryTray.DpiScaleHelper")

if ($helperType -eq $null) {
    Write-Host "FAIL: RazerBatteryTray.DpiScaleHelper type not found!" -ForegroundColor Red
    exit 1
}

$mScaleInt = $helperType.GetMethod("Scale", [Type[]]@([int], [float]))
$val = $mScaleInt.Invoke($null, @([int]100, [float]1.5))
if ($val -ne 150) {
    Write-Host "FAIL: DpiScaleHelper.Scale(100, 1.5) = $val, expected 150!" -ForegroundColor Red
    exit 1
}

$mScaleSize = $helperType.GetMethod("Scale", [Type[]]@([System.Drawing.Size], [float]))
$inSz = New-Object System.Drawing.Size(100, 200)
$sz = $mScaleSize.Invoke($null, @($inSz, [float]2.0))
if ($sz.Width -ne 200 -or $sz.Height -ne 400) {
    Write-Host "FAIL: DpiScaleHelper.Scale(Size(100,200), 2.0) = $sz, expected 200x400!" -ForegroundColor Red
    exit 1
}

Write-Host "PASS: DpiScaleHelper mathematical operations verified." -ForegroundColor Green

# Test 2: Verify DpiAwareForm base class contracts
$baseFormType = $asm.GetType("RazerBatteryTray.DpiAwareForm")
if ($baseFormType -eq $null) {
    Write-Host "FAIL: RazerBatteryTray.DpiAwareForm type not found!" -ForegroundColor Red
    exit 1
}

if (-not [System.Windows.Forms.Form].IsAssignableFrom($baseFormType)) {
    Write-Host "FAIL: DpiAwareForm does not inherit from System.Windows.Forms.Form!" -ForegroundColor Red
    exit 1
}

$propScale = $baseFormType.GetProperty("DpiScale")
if ($propScale -eq $null) {
    Write-Host "FAIL: DpiAwareForm.DpiScale property missing!" -ForegroundColor Red
    exit 1
}

$mApply = $baseFormType.GetMethod("OnApplyDpiScale", [System.Reflection.BindingFlags]"NonPublic,Instance")
if ($mApply -eq $null) {
    Write-Host "FAIL: DpiAwareForm.OnApplyDpiScale method missing!" -ForegroundColor Red
    exit 1
}

Write-Host "PASS: DpiAwareForm base class contracts verified." -ForegroundColor Green

# Test 3: Verify AboutForm inherits from DpiAwareForm and has zero text overlap at 200% DPI
$aboutType = $asm.GetType("RazerBatteryTray.AboutForm")
if ($aboutType -eq $null) {
    Write-Host "FAIL: RazerBatteryTray.AboutForm type not found!" -ForegroundColor Red
    exit 1
}

if (-not $baseFormType.IsAssignableFrom($aboutType)) {
    Write-Host "FAIL: AboutForm does not inherit from DpiAwareForm!" -ForegroundColor Red
    exit 1
}

# Create AboutForm at 2.0 scale (200% 4K DPI)
$aboutForm = $aboutType.GetConstructor(@([float])).Invoke(@([float]2.0))
if ($aboutForm -eq $null) {
    # If single param constructor not yet available, try parameterless
    $aboutForm = $aboutType.GetConstructor([Type]::EmptyTypes).Invoke($null)
}

# Force handle creation for layout resolution
$h = $aboutForm.Handle

# Find controls via reflection
$fLogo = $aboutType.GetField("lblLogo", [System.Reflection.BindingFlags]"NonPublic,Instance")
$fPrefix = $aboutType.GetField("lblAuthorPrefix", [System.Reflection.BindingFlags]"NonPublic,Instance")
$fCardProject = $aboutType.GetField("cardProject", [System.Reflection.BindingFlags]"NonPublic,Instance")
$fProjectDesc = $aboutType.GetField("lblProjectDesc", [System.Reflection.BindingFlags]"NonPublic,Instance")

if ($fLogo -ne $null -and $fPrefix -ne $null) {
    $lblLogo = $fLogo.GetValue($aboutForm)
    $lblPrefix = $fPrefix.GetValue($aboutForm)
    if ($lblPrefix.Top -lt $lblLogo.Bottom) {
        Write-Host "FAIL: AboutForm text overlap detected! lblAuthorPrefix.Top ($($lblPrefix.Top)) < lblLogo.Bottom ($($lblLogo.Bottom))!" -ForegroundColor Red
        $aboutForm.Dispose()
        exit 1
    }
    Write-Host "PASS: AboutForm authorship row is strictly below logo (no overlap at 200% DPI)." -ForegroundColor Green
}

if ($null -eq $fCardProject -or $null -eq $fProjectDesc) { throw 'Missing project card/description' }
# Exercise the actual 100%/150%/200% layout even when the current monitor clamps window scale.
$scaleField = $baseFormType.GetField('dpiScale', [System.Reflection.BindingFlags]'NonPublic,Instance')
$layoutMethod = $aboutType.GetMethod('ApplyAboutLayout', [System.Reflection.BindingFlags]'NonPublic,Instance')
foreach ($scale in @([float]1.0,[float]1.5,[float]2.0)) {
    $scaleField.SetValue($aboutForm,$scale)
    $null = $layoutMethod.Invoke($aboutForm,@())
    $cardProject = $fCardProject.GetValue($aboutForm)
    $description = $fProjectDesc.GetValue($aboutForm)
    if ($description.Right -gt $cardProject.ClientSize.Width) { throw 'Project description is clipped' }
    $previousBottom = $description.Bottom
    foreach ($field in @('lnkGithub','lnkGuide','lnkIssues','lnkUpstream')) {
        $control = $aboutType.GetField($field,[System.Reflection.BindingFlags]'NonPublic,Instance').GetValue($aboutForm)
        if ($control.Top -lt $previousBottom -or $control.Right -gt $cardProject.ClientSize.Width -or $control.Bottom -gt $cardProject.ClientSize.Height) { throw ('Clipped/overlapping project link at scale ' + $scale + ': ' + $field) }
        $previousBottom = $control.Bottom
    }
    if ($aboutForm.ClientSize.Width -ne [int](600*$scale)) { throw 'AboutForm is not applying the requested DPI scale' }
    Write-Host ('PASS: Project card and links fit at ' + ($scale*100) + '% DPI.') -ForegroundColor Green
}

$aboutForm.Dispose()
Write-Host "PASS: AboutForm DPI adaptation verified." -ForegroundColor Green

# Test 4: Verify all secondary dialog forms inherit from DpiAwareForm
$allSecondaryForms = @(
    "AboutForm",
    "AddDeviceWizardForm",
    "DevicePriorityForm",
    "DpiManagementDialog",
    "UpdateNoticeForm",
    "PromptDialog",
    "EasterEggQuoteForm",
    "GameProcessManagerForm",
    "KeyRolloverSpeedForm",
    "MouseRateTestDialog",
    "ModernDeviceSwitcherFlyout",
    "DpiOsdForm"
)

foreach ($formName in $allSecondaryForms) {
    $t = $asm.GetType("RazerBatteryTray.$formName")
    if ($t -eq $null) {
        Write-Host "FAIL: Form type RazerBatteryTray.$formName not found in assembly!" -ForegroundColor Red
        exit 1
    }
    if (-not $baseFormType.IsAssignableFrom($t)) {
        Write-Host "FAIL: $formName does not inherit from DpiAwareForm!" -ForegroundColor Red
        exit 1
    }
    Write-Host "PASS: $formName inherits from DpiAwareForm." -ForegroundColor Green
}

Write-Host "ALL HIGH-DPI TESTS PASSED SUCCESSFULLY!" -ForegroundColor Green
exit 0
