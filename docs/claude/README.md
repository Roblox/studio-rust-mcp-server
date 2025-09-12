# Claude Integration Guide

This guide shows you how to integrate the Roblox Studio MCP Server with Claude Desktop for AI-powered Roblox development.

## 🎯 What You'll Get

- **Direct Studio Integration**: Execute code and import models directly in Roblox Studio
- **Intelligent Code Generation**: Generate Luau scripts with proper Roblox APIs
- **Real-time Feedback**: See results immediately in Studio
- **Contextual Assistance**: Get help based on your current Studio project

## 📋 Prerequisites

- [Claude Desktop](https://claude.ai/download) installed and running
- [Roblox Studio](https://create.roblox.com/docs/en-us/studio/setup) installed
- [Rust](https://www.rust-lang.org/tools/install) (for building from source)

## 🚀 Quick Setup

### 1. Install the MCP Server

```bash
# Clone the repository
git clone https://github.com/Roblox/studio-rust-mcp-server.git
cd studio-rust-mcp-server

# Build and install (automatically configures Claude)
cargo run
```

### 2. Verify Installation

1. Open Roblox Studio
2. Check the **Plugins** tab for the MCP plugin
3. Open Claude Desktop
4. Look for Roblox Studio tools in the MCP tools section

### 3. Test the Connection

In Claude Desktop, try:
```
"Create a simple script that prints 'Hello World' to the console"
```

You should see the script appear in Roblox Studio's ServerScriptService.

## 🛠️ Available Tools

### `run_code`
Execute Luau scripts directly in Roblox Studio.

**Features**:
- Supports both ServerScripts and LocalScripts
- Automatic error handling and reporting
- Real-time execution feedback
- Proper script placement

**Example**:
```
Create a player spawn script that gives new players a sword tool and sets their spawn position
```

### `insert_model`
Import models from the Roblox Marketplace.

**Features**:
- Search by description or keywords
- Automatic model placement
- Error handling for invalid models
- Integration with Studio's model system

**Example**:
```
Import a basic house model for my game
```

## 💡 Usage Examples

### Basic Script Generation

**Prompt**: "Create a script that spawns a part when a player clicks"

**What happens**:
1. Claude generates the Luau code
2. Script is created in ServerScriptService
3. You can test it immediately in Studio
4. See the part spawn when you click

### Player Management

**Prompt**: "Set up a player data system with coins and level"

**What happens**:
1. Creates DataStore scripts for persistence
2. Sets up leaderstats for display
3. Implements save/load functionality
4. Ready to use in your game

### GUI Development

**Prompt**: "Create a main menu with play and settings buttons"

**What happens**:
1. Generates ScreenGui in StarterGui
2. Creates LocalScript for interaction
3. Implements button functionality
4. Adds proper styling and positioning

### Model Importing

**Prompt**: "Add a car model to my racing game"

**What happens**:
1. Searches for car models
2. Imports the selected model
3. Places it in your workspace
4. You can customize and use it

## 🔧 Advanced Configuration

### Custom Claude Settings

Create a `.claude-config.json` file:

```json
{
  "robloxStudio": {
    "defaultScriptLocation": "ServerScriptService",
    "autoExecute": true,
    "includeComments": true,
    "errorHandling": "verbose"
  }
}
```

### Project-Specific Setup

For team projects, create a `claude-rules.md`:

```markdown
# Roblox Studio Development Rules

- Always use proper Roblox services (Players, DataStoreService, etc.)
- Include error handling with pcall for DataStore operations
- Use proper script types (ServerScript vs LocalScript)
- Add comments explaining complex logic
- Follow Roblox coding conventions
```

## 🎨 Best Practices

### Code Generation
- **Be Specific**: Describe exactly what you want the script to do
- **Include Context**: Mention your game type or specific requirements
- **Ask for Examples**: Request complete, working implementations
- **Test Immediately**: Run the code in Studio to verify it works

### Model Importing
- **Describe Purpose**: Explain how you'll use the model
- **Specify Requirements**: Mention size, style, or functionality needs
- **Test Compatibility**: Ensure models work with your game
- **Customize After**: Modify imported models as needed

### Workflow Integration
- **Iterative Development**: Make small changes and test frequently
- **Use Studio Features**: Leverage Studio's tools alongside AI generation
- **Document Changes**: Keep track of what you've implemented
- **Version Control**: Commit working versions regularly

## 🔍 Troubleshooting

### Common Issues

**1. Claude not detecting MCP server**
- Restart Claude Desktop completely
- Check MCP configuration in settings
- Verify server is running

**2. Scripts not executing in Studio**
- Ensure Roblox Studio is running
- Check MCP plugin is enabled
- Look for errors in Studio console
- Verify script placement

**3. Models not importing**
- Check internet connection
- Verify model IDs are valid
- Ensure marketplace permissions
- Try different model descriptions

### Debug Mode

Enable debug logging:

```bash
RUST_LOG=debug cargo run
```

Check Claude's developer console for MCP communication logs.

## 🚀 Advanced Features

### Custom Script Templates

Create reusable script templates:

```
"Create a template for a tool script that I can customize for different weapons"
```

### Batch Operations

Generate multiple related scripts:

```
"Create a complete player management system with spawn, data, and GUI scripts"
```

### Integration with Studio Features

Combine AI generation with Studio tools:

```
"Create a script that works with the Terrain editor to generate random landscapes"
```

## 📚 Learning Resources

### Claude-Specific
- [Claude Desktop Documentation](https://claude.ai/help)
- [MCP Protocol](https://modelcontextprotocol.io/)
- [Claude Best Practices](https://claude.ai/help/best-practices)

### Roblox Development
- [Roblox Studio Scripting](https://create.roblox.com/docs/scripting)
- [Luau Language Reference](https://create.roblox.com/docs/luau)
- [Roblox API Reference](https://create.roblox.com/docs/reference)

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/Roblox/studio-rust-mcp-server/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Roblox/studio-rust-mcp-server/discussions)
- **Claude Support**: [Claude Help Center](https://claude.ai/help)

## 🎯 Quick Start Checklist

- [ ] Claude Desktop installed and running
- [ ] Roblox Studio installed
- [ ] MCP server built and running
- [ ] MCP plugin visible in Studio
- [ ] Test script executed successfully
- [ ] Ready to start developing!

---

**Ready to revolutionize your Roblox development with Claude?** Start by asking Claude to create a simple script! 🚀
