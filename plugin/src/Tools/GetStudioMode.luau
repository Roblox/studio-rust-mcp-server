local Main = script:FindFirstAncestor("MCPStudioPlugin")
local GlobalVariables = require(Main.Utils.GlobalVariables)
local Types = require(Main.Types)

local function handleGetStudioMode(_args: Types.ToolArgs): string?
	local result = GlobalVariables.studioMode
	return result
end

return handleGetStudioMode :: Types.ToolFunction
