#Requires -Version 5.1

<#
.SYNOPSIS
    Builds Device Notifier Windows MSI installer using WiX Toolset

.DESCRIPTION
    This script builds the Device Notifier application and creates a Windows MSI installer.
    It requires WiX Toolset v3.11 or later to be installed.

.PARAMETER SkipBuild
    Skip building the Rust agent and Tauri GUI (use pre-built binaries)

.PARAMETER OutputPath
    Custom output path for the MSI installer

.EXAMPLE
    .\build-msi.ps1
    Builds the installer with default settings

.EXAMPLE
    .\build-msi.ps1 -SkipBuild
    Builds the installer using pre-built binaries

.EXAMPLE
    .\build-msi.ps1 -OutputPath "C:\CustomOutput\"
    Builds the installer to a custom output directory
#>

param(
    [switch]$SkipBuild,
    [string]$OutputPath
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to check if command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Function to check WiX Toolset installation
function Test-WiXToolset {
    if (-not (Test-Command "candle")) {
        Write-ColorOutput "ERROR: WiX Toolset not found. Please install WiX Toolset v3.11 or later." "Red"
        Write-ColorOutput "Download from: https://github.com/wixtoolset/wix3/releases" "Yellow"
        Write-ColorOutput "Or install via Chocolatey: choco install wixtoolset" "Yellow"
        return $false
    }
    
    if (-not (Test-Command "light")) {
        Write-ColorOutput "ERROR: WiX Toolset not found. Please install WiX Toolset v3.11 or later." "Red"
        Write-ColorOutput "Download from: https://github.com/wixtoolset/wix3/releases" "Yellow"
        return $false
    }
    
    return $true
}

# Function to build Rust agent
function Build-RustAgent {
    Write-ColorOutput "Building Rust agent..." "Cyan"
    
    Push-Location $script:AgentDir
    try {
        $process = Start-Process -FilePath "cargo" -ArgumentList "build", "--release" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -ne 0) {
            throw "Failed to build Rust agent (exit code: $($process.ExitCode))"
        }
    }
    finally {
        Pop-Location
    }
}

# Function to build Tauri GUI
function Build-TauriGUI {
    Write-ColorOutput "Building Tauri GUI..." "Cyan"
    
    Push-Location $script:GuiDir
    try {
        # Install npm dependencies
        Write-ColorOutput "Installing npm dependencies..." "Yellow"
        $process = Start-Process -FilePath "npm" -ArgumentList "install" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -ne 0) {
            throw "Failed to install npm dependencies (exit code: $($process.ExitCode))"
        }
        
        # Build Tauri application
        Write-ColorOutput "Building Tauri application..." "Yellow"
        $process = Start-Process -FilePath "npm" -ArgumentList "run", "tauri", "build" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -ne 0) {
            throw "Failed to build Tauri GUI (exit code: $($process.ExitCode))"
        }
    }
    finally {
        Pop-Location
    }
}

# Function to copy built files
function Copy-BuiltFiles {
    Write-ColorOutput "Copying built files..." "Cyan"
    
    # Create files directory if it doesn't exist
    $filesDir = Join-Path $script:InstallerDir "files"
    if (-not (Test-Path $filesDir)) {
        New-Item -ItemType Directory -Path $filesDir -Force | Out-Null
    }
    
    # Copy agent executable
    $agentExe = Join-Path $script:AgentDir "target\release\device-notifier-agent.exe"
    if (-not (Test-Path $agentExe)) {
        throw "Agent executable not found at: $agentExe"
    }
    Copy-Item $agentExe (Join-Path $filesDir "device-notifier-agent.exe") -Force
    
    # Copy GUI executable
    $guiExe = Join-Path $script:GuiDir "src-tauri\target\release\DeviceNotifier.exe"
    if (-not (Test-Path $guiExe)) {
        throw "GUI executable not found at: $guiExe"
    }
    Copy-Item $guiExe (Join-Path $filesDir "DeviceNotifier.exe") -Force
    
    # Copy configuration files
    $configFile = Join-Path $script:AgentDir "config.toml"
    if (Test-Path $configFile) {
        Copy-Item $configFile (Join-Path $filesDir "config.toml") -Force
    }
    
    # Copy documentation
    $readmeFile = Join-Path $script:ProjectRoot "README.md"
    if (Test-Path $readmeFile) {
        Copy-Item $readmeFile (Join-Path $filesDir "README.md") -Force
    }
    
    $installDoc = Join-Path $script:ProjectRoot "docs\INSTALLATION.md"
    if (Test-Path $installDoc) {
        Copy-Item $installDoc (Join-Path $filesDir "INSTALLATION.md") -Force
    }
    
    # Copy icon if it exists
    $iconFile = Join-Path $script:GuiDir "src-tauri\icons\icon.ico"
    if (Test-Path $iconFile) {
        Copy-Item $iconFile (Join-Path $filesDir "icon.ico") -Force
    }
}

