# Plugin Development Guide

This guide explains how the Roblox Studio plugin works and how to extend it.

## Plugin Architecture

The Studio plugin consists of several Luau scripts that handle communication with the MCP server:

### Main Components

- **Main.server.luau**: Main plugin entry point
- **Tools/**: Individual tool implementations
- **MockWebSocketService.luau**: WebSocket simulation for Studio
- **Types.luau**: Type definitions

## Plugin Structure

```
plugin/
├── src/
│   ├── Main.server.luau          # Main plugin logic
│   ├── MockWebSocketService.luau # WebSocket simulation
│   ├── Types.luau               # Type definitions
│   └── Tools/
│       ├── InsertModel.luau      # Model importing tool
│       └── RunCode.luau          # Code execution tool
├── default.project.json          # Rojo project file
└── foreman.toml                  # Build configuration
```

## Main Plugin Logic

### Initialization

```lua
-- Main.server.luau
local MCPPlugin = {}

function MCPPlugin.init()
    -- Initialize WebSocket service
    -- Set up tool handlers
    -- Start communication loop
end
```

### Communication Loop

The plugin uses long polling to communicate with the MCP server:

```lua
local function pollForRequests()
    local success, response = pcall(function()
        return HttpService:GetAsync("http://127.0.0.1:44755/request")
    end)
    
    if success and response then
        handleRequest(response)
    end
end
```

## Tool Implementations

### RunCode Tool

Handles Luau script execution in Studio:

```lua
-- Tools/RunCode.luau
local function executeScript(code)
    -- Create script instance
    -- Set source code
    -- Execute and capture output
    -- Return results
end
```

### InsertModel Tool

Handles model importing from marketplace:

```lua
-- Tools/InsertModel.luau
local function importModel(query)
    -- Search marketplace
    -- Import model
    -- Place in workspace
    -- Return model name
end
```

## WebSocket Simulation

Since Roblox Studio doesn't have native WebSocket support, the plugin uses HTTP long polling:

```lua
-- MockWebSocketService.luau
local MockWebSocketService = {}

function MockWebSocketService.connect(url)
    -- Set up polling interval
    -- Handle connection state
    -- Manage message queuing
end
```

## Type Definitions

### Request/Response Types

```lua
-- Types.luau
export type ToolRequest = {
    args: ToolArguments,
    id: string?
}

export type ToolResponse = {
    response: string,
    id: string
}
```

## Extending the Plugin

### Adding New Tools

1. Create a new tool file in `Tools/`:

```lua
-- Tools/NewTool.luau
local NewTool = {}

function NewTool.execute(args)
    -- Tool implementation
    return "Tool executed successfully"
end

return NewTool
```

2. Register the tool in `Main.server.luau`:

```lua
local NewTool = require(script.Tools.NewTool)

-- Add to tool registry
tools["new_tool"] = NewTool
```

### Adding New MCP Tools

1. Update the Rust server to handle the new tool
2. Add the tool to the plugin's tool registry
3. Implement the tool logic in Luau
4. Test the integration

## Build Process

The plugin is built using Rojo:

```bash
# Build the plugin
rojo build plugin --output plugin.rbxm

# Watch for changes
rojo serve plugin
```

## Testing

### Unit Testing

Test individual tool functions:

```lua
-- Test script
local RunCode = require(script.Tools.RunCode)

local result = RunCode.execute("print('Hello World')")
assert(result == "Hello World")
```

### Integration Testing

Test the full MCP communication:

1. Start the MCP server
2. Load the plugin in Studio
3. Send test requests
4. Verify responses

## Debugging

### Console Logging

Add debug output to track execution:

```lua
print("MCP Plugin: Tool request received", request)
print("MCP Plugin: Tool response sent", response)
```

### Error Handling

Wrap tool execution in pcall:

```lua
local success, result = pcall(function()
    return tool.execute(args)
end)

if not success then
    warn("Tool execution failed:", result)
    return "Error: " .. tostring(result)
end
```

## Performance Considerations

### Memory Management

- Clean up temporary objects
- Use weak references where appropriate
- Monitor memory usage in long-running scripts

### Network Optimization

- Batch requests when possible
- Use appropriate polling intervals
- Handle network errors gracefully

## Security

### Input Validation

Validate all inputs from the MCP server:

```lua
local function validateScript(code)
    -- Check for dangerous functions
    -- Validate syntax
    -- Limit execution time
end
```

### Sandboxing

Run user code in a controlled environment:

```lua
local function createSandbox()
    local env = {
        -- Safe globals only
        print = print,
        warn = warn,
        -- Block dangerous functions
    }
    return env
end
```

## Deployment

### Plugin Distribution

1. Build the plugin with Rojo
2. Upload to Roblox as a plugin
3. Distribute the plugin ID
4. Users can install via the plugin ID

### Version Management

- Use semantic versioning
- Update plugin version in metadata
- Maintain backward compatibility
- Document breaking changes

## Troubleshooting

### Common Issues

1. **Plugin Not Loading**
   - Check Studio console for errors
   - Verify plugin permissions
   - Ensure all dependencies are available

2. **Communication Errors**
   - Verify MCP server is running
   - Check network connectivity
   - Review server logs

3. **Tool Execution Failures**
   - Validate input parameters
   - Check Studio permissions
   - Review error messages

### Debug Tools

Enable debug mode in the plugin:

```lua
local DEBUG = true

if DEBUG then
    print("Debug: Tool request", request)
    print("Debug: Tool response", response)
end
```

## Contributing

### Code Style

- Follow Luau style guidelines
- Use descriptive variable names
- Add comments for complex logic
- Include error handling

### Testing Requirements

- Unit tests for all tools
- Integration tests for MCP communication
- Error case testing
- Performance testing

---

For more information, see the [main documentation](../README.md) and [API reference](api.md).
