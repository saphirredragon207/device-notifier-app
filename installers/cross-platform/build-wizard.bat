@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Building Device Notifier Setup Wizard
echo ========================================
echo.
echo This installer provides:
echo   ✓ Professional GUI wizard interface
echo   ✓ Automatic prerequisite detection/download
echo   ✓ Checksum verification and security
echo   ✓ Guided Discord integration setup
echo   ✓ System service configuration
echo   ✓ Silent install support
echo.

:: Check if PowerShell is available
powershell -Command "exit 0" >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PowerShell is required to build the setup wizard installer.
    echo Please enable PowerShell or install it from Microsoft.
    pause
    exit /b 1
)

:: Run the PowerShell script
echo Running PowerShell build script...
powershell -ExecutionPolicy Bypass -File "%~dp0build-wizard.ps1" %*

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Failed to build setup wizard installer.
    echo Check the error messages above for details.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Build completed successfully!
echo ========================================
echo.
echo The Windows setup wizard installer has been created.
echo Users can now double-click DeviceNotifier-Setup-Wizard.exe to install!
echo.
pause
