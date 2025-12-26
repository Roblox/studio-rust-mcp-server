# Installation Guide

Install the Roblox Studio MCP Server from source.

## Prerequisites

- [Rust](https://rustup.rs/) (latest stable)
- [Roblox Studio](https://create.roblox.com/docs/studio/setting-up-roblox-studio)
- Claude Code, Claude Desktop, or Cursor

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

## Updating

```bash
cd studio-rust-mcp-server
git pull origin main
cargo build --release
cp target/release/build/rbx-studio-mcp-*/out/MCPStudioPlugin.rbxm ~/Documents/Roblox/Plugins/
```

Then restart Studio and your MCP client.
