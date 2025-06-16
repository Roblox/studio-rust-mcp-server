-- FindFirstChildMatching.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added

local function execute(args: Types.FindFirstChildMatchingArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local parentPath = args.parent_path
        local childName = args.child_name
        local recursive = args.recursive == nil and false or args.recursive -- Default to false

        if not parentPath or type(parentPath) ~= "string" or parentPath == "" then
            return "'parent_path' is required and must be a non-empty string."
        end
        if not childName or type(childName) ~= "string" or childName == "" then
            return "'child_name' is required and must be a non-empty string."
        end
        if type(recursive) ~= "boolean" then
            return ("'recursive' must be a boolean, got %s"):format(typeof(recursive))
        end

        local parentInstance, err = ToolHelpers.FindInstanceByPath(parentPath)
        if not parentInstance then
            return ("Parent instance not found at path: %s. %s"):format(parentPath, err or "Unknown error")
        end

        local foundChild = parentInstance:FindFirstChild(childName, recursive)

        local resultData: Types.FindFirstChildMatchingResultData
        if foundChild then
            resultData = {
                message = ("Found child '%s' under %s (recursive: %s)."):format(childName, parentPath, tostring(recursive)),
                parent_path = parentPath,
                child_name_searched = childName,
                recursive_search = recursive,
                found_child_path = foundChild:GetFullName(),
                found_child_class_name = foundChild.ClassName,
            }
        else
            resultData = {
                message = ("Child '%s' not found under %s (recursive: %s)."):format(childName, parentPath, tostring(recursive)),
                parent_path = parentPath,
                child_name_searched = childName,
                recursive_search = recursive,
                found_child_path = nil, -- Explicitly nil
                found_child_class_name = nil, -- Explicitly nil
            }
        end
        return resultData
    end)

    if success then
        if type(resultOrError) == "string" then
            return ToolHelpers.FormatErrorResult(resultOrError)
        else
            return ToolHelpers.FormatSuccessResult(resultOrError)
        end
    else
        return ToolHelpers.FormatErrorResult("Internal error in FindFirstChildMatching: " .. tostring(resultOrError))
    end
end

return execute
