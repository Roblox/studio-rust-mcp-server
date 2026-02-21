local Main = script:FindFirstAncestor("MCPStudioPlugin")
local DataModelType = require(Main.Utils.DataModelType)
local EventBridge = require(Main.Utils.EventBridge)
local Types = require(Main.Types)

local function getServerDMTool()
	local tools: { [string]: Types.ToolFunction } = {
		["RunCode"] = require(Main.Tools.RunCode),
	}
	return tools
end

local function getClientDMTool()
	local tools: { [string]: Types.ToolFunction } = {
		["RunCode"] = require(Main.Tools.RunCode),
	}
	return tools
end

local function getEditDMTool()
	local tools: { [string]: Types.ToolFunction } = {
		["GetConsoleOutput"] = require(Main.Tools.GetConsoleOutput),
		["GetStudioMode"] = require(Main.Tools.GetStudioMode),
		["InsertModel"] = require(Main.Tools.InsertModel),
		["RunScriptInPlayMode"] = require(Main.Tools.RunScriptInPlayMode),
		["StartStopPlay"] = require(Main.Tools.StartStopPlay),
		["RunCode"] = require(Main.Tools.RunCode),
	}
	return tools
end

local remoteDataModelTools = {
	"RunCode",
}

local function dispatchRemoteDataModelTool(
	datamodelType: DataModelType.DataModelType,
	toolName: string,
	args: Types.ToolArgs
): string?
	return EventBridge.callFunction(datamodelType, toolName, args)
end

local function dispatchTool(toolName: string, args: Types.ToolArgs): string?
	local tools = getEditDMTool()
	local toolFunction = tools[toolName]
	if not toolFunction then
		error("Tool " .. toolName .. " not found")
	end

	return toolFunction(args)
end

return {
	getServerDMTool = getServerDMTool,
	getClientDMTool = getClientDMTool,
	getEditDMTool = getEditDMTool,
	dispatchTool = dispatchTool,
}
