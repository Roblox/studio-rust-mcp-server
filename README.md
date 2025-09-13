# Roblox Studio MCP Server

A powerful Model Context Protocol (MCP) server that bridges Roblox Studio with AI assistants, enabling seamless integration for code generation, model importing, and intelligent development workflows.

## 🚀 Overview

This MCP server transforms Roblox Studio into an AI-powered development environment by providing:

- **Code Generation**: Generate and execute Luau scripts directly in Roblox Studio
- **Model Importing**: Search and import models from the Roblox Marketplace
- **AI Integration**: Works with Claude, ChatGPT, and Cursor for intelligent assistance
- **Real-time Communication**: Bidirectional communication between AI and Studio

## ✨ Features

### Core Capabilities
- **Run Code**: Execute Luau scripts in Roblox Studio (ServerScripts and LocalScripts)
- **Insert Models**: Import models from the Roblox Marketplace
- **Unit Testing**: Comprehensive testing framework with TDD support, module reloading, and mocking
- **Search & Fetch**: Find code examples and model information (ChatGPT integration)
- **Real-time Feedback**: Get immediate results and error handling

### Testing Features
- **Test-Driven Development**: Full TDD workflow support with Red-Green-Refactor cycle
- **Module Reloading**: Reload modules during testing to simulate fresh state
- **Mocking Framework**: Create mocks for isolated testing of components
- **Assertion Library**: Comprehensive assertion methods for test validation
- **Test Coverage**: Track test execution and results with detailed reporting
- **Timeout Support**: Prevent hanging tests with configurable timeouts

### AI Assistant Support
- **Claude Desktop**: Full integration with Claude's desktop application
- **ChatGPT**: Deep research and connector support via MCP protocol
- **Cursor**: Seamless integration with Cursor's AI-powered editor

## 🏗️ Architecture

![MCP Server Architecture](MCP-Server.png)

The server consists of:
- **Rust MCP Server**: Handles AI communication and tool routing
- **Web Server**: Manages communication with Roblox Studio plugin
- **Studio Plugin**: Luau plugin that executes commands in Studio

## 🛠️ Installation

### Quick Start (Recommended)

1. **Prerequisites**:
   - [Roblox Studio](https://create.roblox.com/docs/en-us/studio/setup)
   - [Rust](https://www.rust-lang.org/tools/install) (for building from source)
   - One of: [Claude Desktop](https://claude.ai/download), [Cursor](https://www.cursor.com/), or [ChatGPT](https://chatgpt.com/)

2. **Install**:
   ```bash
   git clone https://github.com/Roblox/studio-rust-mcp-server.git
   cd studio-rust-mcp-server
   cargo run
   ```

3. **Verify**: Open Roblox Studio and check for the MCP plugin in the Plugins tab.

### Release Binaries

Download pre-built binaries from the [releases page](https://github.com/Roblox/studio-rust-mcp-server/releases).

## 📚 Implementation Guides

Choose your AI assistant for detailed setup instructions:

- **[Cursor Integration](docs/cursor/README.md)** - For Cursor users
- **[ChatGPT Integration](docs/chatgpt/README.md)** - For ChatGPT users  
- **[Claude Integration](docs/claude/README.md)** - For Claude Desktop users

> **Note**: All implementation guides are located in the `docs/` directory with comprehensive setup instructions, usage examples, and troubleshooting for each AI assistant.

## 🎯 Usage Examples

### Code Generation
```
"Create a player spawn script that gives new players a sword tool"
```

### Model Importing
```
"Import a basic house model from the marketplace"
```

### Unit Testing
```
"Create unit tests for a calculator module with addition and subtraction"
```

### Test-Driven Development
```
"Write failing tests for a new inventory system, then implement the code to pass them"
```

### ChatGPT Deep Research
```
"Show me examples of GUI interaction scripts and vehicle models"
```

## 🔧 Available Tools

| Tool | Description | AI Support |
|------|-------------|------------|
| `run_code` | Execute Luau scripts in Studio | Claude, Cursor |
| `insert_model` | Import models from marketplace | Claude, Cursor |
| `run_tests` | Execute unit tests with TDD support | Claude, Cursor |
| `search` | Find code examples and models | ChatGPT |
| `fetch` | Get detailed code/model information | ChatGPT |

## 🛡️ Security & Privacy

**Important**: This MCP server allows AI assistants to read and modify your Roblox Studio projects. 

- **Data Access**: AI assistants can see and modify your Studio projects
- **Third-party Privacy**: Data handling follows the AI assistant's privacy policies
- **Local Processing**: Code execution happens locally in your Studio environment
- **No Data Storage**: The server doesn't store your project data

## 🚨 Troubleshooting

### Common Issues

1. **Plugin Not Appearing**:
   - Restart Roblox Studio
   - Check console for error messages
   - Verify plugin installation

2. **AI Assistant Not Connecting**:
   - Restart the AI application
   - Check MCP configuration
   - Verify server is running

3. **Code Not Executing**:
   - Check Studio console for errors
   - Verify script placement (ServerScriptService vs StarterGui)
   - Ensure proper Luau syntax

### Debug Mode
```bash
RUST_LOG=debug cargo run
```

## 🔄 Development

### Building from Source
```bash
cargo build --release
```

### Running Tests
```bash
cargo test
```

### Code Quality
```bash
cargo clippy
cargo fmt
```

## 📖 Documentation

### Implementation Guides
- [Cursor Integration](docs/cursor/README.md) - Complete Cursor setup and usage
- [ChatGPT Integration](docs/chatgpt/README.md) - Deep research and connector setup
- [Claude Integration](docs/claude/README.md) - Claude Desktop integration

### Technical Documentation
- [API Reference](docs/api.md) - Complete API documentation
- [Plugin Development](docs/plugin.md) - Studio plugin architecture
- [Documentation Overview](docs/README.md) - All documentation in one place

### Additional Resources
- [MCP Protocol](https://modelcontextprotocol.io/) - Official MCP documentation
- [Contributing](CONTRIBUTING.md) - How to contribute to the project

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Roblox](https://www.roblox.com/) for the amazing Studio platform
- [Anthropic](https://www.anthropic.com/) for Claude and MCP protocol
- [OpenAI](https://openai.com/) for ChatGPT integration
- [Cursor](https://www.cursor.com/) for AI-powered development

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/Roblox/studio-rust-mcp-server/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Roblox/studio-rust-mcp-server/discussions)
- **Documentation**: [Wiki](https://github.com/Roblox/studio-rust-mcp-server/wiki)

---

**Ready to supercharge your Roblox development?** Choose your AI assistant and start building! 🚀