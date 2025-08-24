# Device Notifier Setup Wizard - Windows Installer

A professional Windows setup wizard installer that provides a guided installation experience for the Device Notifier application, with automatic prerequisite management and Discord integration setup.

## Features

- **Professional GUI Wizard**: Step-by-step installation process with modern Windows UI
- **Automatic Prerequisites**: Downloads and installs required system components
- **Security & Integrity**: HTTPS downloads with SHA256 checksum verification
- **Discord Integration**: Optional bot configuration during installation
- **System Integration**: Automatic Windows service setup and startup configuration
- **Silent Install**: Support for automated deployments and enterprise use
- **Error Handling**: Comprehensive error handling with rollback capabilities

## What Gets Installed

### Core Application
- Device Notifier Agent (background service)
- Device Notifier GUI (desktop application)
- Sample Discord bot integration
- Configuration files and data directories

### System Components
- Windows Service for the agent
- Startup configuration
- Desktop shortcuts (optional)
- PATH environment variable updates

### Prerequisites (Auto-downloaded)
- Visual C++ Redistributable 2015-2022
- Microsoft .NET Framework 4.8
- OpenSSL 3.0

## Installation Process

### Interactive Installation
1. **Welcome**: Introduction and overview
2. **License**: Accept terms and privacy policy
3. **Prerequisites**: Check and download system requirements
4. **Install Options**: Choose installation scope and features
5. **Installation**: Build and install the application
6. **Discord Setup**: Configure bot integration (optional)
7. **Completion**: Launch application and finish

### Silent Installation
```cmd
# Basic silent install
DeviceNotifier-Setup-Wizard.exe /SILENT

# With custom configuration
DeviceNotifier-Setup-Wizard.exe /SILENT /CONFIG=config.json

# With specific options
DeviceNotifier-Setup-Wizard.exe /SILENT /DIR="C:\CustomPath" /TASKS="desktopicon,startup"
```

## Building the Installer

### Prerequisites
- **Windows 10/11**: Required for modern installer features
- **PowerShell 5.1+**: Required for build automation
- **Internet Connection**: For downloading prerequisites

### Quick Build
```cmd
# Run the batch file (recommended)
build-wizard.bat

# Or run PowerShell directly
powershell -ExecutionPolicy Bypass -File build-wizard.ps1
```

### Custom Output Directory
```cmd
# Specify custom output path
build-wizard.ps1 -OutputPath "C:\CustomOutput\"
```

### Build Output
The installer will be created at:
```
installers/cross-platform/output/DeviceNotifier-Setup-Wizard.exe
```

## Configuration

### Silent Install Configuration
Create a `silent-install-config.json` file:
```json
{
  "installScope": "system",
  "installDir": "C:\\Program Files\\DeviceNotifier",
  "components": ["agent", "gui", "sampleBot"],
  "startOnBoot": true,
  "createShortcuts": true,
  "discordConfig": {
    "botToken": "YOUR_BOT_TOKEN",
    "defaultChannelId": "CHANNEL_ID",
    "authorizedRoleIds": ["ROLE_ID"]
  },
  "verifySha256": true,
  "acceptLicense": true
}
```

### Command Line Options
- `/SILENT`: Silent installation mode
- `/DIR`: Custom installation directory
- `/TASKS`: Installation tasks (desktopicon, startup, discord)
- `/CONFIG`: Path to configuration file

## Customization

### Inno Setup Script
Edit `setup-wizard.iss` to modify:
- Wizard pages and flow
- Prerequisite checks and sources
- Installation options and defaults
- Branding and styling

### Build Scripts
Edit `build-wizard.ps1` to customize:
- Prerequisite URLs and checksums
- Build process and automation
- Installer metadata and versioning

## Security Features

### Download Security
- HTTPS/TLS with certificate validation
- SHA256 checksum verification
- Optional signature verification
- Secure Discord token handling

### Installation Security
- Minimal privilege elevation
- Secure file permissions
- Audit logging
- Rollback capabilities

## Troubleshooting

### Common Issues
1. **Prerequisites fail to download**
   - Check internet connection and firewall
   - Verify source URLs are accessible
   - Check antivirus software interference

2. **Checksum verification fails**
   - Redownload the installer
   - Check for corrupted downloads
   - Verify source integrity

3. **Installation fails**
   - Ensure administrator privileges
   - Check system requirements
   - Review installation logs

4. **Inno Setup not found**
   - Script will automatically download and install
   - Manual installation available from jrsoftware.org

### Logs and Debugging
- **Installation Log**: `%TEMP%\DeviceNotifier-Install.log`
- **System Logs**: Event Viewer → Windows Logs → Application
- **Application Logs**: `%APPDATA%\DeviceNotifier\logs`

## Distribution

### Code Signing
```powershell
# Sign with Authenticode certificate
Set-AuthenticodeSignature -FilePath "DeviceNotifier-Setup-Wizard.exe" -Certificate $cert
```

### Windows Store
- Package as MSIX for Microsoft Store
- Use App Installer for enterprise deployment
- Support for Windows Package Manager

### Enterprise Deployment
- Group Policy deployment
- SCCM/Intune integration
- Silent installation scripts
- Configuration management

## Development

### Project Structure
```
installers/cross-platform/
├── setup-wizard.iss          # Inno Setup script
├── build-wizard.ps1          # PowerShell build script
├── build-wizard.bat          # Batch file wrapper
├── license.txt               # License agreement
├── files/                    # Application files (placeholder)
├── output/                   # Build output directory
├── silent-install-config.json # Silent install configuration
└── BUILD_INSTRUCTIONS.md     # Detailed build documentation
```

### Adding New Prerequisites
1. Update `setup-wizard.iss` with new prerequisite
2. Add download URL and checksum
3. Update build documentation
4. Test installation process

### Customizing Wizard Pages
1. Modify page creation in `setup-wizard.iss`
2. Update UI text and styling
3. Add new installation options
4. Test user experience flow

## Support

### Documentation
- **Build Instructions**: `BUILD_INSTRUCTIONS.md`
- **Project README**: `README.md`
- **Inno Setup Documentation**: https://jrsoftware.org/ishelp/

### Community
- **GitHub**: https://github.com/devicenotifier
- **Discord**: https://discord.gg/devicenotifier
- **Documentation**: https://devicenotifier.com/docs

### Issues and Questions
- Check troubleshooting section above
- Review installation logs
- Search existing GitHub issues
- Create new issue with detailed information

## License

This installer is part of the Device Notifier project. See the main project license for details.

## Contributing

Contributions are welcome! Please see the main project contributing guidelines.

---

**Note**: This installer is designed specifically for Windows systems. For other platforms, please refer to the main project documentation.
