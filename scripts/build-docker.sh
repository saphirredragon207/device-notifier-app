#!/bin/bash

set -e

echo "========================================"
echo "Device Notifier - Docker Cross-Platform Builder"
echo "========================================"

# Function to show usage
show_usage() {
    echo "Usage: $0 [options] <platform>"
    echo
    echo "Builds Device Notifier installers using Docker containers."
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -c, --clean         Clean up Docker containers and images after build"
    echo "  -p, --push          Push built images to Docker registry (if configured)"
    echo "  -t, --tag <tag>     Use custom tag for Docker images (default: latest)"
    echo "  -o, --output <dir>  Output directory for installers (default: ./output)"
    echo
    echo "Platforms:"
    echo "  windows             Build Windows MSI installer"
    echo "  macos               Build macOS package installer"
    echo "  all                 Build installers for all platforms"
    echo
    echo "Examples:"
    echo "  $0 windows          # Build Windows installer"
    echo "  $0 macos            # Build macOS installer"
    echo "  $0 all              # Build all installers"
    echo "  $0 -c windows       # Build Windows installer and clean up"
    echo "  $0 -o ./myoutput windows  # Build to custom output directory"
    echo
    echo "Requirements:"
    echo "  Docker Desktop or Docker Engine"
    echo "  At least 4GB available disk space"
    echo "  Internet connection for downloading base images"
}

# Function to check Docker availability
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "ERROR: Docker not found. Please install Docker Desktop or Docker Engine."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "ERROR: Docker daemon not running. Please start Docker Desktop or Docker Engine."
        exit 1
    fi
}

# Function to build Windows installer using Docker
build_windows_docker() {
    local output_dir=$1
    local tag=$2
    
    echo "Building Windows MSI installer using Docker..."
    
    # Create Windows build Dockerfile
    cat > Dockerfile.windows << 'EOF'
FROM mcr.microsoft.com/windows/servercore:ltsc2019

# Install Chocolatey
RUN powershell -Command \
    Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install required tools
RUN choco install -y wixtoolset rust nodejs git

# Set environment variables
ENV PATH="C:\Program Files (x86)\WiX Toolset v3.11\bin;${PATH}"
ENV PATH="C:\Users\ContainerUser\.cargo\bin;${PATH}"

# Set working directory
WORKDIR C:\src

# Copy source code
COPY . .

# Build Rust agent
RUN cargo build --release

# Build Tauri GUI
RUN npm install
RUN npm run tauri build

# Build MSI installer
RUN candle -ext WixUtilExtension -ext WixServiceExtension installer.wxs -out installer.wixobj
RUN light -ext WixUtilExtension -ext WixServiceExtension installer.wixobj -out DeviceNotifier.msi

# Create output directory
RUN mkdir -p C:\output

# Copy installer to output
RUN copy DeviceNotifier.msi C:\output\

# Set output volume
VOLUME C:\output
EOF

    # Build Windows Docker image
    echo "Building Windows Docker image..."
    docker build -f Dockerfile.windows -t devicenotifier-windows:$tag .
    
    # Run Windows container and extract installer
    echo "Running Windows build container..."
    docker run --rm -v "$(pwd)/$output_dir":C:\output devicenotifier-windows:$tag
    
    # Clean up Windows Dockerfile
    rm -f Dockerfile.windows
    
    echo "Windows installer built successfully!"
}

