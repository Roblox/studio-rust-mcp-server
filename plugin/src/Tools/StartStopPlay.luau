local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)
local StudioTestService = game:GetService("StudioTestService")
local ConsoleOutput = require(Main.Utils.ConsoleOutput)
local GameStopUtil = require(Main.Utils.GameStopUtil)
local GlobalVariables = require(Main.Utils.GlobalVariables)

local function startPlay(): string?
	ConsoleOutput.outputMessage = ""
	GlobalVariables.studioMode = "start_play"
	task.spawn(function()
		StudioTestService:ExecutePlayModeAsync({})
	end)
	return "Started play"
end

local function stop(): string?
	GameStopUtil.stopPlay()
	GlobalVariables.studioMode = "stop"
	return "Stopped"
end

local function runServer(): string?
	GlobalVariables.studioMode = "run_server"
	task.spawn(function()
		StudioTestService:ExecuteRunModeAsync({})
	end)
	return "Ran server"
end

local function handleStartStopPlay(args: Types.ToolArgs): string?
	if not args["StartStopPlay"] then
		return nil
	end

	local startStopPlayArgs: Types.StartStopPlayArgs = args["StartStopPlay"]
	if type(startStopPlayArgs.mode) ~= "string" then
		error("Missing mode in StartStopPlay")
	end

	if startStopPlayArgs.mode == "start_play" then
		return startPlay()
	elseif startStopPlayArgs.mode == "stop" then
		return stop()
	elseif startStopPlayArgs.mode == "run_server" then
		return runServer()
	end

	return "Invalid mode in StartStopPlay, must be start_play, stop, or run_server"
end

return handleStartStopPlay :: Types.ToolFunction
