@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Building Device Notifier Windows Installer
echo ========================================

:: Check if WiX Toolset is installed
where candle >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: WiX Toolset not found. Please install WiX Toolset v3.11 or later.
    echo Download from: https://github.com/wixtoolset/wix3/releases
    exit /b 1
)

where light >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: WiX Toolset not found. Please install WiX Toolset v3.11 or later.
    echo Download from: https://github.com/wixtoolset/wix3/releases
    exit /b 1
)

:: Set paths
set "PROJECT_ROOT=%~dp0..\.."
set "AGENT_DIR=%PROJECT_ROOT%\agent"
set "GUI_DIR=%PROJECT_ROOT%\gui"
set "INSTALLER_DIR=%~dp0"
set "OUTPUT_DIR=%INSTALLER_DIR%\output"

:: Create output directory
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: Build the Rust agent
echo.
echo Building Rust agent...
cd /d "%AGENT_DIR%"
call cargo build --release
if %errorlevel% neq 0 (
    echo ERROR: Failed to build Rust agent
    exit /b 1
)

:: Build the Tauri GUI
echo.
echo Building Tauri GUI...
cd /d "%GUI_DIR%"
call npm install
if %errorlevel% neq 0 (
    echo ERROR: Failed to install npm dependencies
    exit /b 1
)

call npm run tauri build
if %errorlevel% neq 0 (
    echo ERROR: Failed to build Tauri GUI
    exit /b 1
)

:: Copy built files to installer directory
echo.
echo Copying built files...
if not exist "%INSTALLER_DIR%\files" mkdir "%INSTALLER_DIR%\files"

copy "%AGENT_DIR%\target\release\device-notifier-agent.exe" "%INSTALLER_DIR%\files\" >nul
if %errorlevel% neq 0 (
    echo ERROR: Failed to copy agent executable
    exit /b 1
)

copy "%GUI_DIR%\src-tauri\target\release\DeviceNotifier.exe" "%INSTALLER_DIR%\files\" >nul
if %errorlevel% neq 0 (
    echo ERROR: Failed to copy GUI executable
    exit /b 1
)

copy "%AGENT_DIR%\config.toml" "%INSTALLER_DIR%\files\" >nul
if %errorlevel% neq 0 (
    echo ERROR: Failed to copy config file
    exit /b 1
)

copy "%PROJECT_ROOT%\README.md" "%INSTALLER_DIR%\files\" >nul
if %errorlevel% neq 0 (
    echo ERROR: Failed to copy README
    exit /b 1
)

copy "%PROJECT_ROOT%\docs\INSTALLATION.md" "%INSTALLER_DIR%\files\" >nul
if %errorlevel% neq 0 (
    echo ERROR: Failed to copy installation docs
    exit /b 1
)

:: Copy icon if it exists
if exist "%GUI_DIR%\src-tauri\icons\icon.ico" (
    copy "%GUI_DIR%\src-tauri\icons\icon.ico" "%INSTALLER_DIR%\files\" >nul
)

:: Create license file if it doesn't exist
if not exist "%INSTALLER_DIR%\license.rtf" (
    echo Creating license file...
    (
        echo {\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}
        echo \f0\fs24
        echo \par
        echo \b Device Notifier License Agreement\b0
        echo \par
        echo \par
        echo By installing this software, you agree to the following terms:
        echo \par
        echo \par
        echo 1. This software is provided "as is" without warranty of any kind.
        echo \par
        echo 2. The software will monitor system events and send notifications to Discord.
        echo \par
        echo 3. You consent to the collection and transmission of device event data.
        echo \par
        echo 4. You can disable the service at any time through the GUI or system services.
        echo \par
        echo \par
        echo For more information, visit: https://devicenotifier.com
        echo \par
        echo }
    ) > "%INSTALLER_DIR%\license.rtf"
)

:: Build the MSI installer
echo.
echo Building MSI installer...
cd /d "%INSTALLER_DIR%"

:: Compile WiX source
echo Compiling WiX source...
candle -ext WixUtilExtension -ext WixServiceExtension installer.wxs -out installer.wixobj
if %errorlevel% neq 0 (
    echo ERROR: Failed to compile WiX source
    exit /b 1
)

:: Link WiX object files
echo Linking WiX object files...
light -ext WixUtilExtension -ext WixServiceExtension installer.wixobj -out "%OUTPUT_DIR%\DeviceNotifier.msi"
if %errorlevel% neq 0 (
    echo ERROR: Failed to link WiX object files
    exit /b 1
)

:: Clean up intermediate files
del installer.wixobj >nul 2>&1

echo.
echo ========================================
echo Build completed successfully!
echo ========================================
echo.
echo Installer created at: %OUTPUT_DIR%\DeviceNotifier.msi
echo.
echo To install, run: msiexec /i "%OUTPUT_DIR%\DeviceNotifier.msi"
echo To uninstall, run: msiexec /x "%OUTPUT_DIR%\DeviceNotifier.msi"
echo.

:: Open output directory
explorer "%OUTPUT_DIR%"

cd /d "%PROJECT_ROOT%"
