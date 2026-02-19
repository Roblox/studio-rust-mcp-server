local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

export type GlobalVariables = {
	studioMode: Types.StartStopPlayMode,
}

local GlobalVariables = {
	studioMode = "stop",
}

return GlobalVariables
