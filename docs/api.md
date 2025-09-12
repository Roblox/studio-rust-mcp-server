# API Reference

This document provides detailed information about the Roblox Studio MCP Server API.

## Server Endpoints

### MCP Protocol Endpoints

The server implements the Model Context Protocol (MCP) and provides the following tools:

#### `run_code`
Execute Luau scripts in Roblox Studio.

**Parameters**:
- `command` (string): The Luau code to execute

**Response**:
- Success: Returns the output from the script execution
- Error: Returns error message and details

**Example**:
```json
{
  "command": "print('Hello from Roblox Studio!')"
}
```

#### `insert_model`
Import models from the Roblox Marketplace.

**Parameters**:
- `query` (string): Search query for the model

**Response**:
- Success: Returns the name of the imported model
- Error: Returns error message if model not found

**Example**:
```json
{
  "query": "basic house model"
}
```

#### `search` (ChatGPT MCP)
Search for code examples and model information.

**Parameters**:
- `query` (string): Search query

**Response**:
```json
{
  "results": [
    {
      "id": "player-spawn-script",
      "title": "Player Spawn Script - ServerScript",
      "url": "https://create.roblox.com/docs/scripting/players"
    }
  ]
}
```

#### `fetch` (ChatGPT MCP)
Retrieve detailed code or model information.

**Parameters**:
- `id` (string): Resource identifier

**Response**:
```json
{
  "id": "player-spawn-script",
  "title": "Player Spawn Script - ServerScript",
  "text": "-- Complete Luau code here...",
  "url": "https://create.roblox.com/docs/scripting/players",
  "metadata": {
    "type": "code",
    "script_type": "ServerScript",
    "category": "player_management"
  }
}
```

## HTTP Endpoints

### Studio Communication

#### `POST /request`
Long polling endpoint for Studio plugin requests.

**Response**: Returns pending tool requests from AI assistants.

#### `POST /response`
Endpoint for Studio plugin responses.

**Parameters**:
```json
{
  "response": "Script executed successfully",
  "id": "uuid-here"
}
```

#### `POST /proxy`
Proxy endpoint for direct tool execution.

**Parameters**:
```json
{
  "args": {
    "RunCode": {
      "command": "print('Hello World')"
    }
  },
  "id": "uuid-here"
}
```

## Error Handling

### Error Types

- **Connection Error**: Studio not running or plugin not connected
- **Script Error**: Invalid Luau syntax or runtime errors
- **Model Error**: Invalid model ID or marketplace issues
- **MCP Error**: Protocol violations or invalid requests

### Error Response Format

```json
{
  "error": {
    "type": "ScriptError",
    "message": "Invalid Luau syntax",
    "details": "Line 5: unexpected token"
  }
}
```

## Configuration

### Environment Variables

- `RUST_LOG`: Log level (debug, info, warn, error)
- `STUDIO_PLUGIN_PORT`: Port for Studio communication (default: 44755)

### Server Configuration

The server can be configured through command line arguments:

```bash
rbx-studio-mcp --stdio  # MCP mode
rbx-studio-mcp --help   # Show help
```

## Rate Limiting

- **Script Execution**: No rate limiting (executes immediately)
- **Model Importing**: Limited by Roblox Marketplace API
- **Search/Fetch**: No rate limiting for mock data

## Security Considerations

- Scripts execute with full Studio permissions
- Models are imported from official Roblox Marketplace
- No data is stored or transmitted to external services
- All communication happens locally

## Troubleshooting

### Common Issues

1. **Studio Not Responding**
   - Check if Studio is running
   - Verify MCP plugin is enabled
   - Check console for error messages

2. **Scripts Not Executing**
   - Verify Luau syntax
   - Check script placement requirements
   - Review Studio console output

3. **Models Not Importing**
   - Verify internet connection
   - Check model ID validity
   - Ensure marketplace access

### Debug Information

Enable debug logging to see detailed request/response information:

```bash
RUST_LOG=debug cargo run
```

This will show:
- MCP protocol messages
- Studio communication
- Script execution details
- Error stack traces
