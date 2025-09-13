# Linux Builds for Roblox Studio MCP Server

This document explains how to build and use the Roblox Studio MCP Server on Linux systems, including WSL (Windows Subsystem for Linux).

## Supported Linux Architectures

- **x86_64-unknown-linux-gnu**: Standard 64-bit Linux systems
- **aarch64-unknown-linux-gnu**: ARM64 Linux systems (like Apple Silicon Macs running Linux, ARM servers, etc.)

## Prerequisites

### Required Software

1. **Rust Toolchain**: Install from [rustup.rs](https://rustup.rs/)
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source ~/.cargo/env
   ```

2. **Build Dependencies** (Ubuntu/Debian):
   ```bash
   sudo apt-get update
   sudo apt-get install -y build-essential pkg-config libssl-dev
   ```

3. **Build Dependencies** (CentOS/RHEL/AlmaLinux):
   ```bash
   sudo yum groupinstall "Development Tools"
   sudo yum install pkgconfig openssl-devel
   ```

4. **Optional GUI Dependencies** (for zenity dialogs):
   ```bash
   # Ubuntu/Debian
   sudo apt-get install zenity
   
   # CentOS/RHEL/AlmaLinux
   sudo yum install zenity
   ```

## Building from Source

### Method 1: Using the Cross-Platform Python Script (Recommended)

```bash
# Make the script executable
chmod +x scripts/build-cross-platform.py

# Run the build script
python3 scripts/build-cross-platform.py
```

### Method 2: Using the Bash Script

```bash
# Make the script executable
chmod +x scripts/build-linux.sh

# Run the build script
./scripts/build-linux.sh
```

### Method 3: Manual Build

```bash
# Install required targets
rustup target add x86_64-unknown-linux-gnu
rustup target add aarch64-unknown-linux-gnu

# Build for x86_64
cargo build --release --target x86_64-unknown-linux-gnu

# Build for aarch64
cargo build --release --target aarch64-unknown-linux-gnu

# Strip binaries (optional, reduces size)
strip target/x86_64-unknown-linux-gnu/release/rbx-studio-mcp
strip target/aarch64-unknown-linux-gnu/release/rbx-studio-mcp
```

## Using Pre-built Binaries

### Download from GitHub Releases

1. Go to the [Releases page](https://github.com/Roblox/studio-rust-mcp-server/releases)
2. Download the appropriate binary for your architecture:
   - `rbx-studio-mcp-x86_64-unknown-linux-gnu` for x86_64 systems
   - `rbx-studio-mcp-aarch64-unknown-linux-gnu` for ARM64 systems
3. Make the binary executable:
   ```bash
   chmod +x rbx-studio-mcp-x86_64-unknown-linux-gnu
   ```

### Verify Binary Integrity

```bash
# Download the checksums file
wget https://github.com/Roblox/studio-rust-mcp-server/releases/latest/download/checksums.txt

# Verify the binary
sha256sum -c checksums.txt
```

## Installation

### Install the MCP Server

```bash
# Run without arguments to install the plugin and configure MCP clients
./rbx-studio-mcp-x86_64-unknown-linux-gnu

# Or run as MCP server on stdio
./rbx-studio-mcp-x86_64-unknown-linux-gnu --stdio
```

### MCP Client Configuration

The installer will automatically configure the following MCP clients:

#### Claude Desktop
- **Config Location**: `~/.config/claude/claude_desktop_config.json`
- **Configuration**:
  ```json
  {
    "mcpServers": {
      "Roblox Studio": {
        "command": "/path/to/rbx-studio-mcp-x86_64-unknown-linux-gnu",
        "args": ["--stdio"]
      }
    }
  }
  ```

#### Cursor
- **Config Location**: `~/.cursor/mcp.json`
- **Configuration**:
  ```json
  {
    "mcpServers": {
      "Roblox Studio": {
        "command": "/path/to/rbx-studio-mcp-x86_64-unknown-linux-gnu",
        "args": ["--stdio"]
      }
    }
  }
  ```

## WSL (Windows Subsystem for Linux) Support

This project fully supports WSL. You can:

1. **Build in WSL**: Use any of the build methods above within your WSL environment
2. **Run in WSL**: The MCP server runs natively in WSL
3. **Access Windows Roblox Studio**: The server can communicate with Roblox Studio running on Windows

### WSL-Specific Notes

- Make sure you have Roblox Studio installed on your Windows system
- The MCP server will automatically detect and connect to Roblox Studio
- GUI dialogs (zenity) work in WSL with X11 forwarding or WSLg

## Troubleshooting

### Common Issues

1. **"Permission denied" when running binary**:
   ```bash
   chmod +x rbx-studio-mcp-x86_64-unknown-linux-gnu
   ```

2. **Missing dependencies**:
   ```bash
   # Install build dependencies
   sudo apt-get install build-essential pkg-config libssl-dev
   ```

3. **Rust not found**:
   ```bash
   # Install Rust
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source ~/.cargo/env
   ```

4. **GUI dialogs not working**:
   - Install zenity: `sudo apt-get install zenity`
   - For WSL: Enable X11 forwarding or use WSLg

### Debug Mode

Run with debug logging:
```bash
RUST_LOG=debug ./rbx-studio-mcp-x86_64-unknown-linux-gnu --stdio
```

## Development

### Running Tests

```bash
# Run all tests
cargo test

# Run tests for specific target
cargo test --target x86_64-unknown-linux-gnu
```

### Building for Development

```bash
# Debug build
cargo build --target x86_64-unknown-linux-gnu

# Release build with optimizations
cargo build --release --target x86_64-unknown-linux-gnu
```

## Contributing

When contributing to Linux support:

1. Test on both x86_64 and aarch64 architectures
2. Ensure the build scripts work on different Linux distributions
3. Test WSL compatibility
4. Update this documentation if needed

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
