Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$repoRoot = (Get-Location).Path
$tempDll = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "FerrisPulse_Test_" + [System.Guid]::NewGuid().ToString("N") + ".dll")
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

& $csc /target:library /optimize- /codepage:65001 /r:System.Drawing.dll /r:System.Windows.Forms.dll /out:$tempDll /recurse:src\*.cs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Compilation failed!"
    exit 1
}

$bytes = [System.IO.File]::ReadAllBytes($tempDll)
$assembly = [System.Reflection.Assembly]::Load($bytes)
Remove-Item $tempDll -Force -ErrorAction SilentlyContinue

$aboutFormType = $assembly.GetType('RazerBatteryTray.AboutForm')
$chimeType = $assembly.GetType('RazerBatteryTray.ChimeSynthesizer')

Write-Host '--- 1. Testing Audio rapid fire 20 times ---'
$playMethod = $chimeType.GetMethod('PlayScaleNote', [System.Reflection.BindingFlags]'Public,Static')
$sw = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt 20; $i++) {
    $note = $i % 8
    $playMethod.Invoke($null, @([object]$note))
}
$sw.Stop()
Write-Host "Audio 20 rapid fires completed in $($sw.ElapsedMilliseconds) ms without blocking!"

Write-Host '--- 2. Instantiating AboutForm and capturing Front with Caustic Water Ripples ---'
$form = [System.Activator]::CreateInstance($aboutFormType)
$form.Show()

# Pump events to show form
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Milliseconds 20
    [System.Windows.Forms.Application]::DoEvents()
}

# Simulate 4 rapid clicks on author label to generate a cascade of stacked hearts on front card
$authorClickMethod = $aboutFormType.GetMethod('OnAuthorNameClick', [System.Reflection.BindingFlags]'NonPublic,Instance')
if ($null -ne $authorClickMethod) {
    for ($c = 0; $c -lt 4; $c++) {
        $authorClickMethod.Invoke($form, [object[]]@($null, [System.EventArgs]::Empty))
        Start-Sleep -Milliseconds 15
        [System.Windows.Forms.Application]::DoEvents()
    }
}

# Allow hearts to float upwards gracefully
for ($k = 0; $k -lt 10; $k++) {
    Start-Sleep -Milliseconds 20
    [System.Windows.Forms.Application]::DoEvents()
}

$frontPng = [System.IO.Path]::Combine($repoRoot, "front_view.png")
$bmpFront = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
$form.DrawToBitmap($bmpFront, (New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
$bmpFront.Save($frontPng, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Saved: $frontPng"

# Trigger full-window aurora transition
Write-Host '--- 3. Triggering Ethereal Transition ---'
$triggerMethod = $aboutFormType.GetMethod('TriggerQuantumShatter', [System.Reflection.BindingFlags]'NonPublic,Instance')
$triggerMethod.Invoke($form, @([object]$true))

# Capture mid-transition (~280ms)
for ($i = 0; $i -lt 12; $i++) {
    Start-Sleep -Milliseconds 25
    [System.Windows.Forms.Application]::DoEvents()
}
$shatterPng = [System.IO.Path]::Combine($repoRoot, "shatter_view.png")
$bmpShatter = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
$form.DrawToBitmap($bmpShatter, (New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
$bmpShatter.Save($shatterPng, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Saved: $shatterPng"

# Wait for transition and staggered text fade-in to fully complete (~2.2s)
Write-Host '--- 4. Waiting for staggered text glow, generating stardust trail and capturing Back ---'
for ($i = 0; $i -lt 70; $i++) {
    Start-Sleep -Milliseconds 30
    [System.Windows.Forms.Application]::DoEvents()
}

# Simulate gentle mouse wave across back card to generate radiant stardust trail
for ($px = 120; $px -le 440; $px += 14) {
    $py = 220 + [Math]::Sin($px / 28.0) * 45
    $form.SimulateStardustTrail([int]$px, [int]$py)
    Start-Sleep -Milliseconds 15
    [System.Windows.Forms.Application]::DoEvents()
}

$backPng = [System.IO.Path]::Combine($repoRoot, "back_view.png")
$bmpBack = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
$form.DrawToBitmap($bmpBack, (New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
$bmpBack.Save($backPng, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Saved: $backPng"

# Verify stopping ambient melody
$stopMelody = $chimeType.GetMethod('StopAmbientMelody', [System.Reflection.BindingFlags]'Public,Static')
if ($null -ne $stopMelody) {
    $stopMelody.Invoke($null, $null)
}

# Trigger reverse transition to front
Write-Host '--- 5. Triggering Reverse Transition (Back -> Front) ---'
$triggerMethod.Invoke($form, @([object]$false))

# Capture mid-return (~250ms)
for ($i = 0; $i -lt 10; $i++) {
    Start-Sleep -Milliseconds 25
    [System.Windows.Forms.Application]::DoEvents()
}
$returnPng = [System.IO.Path]::Combine($repoRoot, "return_view.png")
$bmpReturn = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
$form.DrawToBitmap($bmpReturn, (New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
$bmpReturn.Save($returnPng, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Saved: $returnPng"

# Wait for return to fully settle (~600ms)
for ($i = 0; $i -lt 25; $i++) {
    Start-Sleep -Milliseconds 25
    [System.Windows.Forms.Application]::DoEvents()
}
$returnedPng = [System.IO.Path]::Combine($repoRoot, "front_returned.png")
$bmpReturned = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
$form.DrawToBitmap($bmpReturned, (New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
$bmpReturned.Save($returnedPng, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Saved: $returnedPng"

$form.Close()
$form.Dispose()
Write-Host "ALL CAPTURES COMPLETED SUCCESSFULLY!"
