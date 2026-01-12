--[[
	MCPServerCodeRunner - Server-side code execution for MCP testing

	This script enables Claude/MCP to execute Luau code in the SERVER context during playtest.
	Unlike run_code (which runs in the plugin context), this runs where ServerScriptService
	scripts execute, giving access to server-side state like _G values, DataStores, etc.

	SETUP:
	1. Copy this script into ServerScriptService in your Roblox game
	2. The script will automatically poll the MCP server for code to execute
	3. Use the run_server_code MCP tool to execute code

	SECURITY NOTE:
	This script executes arbitrary code. It should ONLY be used during local development
	and testing. Do NOT include this in published games.

	EXAMPLE USAGE (from Claude/MCP):
	run_server_code({ code = "return _G.PlayerDataStore" })
	run_server_code({ code = "return game.Players:GetPlayers()" })
	run_server_code({ code = "print('Hello from server!'); return 'done'" })
]]

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Configuration
local MCP_SERVER_URL = "http://localhost:44755"
local POLL_INTERVAL = 0.1 -- Poll every 100ms for responsive testing
local DEBUG_MODE = true -- Set to false to reduce output

local function log(...)
	if DEBUG_MODE then
		print("[MCPServerCodeRunner]", ...)
	end
end

local function warn_log(...)
	warn("[MCPServerCodeRunner]", ...)
end

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
