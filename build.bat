@echo off
chcp 65001 >nul
setlocal

set CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" (
    set CSC=C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe
)

echo =======================================================
echo Compiling FerrisPulse (Modular Architecture)...
echo Compiler: %CSC%
echo =======================================================

"%CSC%" /target:winexe /optimize+ /codepage:65001 /win32icon:app.ico /r:System.Drawing.dll /r:System.Windows.Forms.dll /out:FerrisPulse.raw.exe /recurse:src\*.cs

if %ERRORLEVEL% neq 0 (
    echo [FAILED] Compilation failed with error code: %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo =======================================================
echo Running Obfuscar Anti-Decompilation Protection...
echo =======================================================

if not exist "tools\obfuscar\Obfuscar.Console.exe" (
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\setup_obfuscator.ps1
)

if exist "tools\obfuscar\Obfuscar.Console.exe" (
    tools\obfuscar\Obfuscar.Console.exe -s tools\obfuscar\obfuscar.xml
    if exist "Obfuscated\FerrisPulse.raw.exe" (
        copy /y "Obfuscated\FerrisPulse.raw.exe" "FerrisPulse.exe" >nul
        del /f /q "FerrisPulse.raw.exe" >nul 2>&1
        rmdir /s /q "Obfuscated" >nul 2>&1
        echo [SUCCESS] Build and Obfuscation successful: FerrisPulse.exe
        exit /b 0
    )
)

echo [WARNING] Obfuscar unavailable or failed, falling back to raw binary.
move /y "FerrisPulse.raw.exe" "FerrisPulse.exe" >nul
echo [SUCCESS] Build successful (Raw): FerrisPulse.exe

endlocal
