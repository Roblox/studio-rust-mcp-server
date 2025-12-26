# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Roblox Studio MCP Server - A Model Context Protocol (MCP) server that enables Claude Desktop and Cursor to communicate with Roblox Studio. It provides two tools: `run_code` (execute Luau code in Studio) and `insert_model` (search and insert models from Roblox marketplace).

## Build Commands

```bash
# Build and run (installs plugin and configures Claude Desktop/Cursor)
cargo run

# Build release binary
cargo build --release

# macOS universal binary (both architectures)
cargo build --release --target aarch64-apple-darwin
cargo build --release --target x86_64-apple-darwin
```

## Linting and Formatting

```bash
# Rust
cargo clippy -- -D warnings
cargo fmt -- --check

# Luau (from plugin directory)
cd plugin
selene .
stylua . --check
```

## Architecture

```
Claude Desktop/Cursor (MCP Client)
        ↓↑ stdio transport
MCP Server (Rust)
        ↓↑ HTTP (localhost:44755)
Roblox Studio Plugin (Luau)
        ↓↑ Long polling
Studio Workspace/Datamodel
```

### Core Components

- **`src/main.rs`**: CLI entry point, sets up Tokio runtime, spawns HTTP server (port 44755) and MCP server concurrently
- **`src/rbx_studio_server.rs`**: MCP handler implementing `ServerHandler` trait from rmcp crate; defines `run_code` and `insert_model` tools; manages state with `AppState` (process_queue, output_map, watch channel)
- **`src/install.rs`**: Installation logic - detects Roblox Studio, embeds plugin, updates Claude Desktop/Cursor config files
- **`src/error.rs`**: Custom error handling with color-eyre

### Plugin Components (Luau)

- **`plugin/src/Main.server.luau`**: Plugin entry point, runs HTTP long polling loop
- **`plugin/src/MockWebSocketService.luau`**: Simulates WebSocket via HTTP for Studio plugin
- **`plugin/src/Tools/RunCode.luau`**: Executes arbitrary Luau code, captures output
- **`plugin/src/Tools/InsertModel.luau`**: Searches marketplace and inserts models

### Communication Flow

1. Plugin long polls `/request` endpoint (15s timeout, HTTP 423 if no tasks)
2. MCP server queues tool requests with UUIDs
3. Plugin executes tools and POSTs results to `/response`
4. Response sent through channel to waiting MCP handler

### Watch Channel Pattern

The `request_handler` uses a `tokio::sync::watch` channel to efficiently wait for new tasks. **Critical**: When cloning a `watch::Receiver`, the clone inherits the "seen version" from the source. If you clone inside a loop and the source receiver never updates its version, each clone will immediately see stale values as "new", causing a hot loop. Always clone the receiver once before the loop, not inside it.

### Build Process

The `build.rs` script automatically compiles the Luau plugin using Rojo, embedding `MCPStudioPlugin.rbxm` into the binary.

## Testing

No automated tests. Manual verification:
1. Verify MCP plugin appears in Roblox Studio Plugins tab
2. Check console for "The MCP Studio plugin is ready for prompts."
3. Verify Claude Desktop shows available tools (insert_model, run_code)

## Profiling

```bash
# Install samply profiler (macOS)
brew install samply

# Profile the MCP server (requires signing or SIP disabled)
samply record ./target/release/rbx-studio-mcp --stdio
```

## Configuration Paths

- Claude Desktop (macOS): `~/Library/Application Support/Claude/claude_desktop_config.json`
- Claude Desktop (Windows): `%APPDATA%\Claude\claude_desktop_config.json`
- Cursor: `~/.cursor/mcp.json`
