#!/usr/bin/env python3
"""
Test script to verify the Linux build configuration
This script checks if all dependencies and configurations are correct
"""

import os
import sys
import subprocess
import platform
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

def check_rust_installed():
    """Check if Rust is installed"""
    try:
        result = subprocess.run(["rustc", "--version"], capture_output=True, text=True)
        if result.returncode == 0:
            print_success(f"Rust is installed: {result.stdout.strip()}")
            return True
        else:
            print_error("Rust is not installed")
            return False
    except FileNotFoundError:
        print_error("Rust is not installed")
        return False

def check_cargo_toml():
    """Check if Cargo.toml has Linux dependencies"""
    cargo_toml = Path("Cargo.toml")
    if not cargo_toml.exists():
        print_error("Cargo.toml not found")
        return False
    
    content = cargo_toml.read_text()
    if 'zenity-dialog' in content:
        print_success("Linux dependencies found in Cargo.toml")
        return True
    else:
        print_error("Linux dependencies not found in Cargo.toml")
        return False

def check_install_rs():
    """Check if install.rs has Linux support"""
    install_rs = Path("src/install.rs")
    if not install_rs.exists():
        print_error("src/install.rs not found")
        return False
    
    content = install_rs.read_text()
    if 'zenity_dialog' in content and 'target_os = "linux"' in content:
        print_success("Linux support found in install.rs")
        return True
    else:
        print_error("Linux support not found in install.rs")
        return False

def check_github_actions():
    """Check if GitHub Actions workflow exists"""
    workflow_path = Path(".github/workflows/build-linux.yml")
    if workflow_path.exists():
        print_success("GitHub Actions workflow found")
        return True
    else:
        print_error("GitHub Actions workflow not found")
        return False

def check_build_scripts():
    """Check if build scripts exist"""
    scripts = [
        "scripts/build-linux.sh",
        "scripts/build-linux.ps1", 
        "scripts/build-cross-platform.py"
    ]
    
    all_exist = True
    for script in scripts:
        if Path(script).exists():
            print_success(f"Build script found: {script}")
        else:
            print_error(f"Build script not found: {script}")
            all_exist = False
    
    return all_exist

def check_documentation():
    """Check if documentation exists"""
    docs = [
        "docs/linux-builds.md"
    ]
    
    all_exist = True
    for doc in docs:
        if Path(doc).exists():
            print_success(f"Documentation found: {doc}")
        else:
            print_error(f"Documentation not found: {doc}")
            all_exist = False
    
    return all_exist

def main():
    """Main test function"""
    print_status("Testing Linux build configuration...")
    print()
    
    # Check if we're in the right directory
    if not Path("Cargo.toml").exists():
        print_error("Please run this script from the project root directory")
        sys.exit(1)
    
    tests = [
        ("Rust Installation", check_rust_installed),
        ("Cargo.toml Configuration", check_cargo_toml),
        ("Install.rs Linux Support", check_install_rs),
        ("GitHub Actions Workflow", check_github_actions),
        ("Build Scripts", check_build_scripts),
        ("Documentation", check_documentation),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print_status(f"Testing {test_name}...")
        if test_func():
            passed += 1
        print()
    
    print_status(f"Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print_success("All tests passed! Linux build configuration is ready.")
        print()
        print_status("Next steps:")
        print("1. Push changes to GitHub")
        print("2. GitHub Actions will automatically build Linux binaries")
        print("3. Linux users can download pre-built binaries from releases")
        print("4. Linux users can also build locally using the provided scripts")
    else:
        print_error("Some tests failed. Please fix the issues above.")
        sys.exit(1)

if __name__ == "__main__":
    main()
