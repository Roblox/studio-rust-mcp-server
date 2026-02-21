local Main = script:FindFirstAncestor("MCPStudioPlugin")
local HttpService = game:GetService("HttpService")
local DataModelType = require(Main.Utils.DataModelType)

local Types = require(Main.Types)

local EventType = {
	PRINT = "print",
	WARN = "warn",
	ERROR = "error",
	RETURN = "return",
}

local function createScript(code: string)
	local datamodel = DataModelType.getDataModelType()
	local parent = nil
	local scriptClassName = nil
	if datamodel == "Server" then
		parent = game.Workspace
		scriptClassName = "Script"
	elseif datamodel == "Client" then
		parent = game.Players.LocalPlayer.PlayerScripts
		scriptClassName = "LocalScript"
	end

	local output = ""

	local function getTableType(arg)
		local hasArray = false
		local hasTable = false
		for key, _value in arg do
			if typeof(key) == "number" then
				hasArray = true
			else
				hasTable = true
			end
			if hasArray and hasTable then
				break
			end
		end
		return hasArray, hasTable
	end

	local function deepClone(t, cache)
		local clone = {}
		for key, value in t do
			local newKey = key
			if typeof(key) == "table" then
				if not cache[key] then
					cache[key] = deepClone(key, cache)
				end
				newKey = cache[key]
			end

			local newValue = value
			if typeof(value) == "table" then
				if not cache[value] then
					cache[value] = deepClone(value, cache)
				end
				newValue = cache[value]
			end

			clone[newKey] = newValue
		end
		return clone
	end

	local function serializeTable(arg): any
		if typeof(arg) == "table" then
			local _, isTable = getTableType(arg)

			local newArg = {}
			for key, value in arg do
				local newKey = serializeTable(key)
				newArg[if isTable then tostring(newKey) else newKey] = serializeTable(value)
			end
			return newArg
		elseif type(arg) == "userdata" then
			return tostring(arg) or "UNABLE_TO_SERIALIZE"
		end
		return arg
	end

	local function toStrTable(t: { any }): { string }
		local clonedTable = deepClone(t, {})
		local strTable = table.create(#clonedTable)
		for i, arg in clonedTable do
			local serializedArg = serializeTable(arg)
			strTable[i] = if typeof(serializedArg) == "table"
				then HttpService:JSONEncode(serializedArg)
				else serializedArg
		end
		return strTable
	end

	local function addToOutput(header: string, ...)
		local strResults = toStrTable(table.pack(...))
		output ..= header .. " " .. table.concat(strResults, "\t") .. "\n"
	end

	local FinishEvent = Instance.new("BindableEvent")
	FinishEvent.Name = "RunCodeFinishEvent"

	local BindableEvent = Instance.new("BindableEvent")
	BindableEvent.Name = "RunCodeBindableEvent"
	BindableEvent.Parent = game.ReplicatedStorage

	BindableEvent.Event:Connect(function(eventType, ...)
		if eventType == EventType.PRINT then
			addToOutput("[OUTPUT]", ...)
		elseif eventType == EventType.WARN then
			addToOutput("[WARNING]", ...)
		elseif eventType == EventType.ERROR then
			addToOutput("[ERROR]", ...)
			FinishEvent:Fire()
		elseif eventType == EventType.RETURN then
			addToOutput("[RETURNED RESULTS]", ...)
			FinishEvent:Fire()
		end
	end)

	local injectedCode = [[
local RunCodeBindableEvent = game.ReplicatedStorage:WaitForChild("RunCodeBindableEvent")

local chunkfenv = getfenv()

local oldPrint = print
chunkfenv.print = function(...)
	oldPrint(...)
	RunCodeBindableEvent:Fire("print", ...)
end

local oldWarn = warn
chunkfenv.warn = function(...)
	oldWarn(...)
	RunCodeBindableEvent:Fire("warn", ...)
end

local oldError = error
chunkfenv.error = function(...)
	oldError(...)
	RunCodeBindableEvent:Fire("error", ...)
end

local ok, result = pcall(function()
]] .. code .. [[
end)

if ok then
	RunCodeBindableEvent:Fire("return", result)
else
	RunCodeBindableEvent:Fire("error", result)
end
]]

	local s = Instance.new(scriptClassName) :: Script
	s.Source = injectedCode
	s.Parent = parent

	FinishEvent.Event:Wait()

	s:Destroy()
	FinishEvent:Destroy()
	BindableEvent:Destroy()

	return output
end

local function handleRunCode(runCodeArgs: Types.RunCodeArgs): string?
	return createScript(runCodeArgs.command)
end

return handleRunCode :: Types.ToolFunction
