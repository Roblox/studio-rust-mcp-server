local Main = script:FindFirstAncestor("MCPStudioPlugin")
local BridgeHandlerServer = require(Main.App.RemoteHandlers.BridgeHandlerServer)
local ClientDMBridgeHandler = require(Main.App.RemoteHandlers.ClientDMBridgeHandler)

return function(plugin: Plugin)
	-- BridgeHandlerServer.serve("Client", ClientDMBridgeHandler.handlers)
	-- plugin.Unloading:Connect(function()
	-- 	BridgeHandlerServer.stop()
	-- end)
end
