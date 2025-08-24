# GitHub Prerequisites Setup - Single Repository

This guide helps you set up prerequisite files directly in your main Device Notifier repository.

## Repository Structure

Instead of creating a separate repository, we'll add a `prerequisites/` folder to your existing `device-notifier-app` repository:

```
device-notifier-app/
├── agent/
├── gui/
├── installers/
├── prerequisites/          ← New folder for prerequisite files
│   └── windows/
│       ├── vc_redist/
│       │   ├── vc_redist.x64.exe
│       │   └── vc_redist.x64.exe.sha256
│       ├── dotnet/
│       │   ├── ndp48-web.exe
│       │   └── ndp48-web.exe.sha256
│       └── openssl/
│           ├── Win64OpenSSL_Light-3_5_2.exe
│           └── Win64OpenSSL_Light-3_5_2.exe.sha256
├── docs/
├── scripts/
└── ... (other existing folders)
```

## Download URLs

The installer will download prerequisites from these URLs in your main repository:

- **Visual C++ Redistributable**: `https://github.com/saphirredragon207/device-notifier-app/raw/main/prerequisites/windows/vc_redist/vc_redist.x64.exe`
- **Microsoft .NET Framework**: `https://github.com/saphirredragon207/device-notifier-app/raw/main/prerequisites/windows/dotnet/ndp48-web.exe`
- **OpenSSL**: `https://github.com/saphirredragon207/device-notifier-app/raw/main/prerequisites/windows/openssl/Win64OpenSSL_Light-3_5_2.exe`

## Setup Steps

### 1. Create Prerequisites Folder Structure

Run these commands in your repository root:

```powershell
# Create prerequisites directory structure
New-Item -ItemType Directory -Path "prerequisites\windows\vc_redist" -Force
New-Item -ItemType Directory -Path "prerequisites\windows\dotnet" -Force
New-Item -ItemType Directory -Path "prerequisites\windows\openssl" -Force
```

### 2. Download Prerequisite Files

```powershell
# Download Visual C++ Redistributable
Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vc_redist.x64.exe" -OutFile "prerequisites\windows\vc_redist\vc_redist.x64.exe"

# Download .NET Framework
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?LinkId=2085155" -OutFile "prerequisites\windows\dotnet\ndp48-web.exe"

# Download OpenSSL (Light 3.5.2)
Invoke-WebRequest -Uri "https://slproweb.com/download/Win64OpenSSL_Light-3_5_2.exe" -OutFile "prerequisites\windows\openssl\Win64OpenSSL_Light-3_5_2.exe"
```

### 3. Generate SHA256 Checksums

```powershell
# Generate checksums for all prerequisite files
Get-FileHash -Path "prerequisites\windows\vc_redist\vc_redist.x64.exe" -Algorithm SHA256 | Select-Object -ExpandProperty Hash | Out-File -FilePath "prerequisites\windows\vc_redist\vc_redist.x64.exe.sha256" -Encoding ASCII

Get-FileHash -Path "prerequisites\windows\dotnet\ndp48-web.exe" -Algorithm SHA256 | Select-Object -ExpandProperty Hash | Out-File -FilePath "prerequisites\windows\dotnet\ndp48-web.exe.sha256" -Encoding ASCII

Get-FileHash -Path "prerequisites\windows\openssl\Win64OpenSSL_Light-3_5_2.exe" -Algorithm SHA256 | Select-Object -ExpandProperty Hash | Out-File -FilePath "prerequisites\windows\openssl\Win64OpenSSL_Light-3_5_2.exe.sha256" -Encoding ASCII
```

### 4. Commit and Push

```bash
# Add all new files
git add prerequisites/

# Commit the changes
git commit -m "Add prerequisite files for installer"

# Push to GitHub
git push origin main
```

## Benefits of Single Repository

- **Simpler management**: Everything in one place
- **Easier updates**: Update prerequisites and app code together
- **Better versioning**: Prerequisites are tied to specific app versions
- **Reduced complexity**: No need to manage multiple repositories

## Installer Integration

The installer scripts have already been updated to use these URLs. When you build the installer, it will automatically download prerequisites from your main repository.

## Verification

After uploading, verify the download URLs work by testing them in a browser:
- https://github.com/saphirredragon207/device-notifier-app/raw/main/prerequisites/windows/vc_redist/vc_redist.x64.exe
- https://github.com/saphirredragon207/device-notifier-app/raw/main/prerequisites/windows/dotnet/ndp48-web.exe
- https://github.com/saphirredragon207/device-notifier-app/raw/main/prerequisites/windows/openssl/Win64OpenSSL_Light-3_5_2.exe

## Maintenance

When new versions of prerequisites become available:
1. Download the new versions
2. Generate new checksums
3. Update the installer scripts if needed
4. Commit and push the changes

This approach keeps everything centralized and makes maintenance much easier!
