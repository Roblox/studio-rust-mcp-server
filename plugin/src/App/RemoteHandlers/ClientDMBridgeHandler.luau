local Main = script:FindFirstAncestor("MCPStudioPlugin")

local handlers = {
	["RunCode"] = require(Main.ToolsImpl.RunCodeImpl),
}

return {
	handlers = handlers,
}
