#Requires -Version 5.1

<#
.SYNOPSIS
    Builds the Windows setup wizard installer for Device Notifier

.DESCRIPTION
    This script creates a professional Windows setup wizard installer that:
    1. Provides a guided GUI wizard interface
    2. Automatically detects and downloads prerequisites
    3. Verifies downloads with checksums
    4. Builds and installs the application
    5. Configures Discord integration
    6. Sets up system services and startup options

.PARAMETER OutputPath
    Custom output path for the installer

.EXAMPLE
    .\build-wizard.ps1
    Builds the Windows setup wizard installer

.EXAMPLE
    .\build-wizard.ps1 -OutputPath "C:\CustomOutput\"
    Builds the installer to a custom output directory
#>

param(
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

# Function to check if Inno Setup is installed
function Test-InnoSetup {
    $innoSetupPath = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    if (Test-Path $innoSetupPath) {
        return $innoSetupPath
    }

    $innoSetupPath = "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    if (Test-Path $innoSetupPath) {
        return $innoSetupPath
    }

    # Check if it's in PATH
    try {
        $null = Get-Command "ISCC" -ErrorAction Stop
        return "ISCC"
    }
    catch {
        return $null
    }
}

# Function to install Inno Setup
function Install-InnoSetup {
    Write-ColorOutput "Inno Setup not found. Installing..." "Yellow"

    $downloadUrl = "https://files.jrsoftware.org/is/6/innosetup-6.2.2.exe"
    $installerPath = "$env:TEMP\innosetup-installer.exe"

    try {
        Write-ColorOutput "Downloading Inno Setup..." "Cyan"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

        Write-ColorOutput "Installing Inno Setup..." "Cyan"
        Start-Process -FilePath $installerPath -ArgumentList "/SILENT" -Wait

        # Wait a moment for installation to complete
        Start-Sleep -Seconds 5

        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        # Check if installation was successful
        $innoSetupPath = Test-InnoSetup
        if ($innoSetupPath) {
            Write-ColorOutput "Inno Setup installed successfully!" "Green"
            return $innoSetupPath
        } else {
            throw "Inno Setup installation failed"
        }
    }
    catch {
        Write-ColorOutput "Failed to install Inno Setup automatically." "Red"
        Write-ColorOutput "Please download and install manually from: https://jrsoftware.org/isdl.php" "Yellow"
        Write-ColorOutput "Then run this script again." "Yellow"
        exit 1
    }
    finally {
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force
        }
    }
}

# Function to create license file
function New-LicenseFile {
    $licenseFile = Join-Path $script:InstallerDir "license.txt"
    if (-not (Test-Path $licenseFile)) {
        Write-ColorOutput "Creating license file..." "Yellow"

        $licenseContent = @"
Device Notifier License Agreement

By installing this software, you agree to the following terms:

1. This software is provided "as is" without warranty of any kind.
2. The software will monitor system events and send notifications to Discord.
3. You consent to the collection and transmission of device event data.
4. You can disable the service at any time through the GUI or system services.
5. Remote command execution is disabled by default for security.

Privacy Summary:
• Device events (login/logout, system health) are sent to Discord
• No passwords or personal data are transmitted
• All data is encrypted in transit
• Local audit logs are stored securely

For more information, visit: https://devicenotifier.com
"@

        $licenseContent | Out-File -FilePath $licenseFile -Encoding UTF8
    }
}

# Function to create files directory structure
function New-FilesDirectory {
    $filesDir = Join-Path $script:InstallerDir "files"
    if (-not (Test-Path $filesDir)) {
        New-Item -ItemType Directory -Path $filesDir -Force | Out-Null
    }

    # Create a placeholder file to ensure the directory is included
    $placeholderFile = Join-Path $filesDir "README.txt"
    if (-not (Test-Path $placeholderFile)) {
        "This installer will automatically download and build the Device Notifier application." | Out-File -FilePath $placeholderFile -Encoding UTF8
    }
}

