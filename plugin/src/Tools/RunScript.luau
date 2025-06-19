-- RunScript.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)

local function execute(args: Types.CreateScriptArgs)
    -- Arguments are expected directly on args table
    local success, pcall_result = pcall(function()
        local parentPath = args.parent_path
        local scriptSource = args.script_source
        local scriptName = args.script_name
        local scriptType = args.script_type -- "Script" or "LocalScript"
        local initiallyDisabled = args.initially_disabled -- Optional, defaults to false

        if not parentPath or type(parentPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'parent_path' is required and must be a string.")
        end
        if scriptSource == nil or type(scriptSource) ~= "string" then -- script_source can be empty string
            return ToolHelpers.FormatErrorResult("'script_source' is required and must be a string.")
        end
        if not scriptName or type(scriptName) ~= "string" or scriptName == "" then
            return ToolHelpers.FormatErrorResult("'script_name' is required and must be a non-empty string.")
        end
        if scriptType ~= "Script" and scriptType ~= "LocalScript" and scriptType ~= "ModuleScript" then
            return ToolHelpers.FormatErrorResult("'script_type' must be 'Script', 'LocalScript', or 'ModuleScript'.")
        end
        if initiallyDisabled ~= nil and type(initiallyDisabled) ~= "boolean" then
            return ToolHelpers.FormatErrorResult("'initially_disabled' must be a boolean if provided.")
        end
        initiallyDisabled = initiallyDisabled or false -- Default to false


        local parentInstance, err = ToolHelpers.FindInstanceByPath(parentPath)
        if not parentInstance then
            return ToolHelpers.FormatErrorResult("Failed to find parent instance at path: " .. parentPath .. ". " .. (err or ""))
        end

        local scriptInstance
        if scriptType == "Script" then
            scriptInstance = Instance.new("Script")
        elseif scriptType == "LocalScript" then
            scriptInstance = Instance.new("LocalScript")
        elseif scriptType == "ModuleScript" then
            scriptInstance = Instance.new("ModuleScript")
        end
        -- Should not happen due to check above, but as a safeguard:
        if not scriptInstance then
             return ToolHelpers.FormatErrorResult("Internal error: Could not create script instance for type " .. scriptType)
        end


        scriptInstance.Name = scriptName
        scriptInstance.Source = scriptSource
        scriptInstance.Disabled = initiallyDisabled
        scriptInstance.Parent = parentInstance

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully created %s named '%s' under %s. Initially disabled: %s."):format(scriptType, scriptName, parentPath, tostring(initiallyDisabled)),
            script_path = scriptInstance:GetFullName(),
            script_type = scriptType,
            initially_disabled = initiallyDisabled
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in RunScript (CreateScript): " .. tostring(pcall_result))
    end
end

return execute
