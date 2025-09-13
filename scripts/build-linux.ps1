# PowerShell build script for Linux binaries
# This script builds the studio-rust-mcp-server for both x86_64 and aarch64 Linux targets

param(
    [switch]$SkipTests,
    [switch]$Verbose
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check if we're in the right directory
if (-not (Test-Path "Cargo.toml")) {
    Write-Error "Please run this script from the project root directory"
    exit 1
}

# Create release directory
$ReleaseDir = "release"
if (-not (Test-Path $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
}

Write-Status "Starting Linux build process..."

# Install required targets
Write-Status "Installing Rust targets..."
rustup target add x86_64-unknown-linux-gnu
rustup target add aarch64-unknown-linux-gnu

# Build for x86_64
Write-Status "Building for x86_64-unknown-linux-gnu..."
$BuildArgs = @("build", "--release", "--target", "x86_64-unknown-linux-gnu")
if ($SkipTests) {
    $BuildArgs += "--no-default-features"
}
cargo @BuildArgs

# Build for aarch64
Write-Status "Building for aarch64-unknown-linux-gnu..."
$BuildArgs = @("build", "--release", "--target", "aarch64-unknown-linux-gnu")
if ($SkipTests) {
    $BuildArgs += "--no-default-features"
}
cargo @BuildArgs

# Copy binaries to release directory
Write-Status "Copying binaries to release directory..."
Copy-Item "target\x86_64-unknown-linux-gnu\release\rbx-studio-mcp" "$ReleaseDir\rbx-studio-mcp-x86_64-unknown-linux-gnu"
Copy-Item "target\aarch64-unknown-linux-gnu\release\rbx-studio-mcp" "$ReleaseDir\rbx-studio-mcp-aarch64-unknown-linux-gnu"

# Create checksums
Write-Status "Creating checksums..."
Push-Location $ReleaseDir
Get-ChildItem -File | ForEach-Object {
    $hash = Get-FileHash $_.Name -Algorithm SHA256
    "$($hash.Hash)  $($_.Name)" | Add-Content "checksums.txt"
}
Pop-Location

# Display results
Write-Success "Build completed successfully!"
Write-Status "Release artifacts:"
Get-ChildItem $ReleaseDir | Format-Table Name, Length, LastWriteTime

Write-Status "Binary sizes:"
Get-ChildItem $ReleaseDir -File | ForEach-Object {
    $size = [math]::Round($_.Length / 1MB, 2)
    Write-Host "$($_.Name): ${size} MB"
}

Write-Status "Checksums:"
Get-Content "$ReleaseDir\checksums.txt"

Write-Success "Linux builds are ready in the $ReleaseDir directory!"
