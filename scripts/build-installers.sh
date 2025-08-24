#!/bin/bash

set -e

echo "Building Device Notifier installers..."

# Build the Rust agent
echo "Building Rust agent..."
cd agent
cargo build --release
cd ..

# Build the Tauri GUI
echo "Building Tauri GUI..."
cd gui
npm install
npm run tauri build
cd ..

# Create Windows installer
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "Creating Windows MSI installer..."
    # This would use WiX Toolset or similar
    echo "Windows installer creation requires WiX Toolset"
fi

# Create macOS installer
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Creating macOS package..."
    # This would use pkgbuild or similar
    echo "macOS installer creation requires pkgbuild"
fi

echo "Build complete!"