# Function to create license file
function New-LicenseFile {
    $licenseFile = Join-Path $script:InstallerDir "license.rtf"
    if (-not (Test-Path $licenseFile)) {
        Write-ColorOutput "Creating license file..." "Yellow"
        
        $licenseContent = @"
{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}
\f0\fs24
\par
\b Device Notifier License Agreement\b0
\par
\par
By installing this software, you agree to the following terms:
\par
\par
1. This software is provided "as is" without warranty of any kind.
\par
2. The software will monitor system events and send notifications to Discord.
\par
3. You consent to the collection and transmission of device event data.
\par
4. You can disable the service at any time through the GUI or system services.
\par
\par
For more information, visit: https://devicenotifier.com
\par
}
"@
        
        $licenseContent | Out-File -FilePath $licenseFile -Encoding ASCII
    }
}

# Function to build MSI installer
function Build-MSIInstaller {
    Write-ColorOutput "Building MSI installer..." "Cyan"
    
    Push-Location $script:InstallerDir
    
    try {
        # Compile WiX source
        Write-ColorOutput "Compiling WiX source..." "Yellow"
        $process = Start-Process -FilePath "candle" -ArgumentList "-ext", "WixUtilExtension", "-ext", "WixServiceExtension", "installer.wxs", "-out", "installer.wixobj" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -ne 0) {
            throw "Failed to compile WiX source (exit code: $($process.ExitCode))"
        }
        
        # Link WiX object files
        Write-ColorOutput "Linking WiX object files..." "Yellow"
        $msiOutput = Join-Path $script:OutputDir "DeviceNotifier.msi"
        $process = Start-Process -FilePath "light" -ArgumentList "-ext", "WixUtilExtension", "-ext", "WixServiceExtension", "installer.wixobj", "-out", $msiOutput -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -ne 0) {
            throw "Failed to link WiX object files (exit code: $($process.ExitCode))"
        }
        
        # Clean up intermediate files
        if (Test-Path "installer.wixobj") {
            Remove-Item "installer.wixobj" -Force
        }
    }
    finally {
        Pop-Location
    }
}

# Main execution
function Main {
    Write-ColorOutput "========================================" "Green"
    Write-ColorOutput "Building Device Notifier Windows Installer" "Green"
    Write-ColorOutput "========================================" "Green"
    Write-Host ""
    
    # Check WiX Toolset
    if (-not (Test-WiXToolset)) {
        exit 1
    }
    
    # Set paths
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:AgentDir = Join-Path $script:ProjectRoot "agent"
    $script:GuiDir = Join-Path $script:ProjectRoot "gui"
    $script:InstallerDir = $PSScriptRoot
    
    # Set output directory
    if ($OutputPath) {
        $script:OutputDir = $OutputPath
    } else {
        $script:OutputDir = Join-Path $script:InstallerDir "output"
    }
    
    # Create output directory
    if (-not (Test-Path $script:OutputDir)) {
        New-Item -ItemType Directory -Path $script:OutputDir -Force | Out-Null
    }
    
    # Build components if not skipped
    if (-not $SkipBuild) {
        Build-RustAgent
        Build-TauriGUI
    }
    
    # Copy built files
    Copy-BuiltFiles
    
    # Create license file
    New-LicenseFile
    
    # Build MSI installer
    Build-MSIInstaller
    
    # Success message
    Write-Host ""
    Write-ColorOutput "========================================" "Green"
    Write-ColorOutput "Build completed successfully!" "Green"
    Write-ColorOutput "========================================" "Green"
    Write-Host ""
    Write-ColorOutput "Installer created at: $($script:OutputDir)\DeviceNotifier.msi" "Yellow"
    Write-Host ""
    Write-ColorOutput "To install, run: msiexec /i `"$($script:OutputDir)\DeviceNotifier.msi`"" "Cyan"
    Write-ColorOutput "To uninstall, run: msiexec /x `"$($script:OutputDir)\DeviceNotifier.msi`"" "Cyan"
    Write-Host ""
    
    # Open output directory
    if (Test-Path $script:OutputDir) {
        Start-Process $script:OutputDir
    }
}

# Run main function
try {
    Main
}
catch {
    Write-ColorOutput "ERROR: $($_.Exception.Message)" "Red"
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Red"
    exit 1
}
