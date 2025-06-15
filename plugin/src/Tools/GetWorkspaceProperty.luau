-- GetWorkspaceProperty.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)

local function execute(args)
    local success, result = pcall(function()
        local propertyName = args.property_name

        if not propertyName or type(propertyName) ~= "string" then
            return ToolHelpers.FormatErrorResult("'property_name' is required and must be a string.")
        end

        local getSuccess, propertyValueOrError = pcall(function()
            return workspace[propertyName]
        end)

        if not getSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to get Workspace property '%s': %s"):format(propertyName, tostring(propertyValueOrError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully retrieved Workspace property '%s'."):format(propertyName),
            property_name = propertyName,
            value = ToolHelpers.RobloxValueToJson(propertyValueOrError)
        })
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in GetWorkspaceProperty: " .. tostring(result))
    end
end

return execute
