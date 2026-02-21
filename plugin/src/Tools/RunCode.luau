local Main = script:FindFirstAncestor("MCPStudioPlugin")

local DataModelStatusMonitor = require(Main.Utils.DataModelStatusMonitor)
local EventBridgePing = require(Main.Utils.EventBridgePing)
local RunCodeImpl = require(Main.ToolsImpl.RunCodeImpl)
local Types = require(Main.Types)

local function handleRunCode(runCodeArgs: Types.RunCodeArgs): string?
	if type(runCodeArgs.command) ~= "string" then
		error("Missing command in RunCode")
	end

	if DataModelStatusMonitor.getDataModelStatus("Server") then
		return EventBridgePing.callFunctionWithPing("Server", 2, "RunCodePlayDM", runCodeArgs)
	end

	return RunCodeImpl(runCodeArgs)
end

return handleRunCode :: Types.ToolFunction
