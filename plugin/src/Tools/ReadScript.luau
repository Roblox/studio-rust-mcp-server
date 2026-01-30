local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local ScriptEditorService = game:GetService("ScriptEditorService")

type ReadScriptArgs = {
	path: string,
}

local function navigateToScript(path: string): (LuaSourceContainer?, string?)
	local parts = string.split(path, ".")
	if #parts < 2 then
		return nil, "Path must include at least a service and script name (e.g., 'ServerScriptService.MyScript')"
	end

	-- Get the root service/container
	local rootName = parts[1]
	local current: Instance? = game:FindFirstChild(rootName)
	if not current then
		return nil, "Service or container not found: " .. rootName
	end

	-- Navigate to the script
	for i = 2, #parts do
		local childName = parts[i]
		local child = current:FindFirstChild(childName)

		if not child then
			return nil, "Path segment not found: " .. childName .. " in " .. current:GetFullName()
		end

		current = child
	end

	-- Verify it's a script
	if not current:IsA("LuaSourceContainer") then
		return nil, "Object at path is not a script: " .. current.ClassName
	end

	return current :: LuaSourceContainer, nil
end

local function handleReadScript(args: Types.ToolArgs): string?
	if not args["ReadScript"] then
		return nil
	end

	local readArgs: ReadScriptArgs = args["ReadScript"]

	-- Validate required parameters
	if type(readArgs.path) ~= "string" or readArgs.path == "" then
		return "[ERROR] Missing or empty path parameter"
	end

	-- Find the script
	local scriptInstance, err = navigateToScript(readArgs.path)
	if err then
		return "[ERROR] " .. err
	end

	-- Read the source code using ScriptEditorService
	local success, source = pcall(function()
		return ScriptEditorService:GetEditorSource(scriptInstance)
	end)

	if not success then
		return "[ERROR] Failed to read script source: " .. tostring(source)
	end

	-- Return the source with metadata header
	return string.format(
		"[SUCCESS] %s at %s (%d characters, %d lines)\n\n%s",
		scriptInstance.ClassName,
		readArgs.path,
		#source,
		select(2, source:gsub("\n", "\n")) + 1,
		source
	)
end

return handleReadScript :: Types.ToolFunction
