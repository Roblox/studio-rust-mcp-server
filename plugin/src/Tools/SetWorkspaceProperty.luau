-- SetWorkspaceProperty.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)

local function execute(args)
    local success, result = pcall(function()
        local propertyName = args.property_name
        local valueJson = args.value

        if not propertyName or type(propertyName) ~= "string" then
            return ToolHelpers.FormatErrorResult("'property_name' is required and must be a string.")
        end
        if args.value == nil then
            return ToolHelpers.FormatErrorResult("'value' is required.")
        end

        local convertedValue = ToolHelpers.JsonToRobloxValue(valueJson)

        local setSuccess, setError = pcall(function()
            workspace[propertyName] = convertedValue
        end)

        if not setSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to set Workspace property '%s': %s"):format(propertyName, tostring(setError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully set Workspace property '%s'."):format(propertyName),
            property_name = propertyName,
            new_value = ToolHelpers.RobloxValueToJson(workspace[propertyName])
        })
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in SetWorkspaceProperty: " .. tostring(result))
    end
end

return execute
