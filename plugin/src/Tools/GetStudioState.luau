local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local function getStudioState(): string
	local isEdit = RunService:IsEdit()
	local isRunning = RunService:IsRunning()
	local isRunMode = RunService:IsRunMode()

	local mode = "edit"
	if isRunning then
		if isRunMode then
			-- Run mode (F8) - physics simulation without player character
			mode = "simulation"
		else
			-- Play mode (F5) - playtest with player character
			mode = "playtest"
		end
	end

	local state = {
		mode = mode,
		isEdit = isEdit,
		isRunning = isRunning,
		isRunMode = isRunMode,
		isPlaytest = isRunning and not isRunMode,
		canModify = isEdit and not isRunning,
	}

	return HttpService:JSONEncode(state)
end

local function handleGetStudioState(args: Types.ToolArgs): string?
	if not args["GetStudioState"] then
		return nil
	end

	return getStudioState()
end

return handleGetStudioState :: Types.ToolFunction
