# Cursor Integration Guide

This guide shows you how to integrate the Roblox Studio MCP Server with Cursor for AI-powered Roblox development.

## 🎯 What You'll Get

- **AI Code Generation**: Generate Luau scripts directly in Cursor
- **Studio Integration**: Execute code in Roblox Studio from Cursor
- **Model Importing**: Search and import models from the marketplace
- **Intelligent Assistance**: Get context-aware help for Roblox development

## 📋 Prerequisites

- [Cursor](https://www.cursor.com/) installed and running
- [Roblox Studio](https://create.roblox.com/docs/en-us/studio/setup) installed
- [Rust](https://www.rust-lang.org/tools/install) (for building from source)

## 🚀 Quick Setup

### 1. Install the MCP Server

```bash
# Clone the repository
git clone https://github.com/Roblox/studio-rust-mcp-server.git
cd studio-rust-mcp-server

# Build and install
cargo run
```

### 2. Configure Cursor

The installer automatically configures Cursor, but you can also set it up manually:

1. Open Cursor
2. Go to **Settings** → **Features** → **Model Context Protocol**
3. Add the following configuration:

```json
{
  "mcpServers": {
    "Roblox Studio": {
      "command": "path/to/rbx-studio-mcp.exe",
      "args": ["--stdio"]
    }
  }
}
```

### 3. Verify Installation

1. Open Roblox Studio
2. Check the **Plugins** tab for the MCP plugin
3. In Cursor, look for Roblox Studio tools in the AI chat

## 🛠️ Available Tools

### `run_code`

Execute Luau scripts in Roblox Studio.

**Example**:

```text
Create a script that spawns a part at the player's position when they click
```

**Response**: Generates and executes a complete Luau script in Studio.

### `insert_model`

Import models from the Roblox Marketplace.

**Example**:

```text
Import a basic house model for my game
```

**Response**: Searches and imports the requested model into your Studio project.

## 💡 Usage Examples

### Basic Script Generation

**Prompt**: "Create a player spawn script that gives new players a sword tool"

**What happens**:

1. Cursor generates the Luau code
2. MCP server executes it in Roblox Studio
3. You see the script in ServerScriptService
4. Players get a sword tool when they join

### Model Importing

**Prompt**: "Add a car model to my game"

**What happens**:

1. Cursor searches for car models
2. MCP server imports the selected model
3. Model appears in your Studio workspace
4. You can position and customize it

### Complex Development

**Prompt**: "Create a GUI system with a health bar and inventory"

**What happens**:

1. Cursor generates multiple scripts
2. Creates GUI elements in StarterGui
3. Sets up LocalScripts for client-side interaction
4. Implements ServerScripts for data management

## 🔧 Advanced Configuration

### Custom MCP Settings

Create a `.cursorrules` file in your project root:

```text
# Roblox Studio MCP Integration
- Use the run_code tool for all Luau script generation
- Always include proper error handling in scripts
- Use insert_model for 3D assets and models
- Generate both ServerScripts and LocalScripts as needed
- Include comments explaining the code functionality
```

### Project-Specific Setup

For team projects, create a `mcp-config.json`:

```json
{
  "robloxStudio": {
    "enabled": true,
    "autoExecute": true,
    "scriptLocation": "ServerScriptService",
    "modelLocation": "Workspace"
  }
}
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Cursor not detecting MCP server

- Restart Cursor completely
- Check the MCP configuration in settings
- Verify the server executable path

#### 2. Scripts not executing in Studio

- Ensure Roblox Studio is running
- Check the MCP plugin is enabled
- Look for errors in Studio console

#### 3. Models not importing

- Verify internet connection
- Check marketplace permissions
- Ensure model IDs are valid

### Debug Mode

Enable debug logging:

```bash
RUST_LOG=debug cargo run
```

Check Cursor's developer console for MCP communication logs.

## 🎨 Best Practices

### Code Generation

- Always specify script type (ServerScript vs LocalScript)
- Include error handling and validation
- Use proper Roblox services and APIs
- Add comments for complex logic

### Model Importing Best Practices

- Specify model requirements clearly
- Consider performance implications
- Test models in different scenarios
- Document model usage

### Workflow Integration

- Use Cursor's chat for quick iterations
- Leverage code completion for Roblox APIs
- Combine multiple tools for complex features
- Test everything in Studio before committing

## 📚 Additional Resources

- [Cursor Documentation](https://cursor.sh/docs)
- [Roblox Studio Scripting](https://create.roblox.com/docs/scripting)
- [Luau Language Reference](https://create.roblox.com/docs/luau)
- [MCP Protocol](https://modelcontextprotocol.io/)

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/Roblox/studio-rust-mcp-server/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Roblox/studio-rust-mcp-server/discussions)
- **Cursor Community**: [Discord](https://discord.gg/cursor)

---

**Ready to supercharge your Roblox development with Cursor?** Start by asking the AI to create a simple script! 🚀