# Function to create GitHub prerequisites setup guide
function New-GitHubPrereqsGuide {
    $guideFile = Join-Path $script:InstallerDir "GITHUB_PREREQS_SETUP.md"
    if (-not (Test-Path $guideFile)) {
        Write-ColorOutput "Creating GitHub prerequisites setup guide..." "Yellow"

        $guideContent = @"
# GitHub Prerequisites Repository Setup

This guide helps you set up a GitHub repository to host all prerequisite files for the Device Notifier installer.

## Why Use GitHub for Prerequisites?

- **Reliability**: GitHub's CDN ensures fast, reliable downloads
- **Security**: All files are hosted on a trusted platform
- **Version Control**: Track changes and rollback if needed
- **Checksums**: Store verified SHA256 checksums
- **Signatures**: Optional PGP signature verification

## Repository Setup

### 1. Create the Repository
```bash
# Create a new repository on GitHub
# Name: device-notifier-prereqs
# Description: Prerequisites for Device Notifier installer
# Public or Private (Public recommended for open source)
```

### 2. Repository Structure
```
device-notifier-prereqs/
├── windows/
│   ├── vc_redist/
│   │   ├── vc_redist.x64.exe
│   │   ├── vc_redist.x64.exe.sha256
│   │   └── vc_redist.x64.exe.sig
│   ├── dotnet/
│   │   ├── ndp48-web.exe
│   │   ├── ndp48-web.exe.sha256
│   │   └── ndp48-web.exe.sig
│   └── openssl/
│       ├── Win64OpenSSL-3_0_12.exe
│       ├── Win64OpenSSL-3_0_12.exe.sha256
│       └── Win64OpenSSL-3_0_12.exe.sig
├── checksums.json
└── README.md
```

### 3. Download Prerequisites

#### Visual C++ Redistributable 2015-2022
```bash
# Download from Microsoft
curl -L -o windows/vc_redist/vc_redist.x64.exe "https://aka.ms/vs/17/release/vc_redist.x64.exe"

# Generate SHA256 checksum
sha256sum windows/vc_redist/vc_redist.x64.exe > windows/vc_redist/vc_redist.x64.exe.sha256
```

#### .NET Framework 4.8
```bash
# Download from Microsoft
curl -L -o windows/dotnet/ndp48-web.exe "https://go.microsoft.com/fwlink/?LinkId=2085155"

# Generate SHA256 checksum
sha256sum windows/dotnet/ndp48-web.exe > windows/dotnet/ndp48-web.exe.sha256
```

#### OpenSSL 3.0
```bash
# Download from OpenSSL
curl -L -o windows/openssl/Win64OpenSSL-3_0_12.exe "https://slproweb.com/download/Win64OpenSSL-3_0_12.exe"

# Generate SHA256 checksum
sha256sum windows/openssl/Win64OpenSSL-3_0_12.exe > windows/openssl/Win64OpenSSL-3_0_12.exe.sha256
```

### 4. Create checksums.json
```json
{
  "windows": {
    "vc_redist": {
      "vc_redist.x64.exe": {
        "url": "https://github.com/yourusername/device-notifier-prereqs/raw/main/windows/vc_redist/vc_redist.x64.exe",
        "sha256": "ACTUAL_SHA256_HASH_HERE",
        "version": "14.38.33130.0",
        "description": "Visual C++ Redistributable 2015-2022 for x64"
      }
    },
    "dotnet": {
      "ndp48-web.exe": {
        "url": "https://github.com/yourusername/device-notifier-prereqs/raw/main/windows/dotnet/ndp48-web.exe",
        "sha256": "ACTUAL_SHA256_HASH_HERE",
        "version": "4.8.03761",
        "description": "Microsoft .NET Framework 4.8 Web Installer"
      }
    },
    "openssl": {
      "Win64OpenSSL-3_0_12.exe": {
        "url": "https://github.com/yourusername/device-notifier-prereqs/raw/main/windows/openssl/Win64OpenSSL-3_0_12.exe",
        "sha256": "ACTUAL_SHA256_HASH_HERE",
        "version": "3.0.12",
        "description": "OpenSSL 3.0.12 for Windows x64"
      }
    }
  }
}
```

### 5. Update Installer Scripts

#### In setup-wizard.iss
```pascal
// Update the GetPrereqDownloadUrl function
function GetPrereqDownloadUrl(const PrereqName: String): String;
begin
  if PrereqName = 'Visual C++ Redistributable 2015-2022' then
    Result := 'https://github.com/YOUR_USERNAME/device-notifier-prereqs/raw/main/windows/vc_redist/vc_redist.x64.exe'
  else if PrereqName = 'Microsoft .NET Framework 4.8' then
    Result := 'https://github.com/YOUR_USERNAME/device-notifier-prereqs/raw/main/windows/dotnet/ndp48-web.exe'
  else if PrereqName = 'OpenSSL 3.0' then
    Result := 'https://github.com/YOUR_USERNAME/device-notifier-prereqs/raw/main/windows/openssl/Win64OpenSSL-3_0_12.exe'
  else
    Result := '';
end;

// Update the GetPrereqChecksum function with actual hashes
function GetPrereqChecksum(const PrereqName: String): String;
begin
  if PrereqName = 'Visual C++ Redistributable 2015-2022' then
    Result := 'ACTUAL_SHA256_HASH_HERE'
  else if PrereqName = 'Microsoft .NET Framework 4.8' then
    Result := 'ACTUAL_SHA256_HASH_HERE'
  else if PrereqName = 'OpenSSL 3.0' then
    Result := 'ACTUAL_SHA256_HASH_HERE'
  else
    Result := '';
end;
```

#### In build-wizard.ps1
```powershell
# Update the silent install configuration
$configContent = @{
  # ... existing config ...
  prereqSources = @{
    vcruntime = "https://github.com/YOUR_USERNAME/device-notifier-prereqs/raw/main/windows/vc_redist/vc_redist.x64.exe"
    dotnet = "https://github.com/YOUR_USERNAME/device-notifier-prereqs/raw/main/windows/dotnet/ndp48-web.exe"
    openssl = "https://github.com/YOUR_USERNAME/device-notifier-prereqs/raw/main/windows/openssl/Win64OpenSSL-3_0_12.exe"
  }
  # ... rest of config ...
}
```

## Benefits

### For Users
- **Faster Downloads**: GitHub's global CDN
- **Reliable Access**: No broken external links
- **Security**: Verified checksums and signatures
- **Transparency**: Source code and files are public

### For Developers
- **Version Control**: Track prerequisite changes
- **Automation**: CI/CD integration possible
- **Testing**: Easy to test different versions
- **Distribution**: Single source of truth

## Maintenance

### Regular Updates
1. **Check for Updates**: Monitor for new versions
2. **Download New Files**: Get latest versions
3. **Generate Checksums**: Create new SHA256 hashes
4. **Update Repository**: Commit and push changes
5. **Test Installer**: Verify everything works

### Automation
```bash
# Example GitHub Action for auto-updates
name: Update Prerequisites
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday

jobs:
  update-prereqs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Download and verify prerequisites
        run: |
          # Download scripts here
      - name: Commit and push changes
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add .
          git commit -m "Update prerequisites"
          git push
```

## Security Considerations

### Checksum Verification
- Always verify SHA256 checksums
- Store checksums in the repository
- Use checksums in the installer

### Signature Verification (Optional)
- PGP sign all files
- Store public keys in repository
- Verify signatures during installation

### Access Control
- Public repository for transparency
- Branch protection for main branch
- Required reviews for changes

## Troubleshooting

### Common Issues
1. **File Not Found**: Check repository structure and URLs
2. **Checksum Mismatch**: Redownload and regenerate checksums
3. **Access Denied**: Verify repository is public or user has access
4. **Download Slow**: Check GitHub status and CDN performance

### Verification Commands
```bash
# Verify checksums
sha256sum -c *.sha256

# Test download URLs
curl -I "https://github.com/yourusername/device-notifier-prereqs/raw/main/windows/vc_redist/vc_redist.x64.exe"

# Check file sizes
ls -la windows/*/
```

---

**Next Steps:**
1. Create the GitHub repository
2. Download and organize prerequisite files
3. Generate checksums and signatures
4. Update installer scripts with new URLs
5. Test the installer with GitHub-hosted files
6. Set up automated updates if desired
"@

        $guideContent | Out-File -FilePath $guideFile -Encoding UTF8
        Write-ColorOutput "✓ GitHub prerequisites setup guide created" "Green"
    }
}

