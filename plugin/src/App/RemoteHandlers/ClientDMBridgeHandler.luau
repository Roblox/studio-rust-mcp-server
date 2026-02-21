local Main = script:FindFirstAncestor("MCPStudioPlugin")

local handlers = {
	["RunCodePlayDM"] = require(Main.ToolsImpl.RunCodePlayDMImpl),
}

return {
	handlers = handlers,
}
