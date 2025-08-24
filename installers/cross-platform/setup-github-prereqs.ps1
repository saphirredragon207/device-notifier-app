#Requires -Version 5.1

<#
.SYNOPSIS
    Sets up a GitHub repository for Device Notifier prerequisites

.DESCRIPTION
    This script helps you create a GitHub repository structure for hosting
    all prerequisite files needed by the Device Notifier installer.

.PARAMETER GitHubUsername
    Your GitHub username for the repository

.PARAMETER RepositoryName
    Name of the repository (default: device-notifier-prereqs)

.PARAMETER OutputPath
    Local path to create the repository structure

.EXAMPLE
    .\setup-github-prereqs.ps1 -GitHubUsername "yourusername"
    
    Creates the repository structure for your GitHub account

.EXAMPLE
    .\setup-github-prereqs.ps1 -GitHubUsername "yourusername" -RepositoryName "my-prereqs"
    
    Creates a custom repository name
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$GitHubUsername,
    
    [string]$RepositoryName = "device-notifier-prereqs",
    
    [string]$OutputPath = ".\github-prereqs"
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

# Function to create directory structure
function New-RepositoryStructure {
    Write-ColorOutput "Creating repository directory structure..." "Cyan"
    
    $directories = @(
        "windows\vc_redist",
        "windows\dotnet", 
        "windows\openssl"
    )
    
    foreach ($dir in $directories) {
        $fullPath = Join-Path $OutputPath $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
            Write-ColorOutput "  Created: $dir" "Green"
        }
    }
}

# Function to download prerequisite files
function Download-Prerequisites {
    Write-ColorOutput "Downloading prerequisite files..." "Cyan"
    
    $prerequisites = @{
        "vc_redist" = @{
            "url" = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
            "filename" = "vc_redist.x64.exe"
            "path" = "windows\vc_redist"
        }
        "dotnet" = @{
            "url" = "https://go.microsoft.com/fwlink/?LinkId=2085155"
            "filename" = "ndp48-web.exe"
            "path" = "windows\dotnet"
        }
        "openssl" = @{
            "url" = "https://slproweb.com/download/Win64OpenSSL-3_0_12.exe"
            "filename" = "Win64OpenSSL-3_0_12.exe"
            "path" = "windows\openssl"
        }
    }
    
    foreach ($prereq in $prerequisites.GetEnumerator()) {
        $name = $prereq.Key
        $info = $prereq.Value
        $outputFile = Join-Path $OutputPath $info.path $info.filename
        
        Write-ColorOutput "  Downloading $name..." "Yellow"
        
        try {
            # Download with progress
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($info.url, $outputFile)
            
            if (Test-Path $outputFile) {
                $fileSize = (Get-Item $outputFile).Length
                Write-ColorOutput "    Downloaded: $($info.filename) ($([math]::Round($fileSize / 1MB, 2)) MB)" "Green"
            } else {
                Write-ColorOutput "    Failed to download: $($info.filename)" "Red"
            }
        }
        catch {
                            Write-ColorOutput "    Error downloading $($info.filename): $($_.Exception.Message)" "Red"
        }
        finally {
            if ($webClient) {
                $webClient.Dispose()
            }
        }
    }
}

# Function to generate SHA256 checksums
function Generate-Checksums {
    Write-ColorOutput "Generating SHA256 checksums..." "Cyan"
    
    $checksumFiles = @(
        "windows\vc_redist\vc_redist.x64.exe",
        "windows\dotnet\ndp48-web.exe",
        "windows\openssl\Win64OpenSSL-3_0_12.exe"
    )
    
    foreach ($file in $checksumFiles) {
        $fullPath = Join-Path $OutputPath $file
        if (Test-Path $fullPath) {
            try {
                $hash = Get-FileHash -Path $fullPath -Algorithm SHA256
                $checksumFile = "$fullPath.sha256"
                $hash.Hash | Out-File -FilePath $checksumFile -Encoding ASCII
                
                Write-ColorOutput "  Generated checksum: $file" "Green"
                Write-ColorOutput "    Hash: $($hash.Hash)" "Gray"
            }
            catch {
                Write-ColorOutput "  Failed to generate checksum for $file - $($_.Exception.Message)" "Red"
            }
        }
    }
}