# Function to build Windows installer
function Build-WindowsInstaller {
    Write-ColorOutput "Building Windows setup wizard installer..." "Cyan"

    Push-Location (Join-Path $script:InstallerDir "windows")

    try {
        # Check if Inno Setup is available
        $innoSetupPath = Test-InnoSetup
        if (-not $innoSetupPath) {
            $innoSetupPath = Install-InnoSetup
        }

        Write-ColorOutput "Using Inno Setup at: $innoSetupPath" "Yellow"

        # Build the installer
        Write-ColorOutput "Compiling setup wizard installer..." "Yellow"
        $process = Start-Process -FilePath $innoSetupPath -ArgumentList "setup-wizard.iss" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -ne 0) {
            throw "Failed to build Windows installer (exit code: $($process.ExitCode))"
        }

        # Check if installer was created
        $installerPath = Join-Path $script:OutputDir "DeviceNotifier-Setup-Wizard.exe"
        if (-not (Test-Path $installerPath)) {
            throw "Windows installer was not created at expected location: $installerPath"
        }

        Write-ColorOutput "Windows installer created successfully!" "Green"
    }
    finally {
        Pop-Location
    }
}

# Function to create silent install configuration
function New-SilentInstallConfig {
    $configFile = Join-Path $script:InstallerDir "silent-install-config.json"
    if (-not (Test-Path $configFile)) {
        Write-ColorOutput "Creating silent install configuration..." "Yellow"

        $configContent = @{
            installScope = "system"
            installDir = "C:\Program Files\DeviceNotifier"
            components = @("agent", "gui", "sampleBot")
            startOnBoot = $true
            createShortcuts = $true
            discordConfig = @{
                botToken = "REDACTED"
                defaultChannelId = "123456789012345678"
                authorizedRoleIds = @("987654321098765432")
            }
            prereqSources = @{
                vcruntime = "https://github.com/saphirredragon207/device-notifier-app/raw/main/prerequisites/windows/vc_redist/vc_redist.x64.exe"
                dotnet = "https://github.com/saphirredragon207/device-notifier-app/raw/main/prerequisites/windows/dotnet/ndp48-web.exe"
                openssl = "https://github.com/saphirredragon207/device-notifier-app/raw/main/prerequisites/windows/openssl/Win64OpenSSL_Light-3_5_2.exe"
            }
            verifySha256 = $true
            acceptLicense = $true
        } | ConvertTo-Json -Depth 10

        $configContent | Out-File -FilePath $configFile -Encoding UTF8
    }
}

