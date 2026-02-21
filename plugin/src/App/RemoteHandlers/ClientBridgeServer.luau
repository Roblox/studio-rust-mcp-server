local Main = script:FindFirstAncestor("MCPStudioPlugin")
local CommonHandler = require(Main.App.RemoteHandlers.CommonHandler)
local DataModelType = require(Main.Utils.DataModelType)
local EventBridge = require(Main.Utils.EventBridge)

local responseHandlerConnection: RBXScriptConnection? = nil
local function serve(datamodel: DataModelType.DataModelType, handlers)
	EventBridge.init(nil, datamodel, true, false)
	responseHandlerConnection = CommonHandler.registerHandlers(handlers)
end

local function stop()
	if responseHandlerConnection then
		responseHandlerConnection:Disconnect()
		responseHandlerConnection = nil
	end
end

return {
	serve = serve,
	stop = stop,
}
