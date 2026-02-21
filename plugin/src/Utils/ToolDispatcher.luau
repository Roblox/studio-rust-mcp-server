local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local tools: { [string]: Types.ToolFunction } = {
	["GetConsoleOutput"] = require(Main.Tools.GetConsoleOutput),
	["GetStudioMode"] = require(Main.Tools.GetStudioMode),
	["InsertModel"] = require(Main.Tools.InsertModel),
	["RunCode"] = require(Main.Tools.RunCode),
	["RunScriptInPlayMode"] = require(Main.Tools.RunScriptInPlayMode),
	["StartStopPlay"] = require(Main.Tools.StartStopPlay),
}

local function dispatchTool(toolName: string, args: Types.ToolArgs): string?
	local toolFunction = tools[toolName]
	if not toolFunction then
		error("Tool " .. toolName .. " not found")
	end

	return toolFunction(args)
end

return {
	tools = tools,
	dispatchTool = dispatchTool,
}
