# Roblox Studio MCP Server

This repository contains a reference implementation of the Model Context Protocol (MCP). The primary workflow enables communication between Roblox Studio (via a plugin) and Google's Gemini models through a Python-based agent. It also supports legacy integrations with [Claude Desktop](https://claude.ai/download) or [Cursor](https://www.cursor.com/).
It consists of the following Rust-based components, which communicate through internal shared
objects.

- A web server built on `axum` that a Studio plugin long polls.
- A `rmcp` server that talks to Claude via `stdio` transport (for legacy setups) or directly to the Roblox Studio plugin when used with the Python agent.

When LLM requests to run a tool, the plugin will get a request through the long polling and post a
response. It will cause responses to be sent to the LLM application.

**Please note** that this MCP server will be accessed by third-party tools, allowing them to modify
and read the contents of your opened place. Third-party data handling and privacy practices are
subject to their respective terms and conditions.

![Scheme](MCP-Server.png)

The setup process installs a Roblox Studio plugin and helps configure the system for the chosen workflow.

## Getting Started with Gemini (Python Agent Workflow)

This project now primarily supports interacting with Google's Gemini models through a Python-based agent. This provides a flexible and powerful way to connect Gemini's capabilities to Roblox Studio.

The `rbx-studio-mcp.exe` (Rust application) acts as a vital bridge, running as an MCP server that directly communicates with a Roblox Studio plugin. The Python agent then connects to this Rust MCP server to send commands to and receive data from Roblox Studio.

### Prerequisites

*   **Python**: Version 3.9 or higher recommended. Ensure Python is added to your system's PATH.
*   **Rust and Cargo**: If not already installed, the `build_rust_server.bat` script (see step 2 below) will attempt to download and install them for you using `rustup`.
*   **Roblox Studio**: Must be installed.

### Setup Instructions

