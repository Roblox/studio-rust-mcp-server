# ChatGPT Integration Guide

This guide shows you how to integrate the Roblox Studio MCP Server with ChatGPT for AI-powered Roblox development using deep research and connectors.

## 🎯 What You'll Get

- **Deep Research**: Search through Roblox code examples and model information
- **Code Examples**: Get complete, ready-to-use Luau scripts
- **Model Information**: Detailed specifications and usage instructions
- **Intelligent Search**: Find relevant resources based on your queries
- **API Integration**: Use with ChatGPT's API for custom applications

## 📋 Prerequisites

- [ChatGPT Plus/Pro](https://chat.openai.com/) with Developer mode enabled
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

### 2. Enable Developer Mode in ChatGPT

1. Go to [ChatGPT Settings](https://chat.openai.com/settings)
2. Navigate to **Connectors** → **Advanced**
3. Enable **Developer mode**
4. This unlocks the full MCP connector functionality

### 3. Configure MCP Server

The server automatically supports ChatGPT's MCP requirements with:
- `search` tool for finding code examples and models
- `fetch` tool for retrieving detailed information
- Proper JSON formatting for ChatGPT integration

## 🛠️ Available Tools

### `search`
Find code examples and model information based on your query.

**Example Queries**:
- "player spawning scripts"
- "GUI interaction code"
- "house models for building"
- "vehicle models with physics"
- "weapon models for tools"

**Response**: Returns a list of relevant resources with IDs, titles, and URLs.

### `fetch`
Get complete code examples or detailed model information.

**Example IDs**:
- `player-spawn-script` - Complete ServerScript for player spawning
- `gui-interaction-code` - Full LocalScript for GUI interaction
- `basic-house-model` - Detailed house model specifications
- `vehicle-model` - Car model with usage instructions

**Response**: Returns complete code or detailed model information.

## 💡 Usage Examples

### Code Research

**Prompt**: "Show me examples of player management scripts in Roblox"

**What happens**:
1. ChatGPT searches for player-related code
2. Returns multiple script examples
3. You can fetch complete implementations
4. Get ready-to-use Luau code

### Model Discovery

**Prompt**: "Find building models for creating a medieval town"

**What happens**:
1. ChatGPT searches for building-related models
2. Returns house, castle, and structure models
3. Provides detailed specifications
4. Shows usage instructions and compatibility

### Deep Research

**Prompt**: "Research GUI systems in Roblox and show me complete implementations"

**What happens**:
1. ChatGPT performs deep research using multiple searches
2. Fetches detailed code examples
3. Provides comprehensive analysis
4. Gives you complete, working solutions

## 🔧 API Integration

### Using with ChatGPT API

```bash
curl https://api.openai.com/v1/responses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
  "model": "o4-mini-deep-research",
  "input": [
    {
      "role": "user",
      "content": [
        {
          "type": "input_text",
          "text": "Show me Roblox scripting examples for player management"
        }
      ]
    }
  ],
  "tools": [
    {
      "type": "mcp",
      "server_label": "roblox-studio",
      "server_url": "YOUR_SERVER_URL",
      "allowed_tools": ["search", "fetch"],
      "require_approval": "never"
    }
  ]
}'
```

### Custom Applications

```python
import openai

# Configure MCP server
mcp_config = {
    "type": "mcp",
    "server_label": "roblox-studio",
    "server_url": "http://localhost:3000",
    "allowed_tools": ["search", "fetch"],
    "require_approval": "never"
}

# Use with ChatGPT API
response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[
        {"role": "user", "content": "Find Roblox GUI examples"}
    ],
    tools=[mcp_config]
)
```

## 🎨 Advanced Usage

### Search Strategies

**Broad Searches**:
- "scripting" - General code examples
- "models" - All model types
- "gui" - Interface-related resources

**Specific Searches**:
- "player spawn ServerScript" - Specific script types
- "car model vehicle" - Specific model categories
- "datastore persistence" - Specific functionality

### Fetch Strategies

**Code Examples**:
- Always fetch complete implementations
- Look for metadata (script type, category)
- Use multiple examples for comparison

**Model Information**:
- Check asset IDs and pricing
- Review compatibility information
- Read usage instructions carefully

## 🔍 Search Categories

### Code Examples
- **Player Management**: Spawning, respawning, data handling
- **GUI Systems**: Interface creation, interaction, animation
- **Data Persistence**: DataStores, player data, game state
- **Game Mechanics**: Combat, movement, inventory

### Model Types
- **Building Kits**: Houses, structures, environments
- **Vehicles**: Cars, planes, boats with physics
- **Weapons**: Tools, swords, guns with animations
- **UI Elements**: Buttons, frames, menus

## 🐛 Troubleshooting

### Common Issues

**1. ChatGPT not finding MCP server**
- Ensure Developer mode is enabled
- Check server is running and accessible
- Verify MCP configuration

**2. Search returning no results**
- Try broader search terms
- Check server logs for errors
- Ensure proper MCP protocol compliance

**3. Fetch returning incomplete data**
- Verify resource IDs are correct
- Check server response format
- Look for JSON parsing errors

### Debug Mode

Enable debug logging:

```bash
RUST_LOG=debug cargo run
```

Check ChatGPT's network tab for MCP requests and responses.

## 🎯 Best Practices

### Effective Queries
- Be specific about what you're looking for
- Use relevant keywords (script, model, gui, etc.)
- Ask for complete examples, not just snippets
- Combine multiple searches for comprehensive results

### Code Usage
- Always review generated code before using
- Test in Studio before implementing
- Customize code for your specific needs
- Add proper error handling and validation

### Model Integration
- Check compatibility with your game
- Review pricing and licensing
- Test performance impact
- Customize models as needed

## 📚 Additional Resources

- [ChatGPT Documentation](https://platform.openai.com/docs)
- [MCP Protocol](https://modelcontextprotocol.io/)
- [Roblox Studio Scripting](https://create.roblox.com/docs/scripting)
- [Luau Language Reference](https://create.roblox.com/docs/luau)

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/Roblox/studio-rust-mcp-server/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Roblox/studio-rust-mcp-server/discussions)
- **ChatGPT Support**: [OpenAI Help Center](https://help.openai.com/)

---

**Ready to explore Roblox development with ChatGPT's deep research capabilities?** Start by asking for code examples or model information! 🚀
