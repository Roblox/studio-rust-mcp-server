local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local HttpService = game:GetService("HttpService")

local function runCodeWithOutput(command: string): string
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

	local function toStrTable(t: { any }): { string }
		local clonedTable = deepClone(t, {})
		local strTable = table.create(#clonedTable)
		for i, arg in clonedTable do
			local serializedArg = serializeTable(arg)
			if typeof(serializedArg) == "table" then
				strTable[i] = HttpService:JSONEncode(serializedArg)
			elseif typeof(serializedArg) == "boolean" then
				-- Convert booleans to string to avoid concat error
				strTable[i] = tostring(serializedArg)
			else
				strTable[i] = serializedArg
			end
		end
		return strTable
	end

	local function addToOutput(header: string, ...)
		local strResults = toStrTable(table.pack(...))
		output ..= header .. " " .. table.concat(strResults, "\t") .. "\n"
	end

	local function executeCode()
		local chunk = loadstring(command) :: any
		local chunkfenv = getfenv(chunk)

		local oldPrint = print
		chunkfenv.print = function(...)
			oldPrint(...)
			addToOutput("[OUTPUT]", ...)
		end

		local oldWarn = warn
		chunkfenv.warn = function(...)
			oldWarn(...)
			addToOutput("[WARNING]", ...)
		end

		local oldError = error
		chunkfenv.error = function(...)
			oldError(...)
			addToOutput("[ERROR]", ...)
		end

		local results = table.pack(chunk())
		if #results > 0 then
			addToOutput("[RETURNED RESULTS]", table.unpack(results))
		end

		return results
	end

	local ok, errorMessage = pcall(executeCode)
	if not ok then
		addToOutput("[UNEXPECTED ERROR]", errorMessage)
	end

	return output
end

local function handleRunCode(args: Types.ToolArgs): string?
	if not args["RunCode"] then
		return nil
	end

	local runCodeArgs: Types.RunCodeArgs = args["RunCode"]
	if type(runCodeArgs.command) ~= "string" then
		error("Missing command in RunCode")
	end

	return runCodeWithOutput(runCodeArgs.command)
end

return handleRunCode :: Types.ToolFunction
