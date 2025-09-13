#!/bin/bash

# Build script for Linux binaries
# This script builds the studio-rust-mcp-server for both x86_64 and aarch64 Linux targets

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "Cargo.toml" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Create release directory
RELEASE_DIR="release"
mkdir -p "$RELEASE_DIR"

print_status "Starting Linux build process..."

# Install required targets
print_status "Installing Rust targets..."
rustup target add x86_64-unknown-linux-gnu
rustup target add aarch64-unknown-linux-gnu

# Build for x86_64
print_status "Building for x86_64-unknown-linux-gnu..."
cargo build --release --target x86_64-unknown-linux-gnu

# Strip the binary to reduce size
if command -v strip &> /dev/null; then
    print_status "Stripping x86_64 binary..."
    strip target/x86_64-unknown-linux-gnu/release/rbx-studio-mcp
fi

# Build for aarch64
print_status "Building for aarch64-unknown-linux-gnu..."
cargo build --release --target aarch64-unknown-linux-gnu

# Strip the binary to reduce size
if command -v strip &> /dev/null; then
    print_status "Stripping aarch64 binary..."
    strip target/aarch64-unknown-linux-gnu/release/rbx-studio-mcp
fi

# Copy binaries to release directory
print_status "Copying binaries to release directory..."
cp target/x86_64-unknown-linux-gnu/release/rbx-studio-mcp "$RELEASE_DIR/rbx-studio-mcp-x86_64-unknown-linux-gnu"
cp target/aarch64-unknown-linux-gnu/release/rbx-studio-mcp "$RELEASE_DIR/rbx-studio-mcp-aarch64-unknown-linux-gnu"

# Make binaries executable
chmod +x "$RELEASE_DIR"/*

# Create checksums
print_status "Creating checksums..."
cd "$RELEASE_DIR"
sha256sum * > checksums.txt
cd ..

# Display results
print_success "Build completed successfully!"
print_status "Release artifacts:"
ls -la "$RELEASE_DIR"/

print_status "Binary sizes:"
du -h "$RELEASE_DIR"/*

print_status "Checksums:"
cat "$RELEASE_DIR/checksums.txt"

print_success "Linux builds are ready in the $RELEASE_DIR directory!"
