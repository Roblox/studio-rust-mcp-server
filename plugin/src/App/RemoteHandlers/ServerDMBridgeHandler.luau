local Main = script:FindFirstAncestor("MCPStudioPlugin")

local handlers = {
	["RunCode"] = require(Main.Tools.RunCode),
}

return {
	handlers = handlers,
}
