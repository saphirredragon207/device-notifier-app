# Device Notifier - Windows Installers

Professional Windows installer packages for the Device Notifier application, providing both traditional MSI installers and an advanced setup wizard with automatic prerequisite management.

## 📦 **Available Installers**

### **1. Setup Wizard Installer** ⭐ **Recommended**
- **File**: `DeviceNotifier-Setup-Wizard.exe`
- **Type**: Inno Setup-based wizard installer
- **Features**: Guided installation, auto-prerequisites, Discord setup
- **Best For**: End users, first-time installations

### **2. Traditional MSI Installer**
- **File**: `DeviceNotifier-Setup.msi`
- **Type**: Windows Installer package
- **Features**: Standard Windows installation, enterprise deployment
- **Best For**: Enterprise environments, automated deployment

## 🚀 **Quick Start**

### **For End Users**
1. Download `DeviceNotifier-Setup-Wizard.exe`
2. Double-click to run the installer
3. Follow the guided wizard steps
4. Enjoy automatic Discord integration setup

### **For Developers**
```cmd
# Navigate to installer directory
cd installers\cross-platform

# Build the setup wizard installer
build-wizard.bat

# Or use PowerShell directly
powershell -ExecutionPolicy Bypass -File build-wizard.ps1
```

### **For Enterprise**
```cmd
# Silent installation with MSI
msiexec /i DeviceNotifier-Setup.msi /quiet

# Silent installation with wizard
DeviceNotifier-Setup-Wizard.exe /SILENT /CONFIG=config.json
```

## ✨ **Setup Wizard Features**

### **Guided Installation**
- **Welcome Page**: Application overview and benefits
- **License Agreement**: Terms acceptance with privacy summary
- **Prerequisites Check**: Automatic system requirement detection
- **Download Progress**: Real-time prerequisite download tracking
- **Install Options**: Customize installation scope and features
- **Install Progress**: Detailed installation logging
- **Discord Setup**: Optional bot integration configuration
- **Completion**: Launch application and finish

### **Automatic Prerequisites**
- **Visual C++ Redistributable 2015-2022**
- **Microsoft .NET Framework 4.8**
- **OpenSSL 3.0**
- **Automatic download and verification**
- **SHA256 checksum validation**

### **Security Features**
- **HTTPS downloads with certificate validation**
- **Checksum verification for all downloads**
- **Minimal privilege elevation**
- **Comprehensive audit logging**
- **Secure Discord token handling**

## 🔧 **Building the Installers**

### **Prerequisites**
- **Windows 10/11**: Required for modern installer features
- **PowerShell 5.1+**: Required for build automation
- **Internet Connection**: For downloading prerequisites

### **Build Commands**
```cmd
# Build setup wizard installer
cd installers\cross-platform
build-wizard.bat

# Custom output directory
powershell -ExecutionPolicy Bypass -File build-wizard.ps1 -OutputPath "C:\CustomOutput\"
```

### **Build Output**
```
installers/cross-platform/output/
├── DeviceNotifier-Setup-Wizard.exe    # Setup wizard installer
├── DeviceNotifier-Setup-Wizard.log    # Build log
└── silent-install-config.json         # Silent install configuration
```

## 📋 **Installation Options**

### **Interactive Installation**
- **User vs. System**: Choose installation scope
- **Custom Directory**: Select installation location
- **Component Selection**: Choose optional features
- **Startup Options**: Configure auto-start behavior
- **Discord Integration**: Set up bot configuration

### **Silent Installation**
```cmd
# Basic silent install
DeviceNotifier-Setup-Wizard.exe /SILENT

# With configuration file
DeviceNotifier-Setup-Wizard.exe /SILENT /CONFIG=config.json

# With specific options
DeviceNotifier-Setup-Wizard.exe /SILENT /DIR="C:\CustomPath" /TASKS="desktopicon,startup"
```