# Function to create checksums.json
function New-ChecksumsJson {
    Write-ColorOutput "Creating checksums.json..." "Cyan"
    
    $checksums = @{
        windows = @{
            vc_redist = @{
                "vc_redist.x64.exe" = @{
                    url = "https://github.com/$GitHubUsername/$RepositoryName/raw/main/windows/vc_redist/vc_redist.x64.exe"
                    sha256 = ""
                    version = "14.38.33130.0"
                    description = "Visual C++ Redistributable 2015-2022 for x64"
                }
            }
            dotnet = @{
                "ndp48-web.exe" = @{
                    url = "https://github.com/$GitHubUsername/$RepositoryName/raw/main/windows/dotnet/ndp48-web.exe"
                    sha256 = ""
                    version = "4.8.03761"
                    description = "Microsoft .NET Framework 4.8 Web Installer"
                }
            }
            openssl = @{
                "Win64OpenSSL-3_0_12.exe" = @{
                    url = "https://github.com/$GitHubUsername/$RepositoryName/raw/main/windows/openssl/Win64OpenSSL-3_0_12.exe"
                    sha256 = ""
                    version = "3.0.12"
                    description = "OpenSSL 3.0.12 for Windows x64"
                }
            }
        }
    }
    
    # Read actual checksums
    $checksumFiles = @(
        "windows\vc_redist\vc_redist.x64.exe.sha256",
        "windows\dotnet\ndp48-web.exe.sha256",
        "windows\openssl\Win64OpenSSL-3_0_12.exe.sha256"
    )
    
    foreach ($file in $checksumFiles) {
        $fullPath = Join-Path $OutputPath $file
        if (Test-Path $fullPath) {
            $hash = Get-Content $fullPath -Raw
            $hash = $hash.Trim()
            
            # Update the appropriate checksum in the JSON
            if ($file -like "*vc_redist*") {
                $checksums.windows.vc_redist."vc_redist.x64.exe".sha256 = $hash
            }
            elseif ($file -like "*dotnet*") {
                $checksums.windows.dotnet."ndp48-web.exe".sha256 = $hash
            }
            elseif ($file -like "*openssl*") {
                $checksums.windows.openssl."Win64OpenSSL-3_0_12.exe".sha256 = $hash
            }
        }
    }
    
    $jsonPath = Join-Path $OutputPath "checksums.json"
    $checksums | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
    
    Write-ColorOutput "  Created checksums.json" "Green"
}

