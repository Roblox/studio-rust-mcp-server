local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ConsoleOutput = require(Main.Utils.ConsoleOutput)
local GlobalVariables = require(Main.Utils.GlobalVariables)
local Types = require(Main.Types)

local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local StudioTestService = game:GetService("StudioTestService")

local TEST_SCRIPT_NAME = "AssistantTestScript"

local function buildTestRunnerSource(userCode: string, timeout: number): string
	local timeoutStr = tostring(timeout)
	return [[
local StudioTestService = game:GetService("StudioTestService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

if not RunService:IsRunning() then
	return
end

local capturedLogs = {}
local logConnection = nil

local MESSAGE_TYPE_MAP = {
	[Enum.MessageType.MessageOutput] = "output",
	[Enum.MessageType.MessageInfo] = "info",
	[Enum.MessageType.MessageWarning] = "warning",
	[Enum.MessageType.MessageError] = "error",
}

logConnection = LogService.MessageOut:Connect(function(message, messageType)
	if string.sub(message, 1, 5) == "[MCP]" then return end
	table.insert(capturedLogs, {
		level = MESSAGE_TYPE_MAP[messageType] or "output",
		message = message,
		ts = os.clock(),
	})
end)

local startTime = os.clock()
local isTimeout = false

local function endTest()
	local duration = os.clock() - startTime
	task.wait(0.1)

	if logConnection then logConnection:Disconnect() end

	local errors = {}
	for _, log in ipairs(capturedLogs) do
		if log.level == "error" or log.level == "warning" then
			table.insert(errors, log)
		end
	end

	StudioTestService:EndTest({
		success = ok,
		value = if ok then tostring(result) else nil,
		error = if not ok then tostring(result) else nil,
		logs = capturedLogs,
		errors = errors,
		duration = duration,
		isTimeout = isTimeout,
	})
end


task.spawn(function()
	wait(]] .. timeoutStr .. [[)
	isTimeout = true
	endTest()
end)

local ok, result = pcall(function()
]] .. userCode .. [[

end)

endTest()
]]
end

local function removeTestScript()
	local testScript = ServerScriptService:FindFirstChild(TEST_SCRIPT_NAME)
	if testScript then
		testScript:Destroy()
	end
end

local function injectTestScript(args: Types.RunScriptInPlayModeArgs)
	removeTestScript()

	local source = buildTestRunnerSource(args.code, args.timeout or 1_000_000)
	local testScript = Instance.new("Script")
	testScript.Name = TEST_SCRIPT_NAME
	testScript.Parent = ServerScriptService
	testScript.Source = source
end

local function runScriptInPlayMode(args: Types.RunScriptInPlayModeArgs): string?
	injectTestScript(args)

	ConsoleOutput.outputMessage = ""
	local success, result = pcall(function()
		if args.mode == "start_play" then
			GlobalVariables.studioMode = "start_play"
			return StudioTestService:ExecutePlayModeAsync({})
		else
			GlobalVariables.studioMode = "run_server"
			return StudioTestService:ExecuteRunModeAsync({})
		end
	end)

	GlobalVariables.studioMode = "stop"
	removeTestScript()

	if not success then
		return "Failed to run script in play mode: " .. result
	end

	local resultStr = HttpService:JSONEncode(result)
	return resultStr
end

local function handleRunScriptInPlayMode(args: Types.ToolArgs): string?
	if not args["RunScriptInPlayMode"] then
		return nil
	end

	local runScriptInPlayModeArgs: Types.RunScriptInPlayModeArgs = args["RunScriptInPlayMode"]
	if type(runScriptInPlayModeArgs.code) ~= "string" or runScriptInPlayModeArgs.code == "" then
		error("Missing code in RunScriptInPlayMode")
	end

	if runScriptInPlayModeArgs.timeout ~= nil then
		if type(runScriptInPlayModeArgs.timeout) ~= "number" or runScriptInPlayModeArgs.timeout < 0 then
			error("Timeout must be a number greater than 0 in RunScriptInPlayMode")
		end
	end

	return runScriptInPlayMode(runScriptInPlayModeArgs)
end

return handleRunScriptInPlayMode :: Types.ToolFunction