### **Configuration File**
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
  }
}
```

## 🏗️ **Architecture**

### **Setup Wizard (Inno Setup)**
```
setup-wizard.iss          # Main installer script
├── [Setup]               # Installer configuration
├── [Languages]           # Localization support
├── [Tasks]               # Installation options
├── [Files]               # Application files
├── [Registry]            # System integration
├── [Run]                 # Post-install actions
└── [Code]                # Pascal scripting engine
    ├── Wizard Pages      # Custom wizard interface
    ├── Download Manager  # Prerequisite management
    ├── Prereq Checker    # System requirement detection
    └── Install Engine    # Application installation
```

### **MSI Installer**
```
installer.wxs             # WiX source file
├── Product               # Product information
├── Package               # Package properties
├── Directory             # File structure
├── Component             # Application components
├── Feature               # Feature selection
└── CustomAction          # Custom installation actions
```

## 🔒 **Security & Privacy**

### **Download Security**
- **HTTPS Enforcement**: All downloads use TLS 1.3
- **Certificate Validation**: Full certificate chain verification
- **Source Verification**: Trusted download source validation
- **Checksum Verification**: SHA256 integrity checking

### **Data Privacy**
- **Minimal Collection**: Only necessary system information
- **Local Processing**: Device events processed locally
- **Encrypted Transmission**: All Discord communication encrypted
- **Audit Logging**: Complete installation audit trail

### **System Security**
- **Privilege Minimization**: Elevation only when required
- **Service Isolation**: Limited system access scope
- **Secure Storage**: Encrypted configuration storage
- **Update Verification**: Signed update package validation

## 🎨 **Customization**

### **Branding & Styling**
```pascal
// Customize wizard appearance
WizardImageFile=logo.bmp
WizardSmallImageFile=small-logo.bmp
SetupIconFile=icon.ico

// Custom colors and fonts
[Code]
procedure InitializeWizard;
begin
  WizardForm.Color := clWhite;
  WizardForm.Font.Color := clBlack;
end;
```

### **Prerequisite Management**
```pascal
// Add new prerequisites
PrereqList.Add('New Runtime Framework');

// Update download URLs and checksums
function GetPrereqDownloadUrl(const PrereqName: String): String;
begin
  if PrereqName = 'New Runtime Framework' then
    Result := 'https://example.com/framework.exe'
  // ... existing code ...
end;
```

### **Discord Integration**
```pascal
// Custom bot configuration
procedure ConfigureDiscordIntegration;
begin
  // Add custom Discord setup logic
  if ConfigureDiscord then
  begin
    // Custom configuration steps
  end;
end;
```

## 📊 **Enterprise Features**

### **Deployment Tools**
- **Group Policy**: Windows domain deployment
- **SCCM**: System Center Configuration Manager
- **Intune**: Microsoft Intune integration
- **Ansible**: Infrastructure automation

### **Monitoring & Reporting**
- **Installation Logs**: Detailed installation records
- **Success Metrics**: Installation success rates
- **Error Tracking**: Common failure analysis
- **Usage Analytics**: Application usage patterns

### **Compliance Support**
- **Audit Trails**: Complete installation history
- **Policy Enforcement**: Corporate policy compliance
- **Security Validation**: Security requirement verification
- **Documentation**: Compliance documentation generation

## 🐛 **Troubleshooting**

### **Common Issues**

#### **Prerequisites Fail to Download**
```cmd
# Check internet connectivity
ping google.com

# Verify firewall settings
# Check Windows Firewall settings

# Test download URLs manually
curl -I "https://aka.ms/vs/17/release/vc_redist.x64.exe"
```

#### **Checksum Verification Fails**
```cmd
# Verify file integrity
certutil -hashfile file.exe SHA256

# Redownload the file
# Check for network corruption
# Verify source URL is correct
```

#### **Installation Fails**
```cmd
# Check system requirements
winver  # Windows 10 1809+

