--[[
	MCPServerCodeRunner - Server-side code execution for MCP testing

	This script enables Claude/MCP to execute Luau code in the SERVER context during playtest.
	Unlike run_code (which runs in the plugin context), this runs where ServerScriptService
	scripts execute, giving access to server-side state like _G values, DataStores, etc.

	SETUP:
	1. Copy this script into ServerScriptService in your Roblox game
	2. Enable HttpService: Game Settings > Security > Allow HTTP Requests
	3. The script will automatically poll the MCP server for code to execute
	4. Use the run_server_code MCP tool to execute code

	BUILT-IN COMMANDS (work without loadstring):
	- "STOP" - Stops the playtest (calls StudioTestService:EndTest)
	- "PING" - Returns "pong" to verify the script is running
	- "PLAYERS" - Returns list of current players

	ARBITRARY CODE EXECUTION (requires LoadStringEnabled):
	If you need to run arbitrary Luau code, you must enable loadstring:
	1. In Explorer, click ServerScriptService
	2. In Properties panel, find "LoadStringEnabled"
	3. Check the checkbox to enable it
	Note: This makes the game more vulnerable to exploits (only use in development)

	SECURITY NOTE:
	This script should ONLY be used during local development and testing.
	Do NOT include this in published games.

	EXAMPLE USAGE (from Claude/MCP):
	run_server_code({ code = "STOP" })  -- Built-in: stops playtest
	run_server_code({ code = "PING" })  -- Built-in: returns "pong"
	run_server_code({ code = "PLAYERS" })  -- Built-in: lists players
	run_server_code({ code = "return _G.GameState" })  -- Requires LoadStringEnabled
]]

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Configuration
local MCP_SERVER_URL = "http://localhost:44755"
local POLL_INTERVAL = 0.5 -- Poll every 500ms (avoid rate limiting)
local DEBUG_MODE = true -- Set to false to reduce output

local function log(...)
	if DEBUG_MODE then
		print("[MCPServerCodeRunner]", ...)
	end
end

local function warn_log(...)
	warn("[MCPServerCodeRunner]", ...)
end

-- Check if loadstring is available
local loadstringEnabled = false
pcall(function()
	local test = loadstring("return true")
	if test and test() then
		loadstringEnabled = true
	end
end)

-- Built-in commands that work without loadstring
local builtInCommands = {
	["STOP"] = function()
		local StudioTestService = game:GetService("StudioTestService")
		StudioTestService:EndTest("Stopped via MCP")
		return true, "Playtest stopped"
	end,

	["PING"] = function()
		return true, "pong"
	end,

	["PLAYERS"] = function()
		local count = #Players:GetPlayers()
		local names = {}
		for _, p in Players:GetPlayers() do
			table.insert(names, p.Name)
		end
		return true, "Players: " .. count .. " - " .. table.concat(names, ", ")
	end,

	["STATE"] = function()
		return true, HttpService:JSONEncode({
			isServer = RunService:IsServer(),
			isRunning = RunService:IsRunning(),
			loadstringEnabled = loadstringEnabled,
			playerCount = #Players:GetPlayers(),
		})
	end,
}

-- Poll for pending server code commands
local function pollForCode()
	local success, response = pcall(function()
		return HttpService:GetAsync(MCP_SERVER_URL .. "/mcp/server_code")
	end)

	if not success then
		-- Silently fail - MCP server may not be running
		return nil
	end

	local data = HttpService:JSONDecode(response)
	return data.commands
end

-- Execute code and return result
local function executeCode(code: string): (boolean, string?)
	-- Check for built-in commands first (case-insensitive)
	local upperCode = string.upper(string.match(code, "^%s*(.-)%s*$") or "")
	if builtInCommands[upperCode] then
		return builtInCommands[upperCode]()
	end

	-- Try loadstring for arbitrary code
	if not loadstringEnabled then
		return false, "loadstring not enabled. Use built-in commands (STOP, PING, PLAYERS, STATE) or enable LoadStringEnabled in ServerScriptService Properties panel."
	end

	-- Wrap code to capture return value
	local wrappedCode = [[
		local __result = (function()
			]] .. code .. [[
		end)()
		return __result
	]]

	local func, compileError = loadstring(wrappedCode)
	if not func then
		return false, "Compile error: " .. tostring(compileError)
	end

	-- Set environment to allow access to game globals
	setfenv(func, setmetatable({}, {
		__index = function(_, key)
			-- Allow access to common globals
			return _G[key] or getfenv(0)[key]
		end,
		__newindex = function(_, key, value)
			_G[key] = value
		end
	}))

	local success, result = pcall(func)
	if not success then
		return false, "Runtime error: " .. tostring(result)
	end

	-- Convert result to string for return
	local resultStr
	if result == nil then
		resultStr = "nil"
	elseif type(result) == "table" then
		-- Try to encode as JSON, fall back to tostring
		local encodeSuccess, encoded = pcall(function()
			return HttpService:JSONEncode(result)
		end)
		if encodeSuccess then
			resultStr = encoded
		else
			resultStr = tostring(result)
		end
	else
		resultStr = tostring(result)
	end

	return true, resultStr
end

-- Send result back to MCP server
local function sendResult(id: string, success: boolean, result: string?, error: string?)
	local payload = HttpService:JSONEncode({
		id = id,
		success = success,
		result = result,
		error = error,
	})

	local httpSuccess, httpError = pcall(function()
		HttpService:PostAsync(
			MCP_SERVER_URL .. "/mcp/server_code",
			payload,
			Enum.HttpContentType.ApplicationJson
		)
	end)

	if not httpSuccess then
		warn_log("Failed to send result:", httpError)
	end
end

-- Process a single code command
local function processCommand(command)
	log("Executing code (id: " .. command.id .. "):")
	if DEBUG_MODE then
		print("---")
		print(command.code)
		print("---")
	end

	local success, result = executeCode(command.code)

	if success then
		log("Success:", result)
		sendResult(command.id, true, result, nil)
	else
		warn_log("Error:", result)
		sendResult(command.id, false, nil, result)
	end
end

-- Main polling loop
local function startPolling()
	log("Started - polling", MCP_SERVER_URL, "for server code commands")
	log("Server context: RunService:IsServer() =", RunService:IsServer())
	log("loadstring enabled:", loadstringEnabled)
	log("Built-in commands: STOP, PING, PLAYERS, STATE")

	while true do
		local commands = pollForCode()

		if commands and #commands > 0 then
			for _, command in ipairs(commands) do
				processCommand(command)
			end
		end

		task.wait(POLL_INTERVAL)
	end
end

-- Only run on server
if RunService:IsServer() then
	-- Delay slightly to let other scripts initialize first
	task.delay(0.5, startPolling)
else
	warn_log("This script must run on the server (ServerScriptService)")
end
