local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ConnectionManager = require(Main.Utils.ConnectionManager)
local EventBridge = require(Main.Utils.EventBridge)
local runCodeWithOutput = require(Main.Utils.runCodeWithOutput)

local function initToolCallHandler()
	EventBridge.registerFunction("RunCode", function(command: string)
		-- return runCodeWithOutput(command)
		print("Running code:", command)
		return "Code run successfully"
	end)
end

local function start()
	ConnectionManager.initEventBridge("Server")
	ConnectionManager.startWebSocket()
end

-- local function stop()
-- 	ConnectionManager.stopWebSocket()
-- end

start()
initToolCallHandler()

return {}