# Function to create build documentation
function New-BuildDocumentation {
    $docFile = Join-Path $script:InstallerDir "BUILD_INSTRUCTIONS.md"
    if (-not (Test-Path $docFile)) {
        Write-ColorOutput "Creating build documentation..." "Yellow"

        $docContent = @"
# Device Notifier Setup Wizard - Windows Build Instructions

## Overview
This installer provides a professional Windows setup wizard that guides users through installing Device Notifier with automatic prerequisite management and Discord integration setup.

## Features
- **Guided Wizard Interface**: Step-by-step installation process
- **Automatic Prerequisites**: Downloads and installs required components
- **Checksum Verification**: Ensures download integrity
- **Discord Integration**: Optional bot configuration during install
- **System Integration**: Automatic service setup and startup configuration
- **Silent Install**: Support for automated deployments

## Building the Installer

### Prerequisites
- **Windows 10/11**: Required for modern installer features
- **PowerShell 5.1+**: Required for build script
- **Internet Connection**: For downloading prerequisites

### Build Commands
```powershell
# Build Windows installer
.\build-wizard.ps1

# Custom output directory
.\build-wizard.ps1 -OutputPath "C:\CustomOutput\"
```

## Silent Installation

### Command Line
```cmd
# Windows silent install
DeviceNotifier-Setup-Wizard.exe /SILENT /CONFIG=config.json

# With custom configuration
DeviceNotifier-Setup-Wizard.exe /SILENT /DIR="C:\CustomPath" /TASKS="desktopicon,startup"
```

### Configuration File
Create a `silent-install-config.json` file with your preferences:
```json
{
  "installScope": "system",
  "installDir": "C:\\Program Files\\DeviceNotifier",
  "startOnBoot": true,
  "discordConfig": {
    "botToken": "YOUR_BOT_TOKEN",
    "defaultChannelId": "CHANNEL_ID"
  }
}
```

## Customization

### Windows (Inno Setup)
Edit `setup-wizard.iss`:
- Modify wizard pages and flow
- Add custom prerequisite checks
- Customize installation options
- Update branding and styling

### Build Scripts
Edit `build-wizard.ps1`:
- Modify prerequisite URLs and checksums
- Customize build process
- Update installer metadata

## Distribution

### Code Signing
```powershell
# Sign with Authenticode certificate
Set-AuthenticodeSignature -FilePath "DeviceNotifier-Setup-Wizard.exe" -Certificate $cert
```

### Windows Store
- Package as MSIX for Microsoft Store distribution
- Use App Installer for enterprise deployment

## Troubleshooting

### Common Issues
1. **Prerequisites fail to download**: Check internet connection and firewall
2. **Checksum verification fails**: Redownload or check source URLs
3. **Installation fails**: Check admin privileges and system requirements
4. **Inno Setup not found**: Script will automatically download and install

### Logs
- **Installation**: Check `%TEMP%\DeviceNotifier-Install.log`
- **System**: Check Event Viewer for system logs
- **Application**: Check `%APPDATA%\DeviceNotifier\logs`

## Security Features
- HTTPS downloads with certificate validation
- SHA256 checksum verification
- Optional signature verification
- Secure Discord token handling
- Minimal privilege elevation
- Audit logging

## Support
For issues and questions:
- GitHub: https://github.com/devicenotifier
- Documentation: https://devicenotifier.com/docs
- Discord: https://discord.gg/devicenotifier
"@

        $docContent | Out-File -FilePath $docFile -Encoding UTF8
    }
}

