# Installation Guide

Install the Roblox Studio MCP Server from source. This fork fixes a critical CPU bug (150%+ idle usage) in the official Roblox release.

## Prerequisites

- [Rust](https://rustup.rs/) (latest stable)
- [Roblox Studio](https://create.roblox.com/docs/studio/setting-up-roblox-studio)
- Claude Code, Claude Desktop, or Cursor

## Remove Official Roblox Release (if installed)

If you previously installed the official Roblox MCP server, remove it first to avoid conflicts and CPU issues.

### 1. Kill running processes

```bash
# Check for running processes (look for high CPU usage!)
ps aux | grep rbx-studio-mcp | grep -v grep

# Kill any running instances
pkill -f rbx-studio-mcp
```

### 2. Remove old binaries

```bash
# macOS - check common locations and remove
rm -f /Applications/RobloxStudioMCP.app/Contents/MacOS/rbx-studio-mcp
rm -f ~/bin/rbx-studio-mcp
rm -f ~/.local/bin/rbx-studio-mcp

# Windows - remove from common locations
# del "%LOCALAPPDATA%\Programs\rbx-studio-mcp\rbx-studio-mcp.exe"
```

### 3. Remove old MCP configurations

```bash
# Claude Code - list and remove old entries
claude mcp list
claude mcp remove Roblox-Studio --scope user 2>/dev/null
claude mcp remove roblox-studio --scope user 2>/dev/null

# Claude Desktop - edit config file
# macOS: ~/Library/Application Support/Claude/claude_desktop_config.json
# Windows: %APPDATA%\Claude\claude_desktop_config.json
# Remove any "Roblox Studio" entries pointing to old binaries

# Cursor - edit ~/.cursor/mcp.json
# Remove any entries pointing to old binaries
```

## Clone or Update

```bash
# First time: clone the repo
git clone git@github.com:splash-screen-studio/studio-rust-mcp-server.git
cd studio-rust-mcp-server

# Or if already cloned: pull latest
cd studio-rust-mcp-server
git pull origin main
```

## Build

```bash
cargo build --release
```

## Install Plugin

Copy the compiled plugin to your Roblox Studio plugins folder:

```bash
# macOS
cp target/release/build/rbx-studio-mcp-*/out/MCPStudioPlugin.rbxm ~/Documents/Roblox/Plugins/

# Windows
copy target\release\build\rbx-studio-mcp-*\out\MCPStudioPlugin.rbxm "%LOCALAPPDATA%\Roblox\Plugins\"
```

## Configure MCP Clients

### Claude Code (CLI)

```bash
claude mcp add --transport stdio roblox-studio --scope user -- /path/to/studio-rust-mcp-server/target/release/rbx-studio-mcp --stdio
```

Verify with:
```bash
claude mcp list
```

### Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "Roblox Studio": {
      "command": "/path/to/studio-rust-mcp-server/target/release/rbx-studio-mcp",
      "args": ["--stdio"]
    }
  }
}
```

### Cursor

Edit `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "Roblox Studio": {
      "command": "/path/to/studio-rust-mcp-server/target/release/rbx-studio-mcp",
      "args": ["--stdio"]
    }
  }
}
```

## Verify Installation

1. Restart Roblox Studio
2. Check the Plugins tab for "MCP" button
3. Open Studio console - should see: `The MCP Studio plugin is ready for prompts.`
4. Restart your MCP client (Claude Code, Claude Desktop, or Cursor)
5. Verify tools are available: `run_code` and `insert_model`

### Verify CPU Fix

```bash
# Check CPU usage - should be near 0% at idle, NOT 150%+
ps aux | grep rbx-studio-mcp | grep -v grep

# Example of GOOD output (low CPU):
# bedwards  12345  0.1  0.0 ... rbx-studio-mcp --stdio

# Example of BAD output (old buggy version):
# bedwards  12345  163.0  0.0 ... rbx-studio-mcp --stdio
```

If you see high CPU usage, you're still running the old binary. Re-check the removal steps above.

## Updating

```bash
cd studio-rust-mcp-server
git pull origin main
cargo build --release
cp target/release/build/rbx-studio-mcp-*/out/MCPStudioPlugin.rbxm ~/Documents/Roblox/Plugins/
```

Then restart Studio and your MCP client.
