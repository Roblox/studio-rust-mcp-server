local Main = script:FindFirstAncestor("MCPStudioPlugin")
local CommonHandler = require(Main.App.RemoteHandlers.CommonHandler)
local ConnectionManager = require(Main.Utils.ConnectionManager)
local DataModelStatusMonitor = require(Main.Utils.DataModelStatusMonitor)
local DataModelType = require(Main.Utils.DataModelType)

local currentDatamodel: DataModelType.DataModelType? = nil
local responseHandlerConnection: RBXScriptConnection? = nil

local function serve(datamodel: DataModelType.DataModelType, handlers)
	currentDatamodel = datamodel

	ConnectionManager.initEventBridge(datamodel, true, true)
	ConnectionManager.startWebSocket(datamodel)

	responseHandlerConnection = CommonHandler.registerHandlers(handlers)

	local client = ConnectionManager.getClient()
	if not client then
		error("Failed to get client")
	end
	client.Opened:Once(function()
		assert(currentDatamodel, "Current datamodel is not set")
		DataModelStatusMonitor.notifyDataModelCreated(currentDatamodel)
	end)
end

local function stop()
	assert(currentDatamodel, "Current datamodel is not set")
	DataModelStatusMonitor.notifyDataModelDestroyed(currentDatamodel)
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