# Function to create README.md
function New-RepositoryReadme {
    Write-ColorOutput "Creating repository README..." "Cyan"
    
    $readmeContent = @"
# Device Notifier Prerequisites

This repository contains all prerequisite files needed for the Device Notifier installer.

## Contents

### Windows Prerequisites
# - **Visual C++ Redistributable 2015-2022**: Runtime libraries for C++ applications
# - **Microsoft .NET Framework 4.8**: .NET runtime environment
# - **OpenSSL 3.0**: SSL/TLS cryptography library

## File Structure
\`\`\`
$RepositoryName/
├── windows/
│   ├── vc_redist/
│   │   ├── vc_redist.x64.exe
│   │   └── vc_redist.x64.exe.sha256
│   ├── dotnet/
│   │   ├── ndp48-web.exe
│   │   └── ndp48-web.exe.sha256
│   └── openssl/
│       ├── Win64OpenSSL-3_0_12.exe
│       └── Win64OpenSSL-3_0_12.exe.sha256
├── checksums.json
└── README.md
\`\`\`

## Usage

The Device Notifier installer will automatically download these files from this repository during installation.

## Security

All files include SHA256 checksums for verification. The installer validates these checksums before installation.

## Updates

This repository is updated when new versions of prerequisites become available.

## License

These files are redistributed according to their respective licenses:
- Visual C++ Redistributable: Microsoft License
- .NET Framework: Microsoft License  
- OpenSSL: Apache License 2.0

## Support

For issues with the Device Notifier installer, please visit the main project repository.
"@

    $readmePath = Join-Path $OutputPath "README.md"
    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
    
            Write-ColorOutput "  Created README.md" "Green"
}

# Function to create .gitignore
function New-GitIgnore {
    Write-ColorOutput "Creating .gitignore..." "Cyan"
    
    $gitignoreContent = @"
# Temporary files
*.tmp
*.temp

# Log files
*.log

# Backup files
*.bak
*.backup

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE files
.vscode/
.idea/
*.swp
*.swo

# Build artifacts
build/
dist/
*.exe
*.msi
*.pkg
"@

    $gitignorePath = Join-Path $OutputPath ".gitignore"
    $gitignoreContent | Out-File -FilePath $gitignorePath -Encoding UTF8
    
            Write-ColorOutput "  Created .gitignore" "Green"
}

# Function to create GitHub setup instructions
function New-GitHubSetupInstructions {
    Write-ColorOutput "Creating GitHub setup instructions..." "Cyan"
    
    $instructionsContent = @"
# GitHub Repository Setup Instructions

## 1. Create the Repository

1. Go to [GitHub](https://github.com) and sign in
2. Click the "+" icon in the top right corner
3. Select "New repository"
4. Repository name: \`$RepositoryName\`
5. Description: "Prerequisites for Device Notifier installer"
6. Make it **Public** (recommended for open source)
7. Don't initialize with README (we'll create our own)
8. Click "Create repository"

## 2. Upload Files

### Option A: Using GitHub Web Interface
1. Click "uploading an existing file"
2. Drag and drop all files from the \`$OutputPath\` folder
3. Add commit message: "Initial commit: Add prerequisite files"
4. Click "Commit changes"

### Option B: Using Git Command Line
\`\`\`bash
# Clone the repository
git clone https://github.com/$GitHubUsername/$RepositoryName.git
cd $RepositoryName

# Copy all files from the setup folder
xcopy /E /I "$OutputPath" .

# Add and commit files
git add .
git commit -m "Initial commit: Add prerequisite files"
git push origin main
\`\`\`

## 3. Verify Setup

1. Check that all files are visible in the repository
2. Verify download URLs work:
   - https://github.com/$GitHubUsername/$RepositoryName/raw/main/windows/vc_redist/vc_redist.x64.exe
   - https://github.com/$GitHubUsername/$RepositoryName/raw/main/windows/dotnet/ndp48-web.exe
   - https://github.com/$GitHubUsername/$RepositoryName/raw/main/windows/openssl/Win64OpenSSL-3_0_12.exe

## 4. Update Installer Scripts

Update the following files in your Device Notifier project:

### setup-wizard.iss
Replace \`YOUR_USERNAME\` with \`$GitHubUsername\` in the prerequisite URLs.

### build-wizard.ps1  
Update the \`prereqSources\` URLs in the silent install configuration.

## 5. Test the Installer

1. Build the installer using the updated scripts
2. Test on a clean system
3. Verify all prerequisites download successfully
4. Check that checksum verification works

## Repository URL
https://github.com/$GitHubUsername/$RepositoryName
"@

    $instructionsPath = Join-Path $OutputPath "GITHUB_SETUP.md"
    $instructionsContent | Out-File -FilePath $instructionsPath -Encoding UTF8
    
            Write-ColorOutput "  Created GitHub setup instructions" "Green"
}

# Main execution
function Main {
    Write-ColorOutput "========================================" "Green"
    Write-ColorOutput "Setting up GitHub Prerequisites Repository" "Green"
    Write-ColorOutput "========================================" "Green"
    Write-Host ""
    Write-ColorOutput "GitHub Username: $GitHubUsername" "Cyan"
    Write-ColorOutput "Repository Name: $RepositoryName" "Cyan"
    Write-ColorOutput "Output Path: $OutputPath" "Cyan"
    Write-Host ""

    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Create repository structure
    New-RepositoryStructure

    # Download prerequisites
    Download-Prerequisites

    # Generate checksums
    Generate-Checksums

    # Create checksums.json
    New-ChecksumsJson

    # Create README.md
    New-RepositoryReadme

    # Create .gitignore
    New-GitIgnore

    # Create GitHub setup instructions
    New-GitHubSetupInstructions

    # Success message
    Write-Host ""
    Write-ColorOutput "========================================" "Green"
    Write-ColorOutput "Setup completed successfully!" "Green"
    Write-ColorOutput "========================================" "Green"
    Write-Host ""
    Write-ColorOutput "Repository structure created at: $OutputPath" "Yellow"
    Write-ColorOutput "Next steps:" "Cyan"
    Write-ColorOutput "  1. Review the files in $OutputPath" "White"
    Write-ColorOutput "  2. Follow GITHUB_SETUP.md instructions" "White"
    Write-ColorOutput "  3. Create the GitHub repository" "White"
    Write-ColorOutput "  4. Upload all files to GitHub" "White"
    Write-ColorOutput "  5. Update installer scripts with new URLs" "White"
    Write-Host ""
    Write-ColorOutput "Repository will be available at:" "Cyan"
    Write-ColorOutput "  https://github.com/$GitHubUsername/$RepositoryName" "Yellow"
    Write-Host ""

    # Open output directory
    if (Test-Path $OutputPath) {
        Start-Process $OutputPath
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
