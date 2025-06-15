-- FindFirstChildMatching.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)

local function execute(args)
    local success, pcall_result = pcall(function()
        local parentPath = args.parent_path
        local childName = args.child_name
        local recursive = args.recursive or false -- Default to false (immediate children)

        if not parentPath or type(parentPath) ~= "string" or parentPath == "" then
            return ToolHelpers.FormatErrorResult("'parent_path' is required and must be a non-empty string.")
        end
        if not childName or type(childName) ~= "string" or childName == "" then
            return ToolHelpers.FormatErrorResult("'child_name' is required and must be a non-empty string.")
        end
        if type(recursive) ~= "boolean" then
            return ToolHelpers.FormatErrorResult("'recursive' must be a boolean if provided.")
        end

        local parentInstance, err = ToolHelpers.FindInstanceByPath(parentPath)
        if not parentInstance then
            return ToolHelpers.FormatErrorResult(("Parent instance not found at path: %s. %s"):format(parentPath, err or ""))
        end

        local foundChild = parentInstance:FindFirstChild(childName, recursive)

        if foundChild then
            return ToolHelpers.FormatSuccessResult({
                message = ("Found child '%s' under %s (recursive: %s)."):format(childName, parentPath, tostring(recursive)),
                parent_path = parentPath,
                child_name_searched = childName,
                recursive_search = recursive,
                found_child_path = foundChild:GetFullName(),
                found_child_type = foundChild:GetClass()
            })
        else
            return ToolHelpers.FormatSuccessResult({
                message = ("Child '%s' not found under %s (recursive: %s)."):format(childName, parentPath, tostring(recursive)),
                parent_path = parentPath,
                child_name_searched = childName,
                recursive_search = recursive,
                found_child_path = nil
            })
        end
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in FindFirstChildMatching: " .. tostring(pcall_result))
    end
end

return execute
