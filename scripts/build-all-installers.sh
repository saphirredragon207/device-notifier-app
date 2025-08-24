#!/bin/bash

set -e

echo "========================================"
echo "Device Notifier - Cross-Platform Builder"
echo "========================================"

# Function to detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unknown";;
    esac
}

# Function to check dependencies
check_dependencies() {
    local os=$1
    
    case $os in
        "windows")
            if ! command -v candle &> /dev/null; then
                echo "ERROR: WiX Toolset not found. Please install WiX Toolset v3.11 or later."
                echo "Download from: https://github.com/wixtoolset/wix3/releases"
                echo "Or run the Windows batch file directly: installers/windows/build-msi.bat"
                return 1
            fi
            ;;
        "macos")
            if ! command -v pkgbuild &> /dev/null; then
                echo "ERROR: pkgbuild not found. This tool is part of Xcode Command Line Tools."
                echo "Install with: xcode-select --install"
                echo "Or run the macOS script directly: installers/macos/build-pkg.sh"
                return 1
            fi
            ;;
        "linux")
            echo "Linux installer creation is not yet implemented."
            echo "Please build manually or use Docker for cross-platform builds."
            return 1
            ;;
    esac
    return 0
}

# Function to build for specific OS
build_for_os() {
    local os=$1
    
    case $os in
        "windows")
            echo "Building Windows MSI installer..."
            cd "installers/windows"
            if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
                # On Windows with Git Bash/MSYS
                ./build-msi.bat
            else
                # On other systems, try to run the batch file
                echo "Attempting to run Windows build script..."
                if command -v cmd &> /dev/null; then
                    cmd //c build-msi.bat
                else
                    echo "ERROR: Cannot run Windows batch file on this system."
                    echo "Please run the Windows build script directly on a Windows machine."
                    return 1
                fi
            fi
            ;;
        "macos")
            echo "Building macOS package installer..."
            cd "installers/macos"
            chmod +x build-pkg.sh
            ./build-pkg.sh
            ;;
        "linux")
            echo "Linux installer creation is not yet implemented."
            return 1
            ;;
    esac
}

# Main execution
main() {
    local detected_os=$(detect_os)
    
    echo "Detected operating system: $detected_os"
    echo
    
    # Check if specific OS was requested
    if [ "$1" != "" ]; then
        case "$1" in
            "windows"|"win")
                detected_os="windows"
                ;;
            "macos"|"mac")
                detected_os="macos"
                ;;
            "linux")
                detected_os="linux"
                ;;
            *)
                echo "ERROR: Unknown OS '$1'. Supported values: windows, macos, linux"
                exit 1
                ;;
        esac
        echo "Building for requested OS: $detected_os"
        echo
    fi
    
    # Check dependencies
    if ! check_dependencies "$detected_os"; then
        exit 1
    fi
    
    # Build the Rust agent first (common for all platforms)
    echo "Building Rust agent (common component)..."
    cd agent
    cargo build --release
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to build Rust agent"
        exit 1
    fi
    cd ..
    
    # Build the Tauri GUI (common for all platforms)
    echo "Building Tauri GUI (common component)..."
    cd gui
    npm install
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to install npm dependencies"
        exit 1
    fi
    
    npm run tauri build
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to build Tauri GUI"
        exit 1
    fi
    cd ..
    
    # Build platform-specific installer
    if build_for_os "$detected_os"; then
        echo
        echo "========================================"
        echo "Build completed successfully for $detected_os!"
        echo "========================================"
        echo
        echo "Installers created in: installers/$detected_os/output/"
        echo
        case $detected_os in
            "windows")
                echo "Windows MSI installer: installers/windows/output/DeviceNotifier.msi"
                echo "To install: msiexec /i installers/windows/output/DeviceNotifier.msi"
                ;;
            "macos")
                echo "macOS package: installers/macos/output/DeviceNotifier.pkg"
                echo "To install: sudo installer -pkg installers/macos/output/DeviceNotifier.pkg -target /"
                ;;
        esac
    else
        echo
        echo "========================================"
        echo "Build failed for $detected_os"
        echo "========================================"
        echo
        echo "Please check the error messages above and try again."
        echo "You can also run the platform-specific build script directly:"
        case $detected_os in
            "windows")
                echo "  installers/windows/build-msi.bat"
                ;;
            "macos")
                echo "  installers/macos/build-pkg.sh"
                ;;
        esac
        exit 1
    fi
}

# Show usage if help requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 [platform]"
    echo
    echo "Builds Device Notifier installers for the specified platform."
    echo "If no platform is specified, automatically detects the current OS."
    echo
    echo "Supported platforms:"
    echo "  windows, win  - Build Windows MSI installer"
    echo "  macos, mac    - Build macOS package installer"
    echo "  linux         - Build Linux package (not yet implemented)"
    echo
    echo "Examples:"
    echo "  $0              # Auto-detect OS and build"
    echo "  $0 windows      # Build Windows installer"
    echo "  $0 macos        # Build macOS installer"
    echo
    echo "Requirements:"
    echo "  Windows: WiX Toolset v3.11+"
    echo "  macOS: Xcode Command Line Tools"
    echo "  All: Rust, Node.js, npm"
    exit 0
fi

# Run main function
main "$@"
