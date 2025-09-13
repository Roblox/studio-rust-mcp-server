#!/usr/bin/env python3
"""
Cross-platform build script for Linux binaries
This script builds the studio-rust-mcp-server for both x86_64 and aarch64 Linux targets
Works on Windows, macOS, and Linux
"""

import os
import sys
import subprocess
import platform
import shutil
from pathlib import Path

class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def print_status(message):
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {message}")

def print_success(message):
    print(f"{Colors.GREEN}[SUCCESS]{Colors.NC} {message}")

def print_warning(message):
    print(f"{Colors.YELLOW}[WARNING]{Colors.NC} {message}")

def print_error(message):
    print(f"{Colors.RED}[ERROR]{Colors.NC} {message}")

def run_command(cmd, check=True):
    """Run a command and return the result"""
    print_status(f"Running: {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, check=check, capture_output=True, text=True)
        if result.stdout:
            print(result.stdout)
        return result
    except subprocess.CalledProcessError as e:
        print_error(f"Command failed: {e}")
        if e.stderr:
            print(e.stderr)
        raise

def check_rust_installed():
    """Check if Rust is installed"""
    try:
        run_command(["rustc", "--version"])
        run_command(["cargo", "--version"])
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print_error("Rust is not installed. Please install Rust from https://rustup.rs/")
        return False

def install_targets():
    """Install required Rust targets"""
    targets = ["x86_64-unknown-linux-gnu", "aarch64-unknown-linux-gnu"]
    for target in targets:
        print_status(f"Installing target: {target}")
        run_command(["rustup", "target", "add", target])

def build_target(target):
    """Build for a specific target"""
    print_status(f"Building for {target}...")
    
    # Check if we're cross-compiling
    host_os = platform.system().lower()
    target_os = target.split('-')[2] if '-' in target else 'unknown'
    
    if host_os == 'windows' and target_os == 'linux':
        print_warning("Cross-compiling from Windows to Linux is not supported in this script.")
        print_warning("Please use the GitHub Actions workflow or build on a Linux system.")
        print_status("Skipping build for this target...")
        return
    
    cmd = ["cargo", "build", "--release", "--target", target]
    run_command(cmd)
    
    # Strip binary if strip command is available
    binary_path = Path("target") / target / "release" / "rbx-studio-mcp"
    if shutil.which("strip") and binary_path.exists():
        print_status(f"Stripping {target} binary...")
        run_command(["strip", str(binary_path)])

def copy_binaries():
    """Copy built binaries to release directory"""
    release_dir = Path("release")
    release_dir.mkdir(exist_ok=True)
    
    targets = ["x86_64-unknown-linux-gnu", "aarch64-unknown-linux-gnu"]
    for target in targets:
        source = Path("target") / target / "release" / "rbx-studio-mcp"
        dest = release_dir / f"rbx-studio-mcp-{target}"
        
        if source.exists():
            shutil.copy2(source, dest)
            # Make executable on Unix systems
            if platform.system() != "Windows":
                os.chmod(dest, 0o755)
            print_success(f"Copied {target} binary")
        else:
            print_error(f"Binary not found: {source}")

def create_checksums():
    """Create checksums for all binaries"""
    release_dir = Path("release")
    checksum_file = release_dir / "checksums.txt"
    
    print_status("Creating checksums...")
    with open(checksum_file, "w") as f:
        for binary in release_dir.glob("rbx-studio-mcp-*"):
            if binary.is_file():
                if platform.system() == "Windows":
                    # Use PowerShell Get-FileHash on Windows
                    result = subprocess.run([
                        "powershell", "-Command",
                        f"Get-FileHash '{binary}' -Algorithm SHA256 | Select-Object -ExpandProperty Hash"
                    ], capture_output=True, text=True)
                    if result.returncode == 0:
                        hash_value = result.stdout.strip()
                        f.write(f"{hash_value}  {binary.name}\n")
                else:
                    # Use sha256sum on Unix systems
                    result = subprocess.run(["sha256sum", str(binary)], capture_output=True, text=True)
                    if result.returncode == 0:
                        f.write(result.stdout)

def display_results():
    """Display build results"""
    release_dir = Path("release")
    
    print_success("Build completed successfully!")
    print_status("Release artifacts:")
    
    for item in release_dir.iterdir():
        if item.is_file():
            size = item.stat().st_size
            size_mb = size / (1024 * 1024)
            print(f"  {item.name}: {size_mb:.2f} MB")
    
    print_status("Checksums:")
    checksum_file = release_dir / "checksums.txt"
    if checksum_file.exists():
        with open(checksum_file) as f:
            print(f.read())

def main():
    """Main build function"""
    print_status("Starting cross-platform Linux build process...")
    
    # Check if we're in the right directory
    if not Path("Cargo.toml").exists():
        print_error("Please run this script from the project root directory")
        sys.exit(1)
    
    # Check if Rust is installed
    if not check_rust_installed():
        sys.exit(1)
    
    # Install targets
    install_targets()
    
    # Build for each target
    targets = ["x86_64-unknown-linux-gnu", "aarch64-unknown-linux-gnu"]
    for target in targets:
        build_target(target)
    
    # Copy binaries
    copy_binaries()
    
    # Create checksums
    create_checksums()
    
    # Display results
    display_results()
    
    print_success("Linux builds are ready in the release directory!")

if __name__ == "__main__":
    main()