# Function to build macOS installer using Docker
build_macos_docker() {
    local output_dir=$1
    local tag=$2
    
    echo "Building macOS package installer using Docker..."
    
    # Note: Building macOS packages on non-macOS systems is complex
    # This is a simplified approach that may not work in all cases
    echo "WARNING: Building macOS packages on non-macOS systems may not work correctly."
    echo "Consider building on a macOS machine or using a macOS CI/CD service."
    
    # Create macOS build Dockerfile
    cat > Dockerfile.macos << 'EOF'
FROM ubuntu:20.04

# Install required packages
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    pkg-config \
    libssl-dev \
    libsqlite3-dev \
    libclang-dev \
    clang \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get install -y nodejs

# Install Tauri CLI
RUN npm install -g @tauri-apps/cli

# Set working directory
WORKDIR /src

# Copy source code
COPY . .

# Build Rust agent
RUN cargo build --release

# Build Tauri GUI
RUN npm install
RUN npm run tauri build

# Create package structure (simplified)
RUN mkdir -p /output/DeviceNotifier.app/Contents/MacOS
RUN mkdir -p /output/DeviceNotifier.app/Contents/Resources

# Copy built files
RUN cp target/release/device-notifier-agent /output/DeviceNotifier.app/Contents/Resources/
RUN cp src-tauri/target/release/DeviceNotifier /output/DeviceNotifier.app/Contents/MacOS/

# Create a simple package (this won't be a proper macOS package)
RUN cd /output && tar -czf DeviceNotifier-macos.tar.gz DeviceNotifier.app/

# Set output volume
VOLUME /output
EOF

    # Build macOS Docker image
    echo "Building macOS Docker image..."
    docker build -f Dockerfile.macos -t devicenotifier-macos:$tag .
    
    # Run macOS container and extract package
    echo "Running macOS build container..."
    docker run --rm -v "$(pwd)/$output_dir":/output devicenotifier-macos:$tag
    
    # Clean up macOS Dockerfile
    rm -f Dockerfile.macos
    
    echo "macOS package built successfully (note: this is a simplified package)"
}

# Function to clean up Docker resources
cleanup_docker() {
    local tag=$1
    
    echo "Cleaning up Docker resources..."
    
    # Remove containers
    docker container prune -f
    
    # Remove images
    docker rmi devicenotifier-windows:$tag 2>/dev/null || true
    docker rmi devicenotifier-macos:$tag 2>/dev/null || true
    
    # Remove dangling images
    docker image prune -f
    
    echo "Docker cleanup completed."
}

# Function to push Docker images
push_docker_images() {
    local tag=$1
    
    echo "Pushing Docker images to registry..."
    
    # This would require proper registry configuration
    # For now, just show a message
    echo "Note: Image pushing requires Docker registry configuration."
    echo "Images built:"
    echo "  devicenotifier-windows:$tag"
    echo "  devicenotifier-macos:$tag"
}

# Parse command line arguments
CLEANUP=false
PUSH_IMAGES=false
TAG="latest"
OUTPUT_DIR="./output"
PLATFORM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -c|--clean)
            CLEANUP=true
            shift
            ;;
        -p|--push)
            PUSH_IMAGES=true
            shift
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        windows|macos|all)
            PLATFORM="$1"
            shift
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if platform was specified
if [[ -z "$PLATFORM" ]]; then
    echo "ERROR: Platform must be specified."
    show_usage
    exit 1
fi

# Check Docker availability
check_docker

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build installers based on platform
case "$PLATFORM" in
    "windows")
        build_windows_docker "$OUTPUT_DIR" "$TAG"
        ;;
    "macos")
        build_macos_docker "$OUTPUT_DIR" "$TAG"
        ;;
    "all")
        echo "Building installers for all platforms..."
        build_windows_docker "$OUTPUT_DIR" "$TAG"
        build_macos_docker "$OUTPUT_DIR" "$TAG"
        ;;
esac

# Push images if requested
if [[ "$PUSH_IMAGES" == true ]]; then
    push_docker_images "$TAG"
fi

# Clean up if requested
if [[ "$CLEANUP" == true ]]; then
    cleanup_docker "$TAG"
fi

echo
echo "========================================"
echo "Docker build completed successfully!"
echo "========================================"
echo
echo "Output directory: $OUTPUT_DIR"
echo "Platforms built: $PLATFORM"
echo
echo "Note: Docker-based builds may have limitations compared to native builds."
echo "For production use, consider building on the target platform."
echo

# List output files
if [[ -d "$OUTPUT_DIR" ]]; then
    echo "Generated files:"
    ls -la "$OUTPUT_DIR"
fi
