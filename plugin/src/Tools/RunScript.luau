-- RunScript.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)

local function execute(args)
    local success, result = pcall(function()
        local parentPath = args.parent_path
        local scriptSource = args.script_source
        local scriptName = args.script_name
        local scriptType = args.script_type -- "Script" or "LocalScript"

        if not parentPath or type(parentPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'parent_path' is required and must be a string.")
        end
        if type(scriptSource) ~= "string" then -- script_source can be empty, but must be string
            return ToolHelpers.FormatErrorResult("'script_source' is required and must be a string.")
        end
        if not scriptName or type(scriptName) ~= "string" then
            return ToolHelpers.FormatErrorResult("'script_name' is required and must be a string.")
        end
        if scriptType ~= "Script" and scriptType ~= "LocalScript" then
            return ToolHelpers.FormatErrorResult("'script_type' must be 'Script' or 'LocalScript'.")
        end

        local parentInstance, err = ToolHelpers.FindInstanceByPath(parentPath)
        if not parentInstance then
            return ToolHelpers.FormatErrorResult("Failed to find parent instance at path: " .. parentPath .. ". " .. (err or ""))
        end

        local scriptInstance
        if scriptType == "Script" then
            scriptInstance = Instance.new("Script")
        elseif scriptType == "LocalScript" then
            scriptInstance = Instance.new("LocalScript")
        end

        scriptInstance.Name = scriptName
        scriptInstance.Source = scriptSource
        scriptInstance.Parent = parentInstance
        -- Consider if script should be initially disabled: scriptInstance.Disabled = true

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully created %s named '%s' under %s."):format(scriptType, scriptName, parentPath),
            script_path = scriptInstance:GetFullName()
        })
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in RunScript: " .. tostring(result))
    end
end

return execute
