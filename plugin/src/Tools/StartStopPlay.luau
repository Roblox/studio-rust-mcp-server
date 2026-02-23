local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)
local StudioTestService = game:GetService("StudioTestService")
local ConsoleOutput = require(Main.Utils.ConsoleOutput)
local GameStopUtil = require(Main.Utils.GameStopUtil)
local GlobalVariables = require(Main.Utils.GlobalVariables)

-- If callback finishes before timeout, returns callback result, otherwise returns timeoutResult
-- StudioTestService:ExecutePlayModeAsync({}) may error "Previous call to start play session has not been completed" immediately(still yielding) or yield until stop.
local function callWithTimeout(callback: () -> any, timeout: number, timeoutResult: string): string?
	local BindableEvent = Instance.new("BindableEvent")
	local isDone = false
	local _success = true
	local result = timeoutResult
	local isTimeout = false

	task.spawn(function()
		_success, result = pcall(function()
			return callback()
		end)
		if not isDone then
			isDone = true
			BindableEvent:Fire()
		end
	end)
	task.spawn(function()
		task.wait(timeout)
		if not isDone then
			isDone = true
			isTimeout = true
			BindableEvent:Fire()
		end
	end)

	if not isDone then
		BindableEvent.Event:Wait()
	end
	return result, isTimeout
end

local function startPlay(): string?
	ConsoleOutput.outputMessage = ""
	GlobalVariables.studioMode = "start_play"
	local result, isTimeout = callWithTimeout(function()
		return StudioTestService:ExecutePlayModeAsync({})
	end, 0.1, "Started play")
	if not isTimeout then
		return "Already in play mode"
	end
	return result
end

local function stop(): string?
	GameStopUtil.stopPlay()
	GlobalVariables.studioMode = "stop"
	return "Stopped"
end

local function runServer(): string?
	GlobalVariables.studioMode = "run_server"
	local result, isTimeout = callWithTimeout(function()
		return StudioTestService:ExecuteRunModeAsync({})
	end, 0.1, "Ran server")
	if not isTimeout then
		return "Already in server mode"
	end
	return result
end

local function handleStartStopPlay(startStopPlayArgs: Types.StartStopPlayArgs): string?
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

	error("Invalid mode in StartStopPlay, must be start_play, stop, or run_server")
end

return handleStartStopPlay :: Types.ToolFunction
