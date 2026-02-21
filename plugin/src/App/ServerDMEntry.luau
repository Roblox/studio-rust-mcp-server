local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ServerBridgeServer = require(Main.App.RemoteHandlers.ServerBridgeServer)
local ServerDMBridgeHandler = require(Main.App.RemoteHandlers.ServerDMBridgeHandler)

return function(plugin: Plugin)
	ServerBridgeServer.serve("Server", ServerDMBridgeHandler.handlers)
	plugin.Unloading:Connect(function()
		ServerBridgeServer.stop()
	end)
end
