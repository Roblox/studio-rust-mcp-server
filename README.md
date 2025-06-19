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

## Using Local LLMs with Ollama

This project also supports using local Large Language Models (LLMs) through [Ollama](https://ollama.com/). This allows you to run powerful models directly on your own machine.

**Benefits of using Ollama:**
*   **Privacy**: Your prompts and code are processed locally, not sent to a third-party cloud service.
*   **Offline Capability**: Once models are downloaded, you can use the agent without an active internet connection (though initial setup and model downloads require internet).
*   **Custom Models**: Ollama supports a wide range of open-source models, and you can easily switch between them or even use customized versions.

### Installation and Setup (Ollama)

1.  **Prerequisites**:
    *   Ensure your Python environment is set up as described in the "Getting Started with Gemini" section (virtual environment, `requirements.txt` installed, especially the `ollama` package).
    *   Ollama itself needs to be installed on your system.

2.  **Ollama Setup Script**:
    This project includes a batch script to help you set up Ollama and download recommended models.
    *   **What it does**:
        *   Checks if Ollama is already installed.
        *   If not installed, it provides a download link and instructions.
        *   Pulls several common Ollama models suitable for coding tasks (e.g., `phi3:mini`, `qwen2:7b`).
    *   **How to run it**:
        Open a command prompt or terminal in the project root and run:
        ```batch
        .\ollama_setup.bat
        ```
        Follow the on-screen prompts.

### Running the Agent with Ollama

A dedicated batch script is provided to simplify running the agent with Ollama.

1.  **Ensure Rust MCP Server is Running**:
    Just like with the Gemini workflow, the Rust MCP server (`rbx-studio-mcp.exe`) must be running. Open a terminal and execute:
    ```batch
    run_rust_server.bat
    ```
    Keep this window open.

2.  **Run the Ollama Agent Script**:
    In another terminal, run the `run_ollama_agent.bat` script:
    ```batch
    .\run_ollama_agent.bat
    ```
    *   **What it does**:
        *   Checks if Ollama is installed and if the Ollama service/daemon is running.
        *   Attempts to start the Ollama service if it's not detected (by running a small model in the background).
        *   Presents a menu to select which Ollama model you want to use (from the ones downloaded by `ollama_setup.bat` or a custom one).
        *   Starts the Python agent (`main.py`) configured to use Ollama with your selected model.

### Configuration Options (Ollama)

The primary way to configure Ollama is through command-line arguments or the interactive menu in `run_ollama_agent.bat`. However, you can also view or (less commonly) manually edit these settings in `config.json` (created after the first run or if you manually copy `config.example.json`):

*   `"LLM_PROVIDER"`: Set this to `"ollama"` to use Ollama by default (can be overridden by command-line).
*   `"OLLAMA_API_URL"`: The API endpoint for your Ollama instance. Defaults to `"http://localhost:11434"`.
*   `"OLLAMA_DEFAULT_MODEL"`: The default Ollama model to use if not specified by other means. Defaults to `"phi3:mini"`.

### Command-Line Arguments for Ollama (`main.py`)

You can also run `main.py` directly with arguments to use Ollama:

*   `--llm_provider {gemini,ollama}`: Specifies the LLM provider.
    *   Example: `python main.py --llm_provider ollama`
*   `--ollama_model <model_name>`: Specifies which Ollama model to use. This overrides the `OLLAMA_DEFAULT_MODEL` from `config.json` and the selection from `run_ollama_agent.bat` if you run `main.py` directly.
    *   Example: `python main.py --llm_provider ollama --ollama_model qwen2:7b`

### Model Notes (Ollama)

*   The `ollama_setup.bat` script attempts to download the following models:
    *   `phi3:mini` (a capable small model)
    *   `qwen2:7b` (a larger, powerful model)
    *   `qwen2:7b-q4_K_M` (a quantized version of Qwen2 7B, offering a balance of performance and resource usage)
*   You can download other models compatible with Ollama by using the command `ollama pull <another_model_name:tag>`.
*   Once downloaded, you can use these additional models by:
    *   Selecting the "Enter custom model name" option in `run_ollama_agent.bat`.
    *   Using the `--ollama_model <another_model_name:tag>` command-line argument when running `main.py`.

#### Testing the Ollama Integration
To run a predefined set of test commands with the Ollama provider, you can use the `run_ollama_agent_test.bat` script. This script automates the execution of commands listed in `ollama_test_commands.txt` and is helpful for verifying that tool calls and responses are working as expected with your chosen Ollama model. It will use a default Ollama model specified within the batch file but calls `main.py` which allows for model override via its own arguments if you modify the batch script.

Run it from the project root:
```batch
.\run_ollama_agent_test.bat
```

## Known Issues

### Tool Execution Timeouts in Persistent Sessions

-   **Symptom**: Luau tools executed via the Python agent (e.g., `delete_instance`, `RunCode`, `GetInstanceProperties`) may consistently time out after approximately 20 seconds when `main.py` is run with the `--test_file` argument. This mode keeps the MCP server and its connection to the Python agent alive across multiple commands.
-   **Associated MCP Server Log**: When these timeouts occur, the `rbx-studio-mcp.exe` (Rust server) console often displays a critical error message in its STDERR output similar to: `Client that was waiting for task is gone. Task was not queued as it was consumed by send attempt.`
-   **Hypothesis**: This behavior suggests a potential issue within the Rust-based MCP server's task management, state handling, or client communication logic when dealing with multiple, sequential requests from a single, persistent client session (the Python agent). The linkage between the Luau script execution (initiated by the plugin) and the MCP server task awaiting its response might be prematurely lost or mishandled for subsequent commands in a session.
-   **Impact**: This issue prevents the reliable execution of command sequences when using the `--test_file` feature or any other mode that relies on a persistent session between the Python agent and the MCP server for multiple tool calls. Individual commands run via `--test_command` (which restart the agent and thus establish a new, brief MCP session) or single commands in interactive mode might appear to work more reliably regarding this specific timeout, but this is inefficient for sequences.
-   **Workaround/Current Status**: The previous behavior of the system, where each command effectively restarted the Python agent (e.g., running `python main.py --test_command "some command"` repeatedly via a batch script for each command), did not exhibit this specific 20-second timeout for each tool call. However, that approach is significantly slower due to the overhead of restarting the Python agent and re-establishing the MCP session for every command. The timeout issue became prominent after `main.py` was modified to keep the MCP session alive for processing multiple commands from a file or in a prolonged interactive session. Further investigation into the MCP server's handling of persistent client sessions and task lifecycles is needed.

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
