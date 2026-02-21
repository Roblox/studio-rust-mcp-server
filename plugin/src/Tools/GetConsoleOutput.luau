local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local ConsoleOutput = require(Main.Utils.ConsoleOutput)

local function handleGetConsoleOutput(_args: Types.ToolArgs): string?
	local result = ConsoleOutput.outputMessage or ""
	return result
end

return handleGetConsoleOutput :: Types.ToolFunction