# Main execution
function Main {
    Write-ColorOutput "========================================" "Green"
    Write-ColorOutput "Building Device Notifier Setup Wizard" "Green"
    Write-ColorOutput "========================================" "Green"
    Write-Host ""
    Write-ColorOutput "This installer provides:" "Cyan"
    Write-ColorOutput "  ✓ Professional GUI wizard interface" "White"
    Write-ColorOutput "  ✓ Automatic prerequisite detection/download" "White"
    Write-ColorOutput "  ✓ Checksum verification and security" "White"
    Write-ColorOutput "  ✓ Guided Discord integration setup" "White"
    Write-ColorOutput "  ✓ System service configuration" "White"
    Write-ColorOutput "  ✓ Silent install support" "White"
    Write-Host ""

    # Set paths
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
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

    # Create files directory and license
    New-FilesDirectory
    New-LicenseFile

    # Create silent install configuration
    New-SilentInstallConfig

    # Create GitHub prerequisites setup guide
    New-GitHubPrereqsGuide

    # Create build documentation
    New-BuildDocumentation

    # Build Windows installer
    Build-WindowsInstaller

    # Success message
    Write-Host ""
    Write-ColorOutput "========================================" "Green"
    Write-ColorOutput "Build completed successfully!" "Green"
    Write-ColorOutput "========================================" "Green"
    Write-Host ""

    Write-ColorOutput "Windows installer created at: $($script:OutputDir)\DeviceNotifier-Setup-Wizard.exe" "Yellow"

    Write-Host ""
    Write-ColorOutput "🎉 Professional Windows setup wizard installer ready!" "Cyan"
    Write-Host ""
    Write-ColorOutput "Features of the setup wizard:" "Cyan"
    Write-ColorOutput "  ✓ Guided installation process" "White"
    Write-ColorOutput "  ✓ Automatic prerequisite management" "White"
    Write-ColorOutput "  ✓ Security and integrity verification" "White"
    Write-ColorOutput "  ✓ Discord integration setup" "White"
    Write-ColorOutput "  ✓ System service configuration" "White"
    Write-ColorOutput "  ✓ Silent install support" "White"
    Write-ColorOutput "  ✓ Professional user experience" "White"
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
