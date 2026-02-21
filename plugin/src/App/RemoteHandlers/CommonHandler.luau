local Main = script:FindFirstAncestor("MCPStudioPlugin")
local EventBridge = require(Main.Utils.EventBridge)
local EventBridgePing = require(Main.Utils.EventBridgePing)

local function registerHandlers(handlers)
	local responseHandlerConnection = EventBridgePing.registerResponseHandler()
	for toolName, handler in handlers do
		EventBridge.registerFunction(toolName, handler)
	end
	return responseHandlerConnection
end

return {
	registerHandlers = registerHandlers,
}
