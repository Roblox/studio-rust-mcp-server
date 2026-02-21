local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ConnectionManager = require(Main.Utils.ConnectionManager)
local DataModelStatusMonitor = require(Main.Utils.DataModelStatusMonitor)
local EventBridge = require(Main.Utils.EventBridge)
local EventBridgePing = require(Main.Utils.EventBridgePing)

local currentDatamodelType: string? = nil
local responseHandlerConnection: RBXScriptConnection? = nil

local function serve(datamodelType: string, handlers)
	currentDatamodelType = datamodelType
	ConnectionManager.initEventBridge(datamodelType)
	ConnectionManager.startWebSocket()

	responseHandlerConnection = EventBridgePing.registerResponseHandler()
	for toolName, handler in handlers do
		EventBridge.registerFunction(toolName, handler)
	end

	local client = ConnectionManager.getClient()
	if not client then
		error("Failed to get client")
	end
	client.Opened:Once(function()
		assert(currentDatamodelType, "Current datamodel type is not set")
		DataModelStatusMonitor.notifyDataModelCreated(currentDatamodelType)
	end)
end

local function stop()
	assert(currentDatamodelType, "Current datamodel type is not set")
	DataModelStatusMonitor.notifyDataModelDestroyed(currentDatamodelType)
	ConnectionManager.stopWebSocket()
	if responseHandlerConnection then
		responseHandlerConnection:Disconnect()
		responseHandlerConnection = nil
	end
end

return {
	serve = serve,
	stop = stop,
}
