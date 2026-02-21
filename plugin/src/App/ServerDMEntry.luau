local Main = script:FindFirstAncestor("MCPStudioPlugin")
local BridgeHandlerServer = require(Main.App.RemoteHandlers.BridgeHandlerServer)
local ServerDMBridgeHandler = require(Main.App.RemoteHandlers.ServerDMBridgeHandler)

return function(plugin: Plugin)
	BridgeHandlerServer.serve("Server", ServerDMBridgeHandler.handlers)
	plugin.Unloading:Connect(function()
		BridgeHandlerServer.stop()
	end)
end