# Verify administrator privileges
# Run as Administrator

# Check available disk space
dir C:\
```

### **Log Files**
- **Installation Log**: `%TEMP%\DeviceNotifier-Install.log`
- **System Logs**: Event Viewer → Windows Logs → Application
- **Application Logs**: `%APPDATA%\DeviceNotifier\logs`

### **Debug Mode**
```cmd
# Enable verbose logging
DeviceNotifier-Setup-Wizard.exe /LOG=install.log /VERBOSE

# Debug mode with console output
DeviceNotifier-Setup-Wizard.exe /DEBUG
```

## 🔄 **Updates & Maintenance**

### **Version Management**
- **Semantic Versioning**: Major.Minor.Patch format
- **Update Channels**: Stable, Beta, Development releases
- **Rollback Support**: Previous version restoration
- **Delta Updates**: Incremental update packages

### **Distribution**
- **Code Signing**: Authenticode certificate signing
- **Windows Store**: MSIX packaging for Microsoft Store
- **Update Servers**: Secure update distribution
- **CDN Integration**: Global content delivery

### **Maintenance**
- **Log Rotation**: Automatic log file management
- **Cleanup Scripts**: Temporary file removal
- **Health Checks**: System integration verification
- **Performance Monitoring**: Resource usage tracking

## 📚 **Documentation & Support**

### **User Documentation**
- **Installation Guide**: Step-by-step installation instructions
- **Configuration Manual**: Advanced configuration options
- **Troubleshooting Guide**: Common issues and solutions
- **FAQ**: Frequently asked questions

### **Developer Resources**
- **API Reference**: Integration and customization APIs
- **Sample Code**: Example implementations
- **Best Practices**: Security and performance guidelines
- **Contributing Guide**: Development contribution process

### **Support Channels**
- **GitHub Issues**: Bug reports and feature requests
- **Discord Community**: Real-time support and discussion
- **Documentation Site**: Comprehensive online documentation
- **Email Support**: Direct technical support

## 🎯 **Roadmap & Future Features**

### **Short Term (Next 3 Months)**
- **Enhanced Localization**: Additional language support
- **Advanced Prerequisites**: More runtime framework detection
- **Improved Error Handling**: Better error recovery mechanisms
- **Performance Optimization**: Faster installation process

### **Medium Term (3-6 Months)**
- **Cloud Integration**: Cloud-based configuration management
- **Advanced Security**: Hardware security module support
- **Automated Testing**: Comprehensive test automation
- **CI/CD Integration**: Automated build and deployment

### **Long Term (6+ Months)**
- **Advanced Analytics**: Installation and usage analytics
- **Enterprise Features**: Advanced deployment and management
- **Plugin System**: Extensible installer framework
- **Cloud Deployment**: Cloud-based installer distribution

## 🤝 **Contributing**

We welcome contributions from the community! Please see our [Contributing Guide](CONTRIBUTING.md) for details on:

- **Code Style**: Coding standards and conventions
- **Testing**: Testing requirements and procedures
- **Documentation**: Documentation standards
- **Pull Requests**: PR submission process

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- **Inno Setup Team**: For the excellent Windows installer framework
- **WiX Toolset Team**: For the Windows Installer XML framework
- **Community Contributors**: For feedback, testing, and contributions
- **Open Source Projects**: For the libraries and tools that make this possible

---

**Ready to get started?** 🚀

1. **Build the installer**: Run `build-wizard.bat` in the cross-platform directory
2. **Test the wizard**: Install on a test system to verify functionality
3. **Customize**: Modify branding, prerequisites, and integration options
4. **Deploy**: Distribute to your users with confidence

For questions and support, join our [Discord community](https://discord.gg/devicenotifier) or check our [documentation](https://devicenotifier.com/docs).

**Note**: This installer is designed specifically for Windows systems. For other platforms, please refer to the main project documentation.
