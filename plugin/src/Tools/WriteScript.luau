local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local ScriptEditorService = game:GetService("ScriptEditorService")

type WriteScriptArgs = {
	path: string,
	source: string,
	script_type: string?,
}

local SCRIPT_CLASSES = {
	Script = "Script",
	LocalScript = "LocalScript",
	ModuleScript = "ModuleScript",
}

local function navigateToParent(path: string, createIfMissing: boolean): (Instance?, string?)
	local parts = string.split(path, ".")
	if #parts < 2 then
		return nil, "Path must include at least a service and script name"
	end

	local rootName = parts[1]
	local current: Instance? = game:FindFirstChild(rootName)
	if not current then
		return nil, "Service or container not found: " .. rootName
	end

	for i = 2, #parts - 1 do
		local childName = parts[i]
		local child = current:FindFirstChild(childName)

		if not child then
			if createIfMissing then
				local folder = Instance.new("Folder")
				folder.Name = childName
				folder.Parent = current
				child = folder
			else
				return nil, "Path segment not found: " .. childName
			end
		end

		current = child
	end

	return current, nil
end

local function getOrCreateScript(
	path: string,
	scriptType: string,
	createIfMissing: boolean
): (LuaSourceContainer?, string?)
	local parts = string.split(path, ".")
	local scriptName = parts[#parts]

	local parent, err = navigateToParent(path, createIfMissing)
	if err then
		return nil, err
	end

	local existingScript = parent:FindFirstChild(scriptName)

	if existingScript then
		if existingScript:IsA("LuaSourceContainer") then
			return existingScript :: LuaSourceContainer, nil
		else
			return nil, "Object exists at path but is not a script: " .. existingScript.ClassName
		end
	end

	if createIfMissing then
		local className = SCRIPT_CLASSES[scriptType]
		if not className then
			return nil, "Invalid script_type: " .. scriptType
		end

		local newScript = Instance.new(className) :: LuaSourceContainer
		newScript.Name = scriptName
		newScript.Parent = parent
		return newScript, nil
	end

	return nil, "Script not found: " .. scriptName
end

local function writeScriptSource(scriptInstance: LuaSourceContainer, source: string): (boolean, string?)
	local success, result = pcall(function()
		ScriptEditorService:UpdateSourceAsync(scriptInstance, function(_oldSource)
			return source
		end)
	end)

	if success then
		return true, nil
	else
		return false, tostring(result)
	end
end

local function handleWriteScript(args: Types.ToolArgs): string?
	if not args["WriteScript"] then
		return nil
	end

	local writeArgs: WriteScriptArgs = args["WriteScript"]

	if type(writeArgs.path) ~= "string" or writeArgs.path == "" then
		return "[ERROR] Missing or empty script_path parameter"
	end

	if type(writeArgs.source) ~= "string" then
		return "[ERROR] Missing source parameter"
	end

	local scriptType = writeArgs.script_type or "Script"
	local createIfMissing = true

	local scriptInstance, err = getOrCreateScript(writeArgs.path, scriptType, createIfMissing)
	if err then
		return "[ERROR] " .. err
	end

	local success, writeErr = writeScriptSource(scriptInstance, writeArgs.source)
	if not success then
		return "[ERROR] Failed to write script source: " .. (writeErr or "Unknown error")
	end

	return string.format(
		"[SUCCESS] %s %s at %s (%d characters)",
		"Created/Updated",
		scriptInstance.ClassName,
		writeArgs.path,
		#writeArgs.source
	)
end

return handleWriteScript :: Types.ToolFunction
