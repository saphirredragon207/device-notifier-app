# Installation Guide

## Prerequisites

### Windows
- Windows 10 or later (64-bit)
- .NET Framework 4.7.2 or later
- Administrator privileges for installation

### macOS
- macOS 10.15 (Catalina) or later
- Administrator privileges for installation

## Installation Methods

### Method 1: Pre-built Installer (Recommended)

#### Windows
1. Download the latest `.msi` installer from the releases page
2. Right-click the installer and select "Run as administrator"
3. Follow the installation wizard
4. Complete the consent and configuration flow
5. The service will start automatically

#### macOS
1. Download the latest `.pkg` installer from the releases page
2. Double-click the installer package
3. Follow the installation wizard
4. Complete the consent and configuration flow
5. The service will start automatically

### Method 2: Manual Installation

#### Windows
1. Extract the release archive
2. Open Command Prompt as Administrator
3. Navigate to the extracted directory
4. Run: `device-notifier.exe install`
5. Configure the application using the GUI

#### macOS
1. Extract the release archive
2. Open Terminal
3. Navigate to the extracted directory
4. Run: `sudo ./device-notifier install`
5. Configure the application using the GUI

## First Run Configuration

1. **Consent Screen**: Read and accept the terms of service
2. **Discord Setup**: Enter your Discord bot token and channel ID
3. **Feature Selection**: Choose which notifications to enable
4. **Security Settings**: Configure authentication and permissions
5. **Device Alias**: Set a friendly name for your device

## Service Management

### Windows
- Start: `net start DeviceNotifier`
- Stop: `net stop DeviceNotifier`
- Status: `sc query DeviceNotifier`

### macOS
- Start: `sudo launchctl load /Library/LaunchDaemons/com.device-notifier.plist`
- Stop: `sudo launchctl unload /Library/LaunchDaemons/com.device-notifier.plist`
- Status: `sudo launchctl list | grep device-notifier`

## Emergency Disable

If you need to immediately disable the application:

### Windows
1. Open Command Prompt as Administrator
2. Run: `device-notifier emergency-disable`

### macOS
1. Open Terminal
2. Run: `sudo device-notifier emergency-disable`

### GUI
Use the Emergency Kill button in the main interface

## Uninstallation

### Windows
1. Open Control Panel > Programs > Uninstall a program
2. Find "Device Notifier" and click Uninstall
3. Or run: `device-notifier.exe uninstall`

### macOS
1. Open Applications folder
2. Drag "Device Notifier" to Trash
3. Or run: `sudo device-notifier uninstall`

## Troubleshooting

### Common Issues

1. **Service won't start**
   - Check Windows Event Viewer or macOS Console for errors
   - Verify administrator privileges
   - Check firewall settings

2. **Discord integration not working**
   - Verify bot token is correct
   - Check bot permissions in Discord
   - Ensure webhook URL is valid

3. **Permission denied errors**
   - Run as administrator/with sudo
   - Check file permissions
   - Verify antivirus isn't blocking the application

### Logs

Logs are stored in:
- **Windows**: `%APPDATA%\device-notifier\logs\`
- **macOS**: `~/Library/Logs/device-notifier/`

### Support

For additional help:
1. Check the troubleshooting section
2. Review the logs for error messages
3. Open an issue on GitHub
4. Contact support with detailed error information