Follow these steps to set up and run the Gemini Python agent with Roblox Studio:

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/Roblox/studio-rust-mcp-server.git
    cd studio-rust-mcp-server
    ```

2.  **Build the Rust MCP Server & Install Studio Plugin**:
    Run the `build_rust_server.bat` script:
    ```batch
    build_rust_server.bat
    ```
    This script performs several key actions:
    *   Checks if Rust/Cargo is installed. If not, it will attempt to download and run `rustup-init.exe` to install them. If this happens, you **must restart your terminal/command prompt after `rustup` finishes and re-run `build_rust_server.bat`** for the PATH changes to take effect.
    *   Compiles the `rbx-studio-mcp.exe` application with the `gemini_python_broker` feature enabled.
    *   Automatically runs the compiled `rbx-studio-mcp.exe` in its one-time "installer" mode. This installs the `MCPStudioPlugin.rbxm` into your Roblox Studio plugins folder and provides guidance for the Python workflow.

3.  **Set up Python Virtual Environment & Dependencies**:
    Run the `setup_venv.bat` script:
    ```batch
    setup_venv.bat
    ```
    This creates a Python virtual environment in a folder named `venv` and installs dependencies from `requirements.txt`.

4.  **Configure Your Gemini API Key**:
    Create a `.env` file in the project root directory with your Gemini API key:
    ```env
    GEMINI_API_KEY="YOUR_API_KEY_HERE"
    ```
    Replace `"YOUR_API_KEY_HERE"` with your actual key. This file is gitignored.

### Running the System

To use the Gemini agent with Roblox Studio:

1.  **Open Roblox Studio**: And open your target place. Ensure the "MCPStudioPlugin" is enabled (it should be by default after installation).
2.  **Start the Rust MCP Server**: In a terminal, run:
    ```batch
    run_rust_server.bat
    ```
    Keep this window open. It will display connection information and logs.
3.  **Start the Python Agent**: In another terminal, run:
    ```batch
    run_agent.bat
    ```
    This starts the console interface for the Gemini agent.

### Using the Agent

Type your prompts into the Python agent's console. It will interact with Gemini and relay actions to Roblox Studio via the Rust MCP server.

## Legacy / Alternative Setups (Claude, Cursor, Manual)

The following sections describe older setup methods, primarily for integrating with Claude Desktop or Cursor, or for manual configuration.

### Setup with Release Binaries (Claude/Cursor Focus)

Note: This setup method is primarily for the legacy Claude/Cursor integration. For the Gemini Python workflow, please see the "Getting Started with Gemini" section above.

This MCP Server supports pretty much any MCP Client but will automatically set up only [Claude Desktop](https://claude.ai/download) and [Cursor](https://www.cursor.com/) if found.

To set up automatically:

1. Ensure you have [Roblox Studio](https://create.roblox.com/docs/en-us/studio/setup),
   and [Claude Desktop](https://claude.ai/download)/[Cursor](https://www.cursor.com/) installed and started at least once.
1. Exit MCP Clients and Roblox Studio if they are running.
1. Download and run the installer:
   1. Go to the [releases](https://github.com/Roblox/studio-rust-mcp-server/releases) page and
      download the latest release for your platform.
   1. Unzip the downloaded file if necessary and run the installer.
   1. Restart Claude/Cursor and Roblox Studio if they are running.

### Manual Configuration (Claude/Cursor)

Note: This setup method is primarily for the legacy Claude/Cursor integration.

To set up manually add following to your MCP Client config:

```json
{
  "mcpServers": {
    "Roblox Studio": {
      "args": [
        "--stdio"
      ],
      "command": "Path-to-downloaded\\rbx-studio-mcp.exe"
    }
  }
}
```

On macOS the path would be something like `"/Applications/RobloxStudioMCP.app/Contents/MacOS/rbx-studio-mcp"` if you move the app to the Applications directory.

### Building from Source (Legacy Claude/Cursor Setup)

The `build_rust_server.bat` script described in the "Getting Started with Gemini" section is the primary way to build the server from source, as it also handles the `gemini_python_broker` feature.

If you wish to build for the legacy Claude/Cursor integration specifically (without the Gemini feature by default, though the installer script will still run), you can use `cargo run`. This was the original method for Claude/Cursor setup:

1.  Ensure you have [Roblox Studio](https://create.roblox.com/docs/en-us/studio/setup) and [Claude Desktop](https://claude.ai/download)/[Cursor](https://www.cursor.com/) installed and started at least once.
2.  Exit Claude/Cursor and Roblox Studio if they are running.
3.  [Install Rust](https://www.rust-lang.org/tools/install).
4.  Download or clone this repository.
5.  Run `cargo run` from the root of this repository. This will:
    *   Build the Rust MCP server app (without the `gemini_python_broker` feature by default).
    *   Run the installer logic which, in this mode, attempts to set up Claude/Cursor and installs the Studio plugin.

After the command completes, the Studio MCP Server is installed and ready for your prompts from Claude Desktop.

### Verifying Claude/Cursor Setup

To make sure everything is set up correctly for Claude/Cursor, follow these steps:

1. In Roblox Studio, click on the **Plugins** tab and verify that the MCP plugin appears. Clicking on
   the icon toggles the MCP communication with Claude Desktop on and off, which you can verify in
   the Roblox Studio console output.
1. In the console, verify that `The MCP Studio plugin is ready for prompts.` appears in the output.
   Clicking on the plugin's icon toggles MCP communication with Claude Desktop on and off,
   which you can also verify in the console output.
1. Verify that Claude Desktop is correctly configured by clicking on the hammer icon for MCP tools
   beneath the text field where you enter prompts. This should open a window with the list of
   available Roblox Studio tools (`insert_model` and `run_code`).

**Note**: You can fix common issues with setup by restarting Studio and Claude Desktop. Claude
sometimes is hidden in the system tray, so ensure you've exited it completely.

### Sending Requests (Claude/Cursor)

1. Open a place in Studio.
1. Type a prompt in Claude Desktop and accept any permissions to communicate with Studio.
1. Verify that the intended action is performed in Studio by checking the console, inspecting the
   data model in Explorer, or visually confirming the desired changes occurred in your place.
