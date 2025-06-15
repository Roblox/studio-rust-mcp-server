-- GetLightingProperty.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local Lighting = game:GetService("Lighting")

local function execute(args)
    local success, result = pcall(function()
        local propertyName = args.property_name

        if not propertyName or type(propertyName) ~= "string" then
            return ToolHelpers.FormatErrorResult("'property_name' is required and must be a string.")
        end

        local getSuccess, propertyValueOrError = pcall(function()
            return Lighting[propertyName]
        end)

        if not getSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to get Lighting property '%s': %s"):format(propertyName, tostring(propertyValueOrError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully retrieved Lighting property '%s'."):format(propertyName),
            property_name = propertyName,
            value = ToolHelpers.RobloxValueToJson(propertyValueOrError)
        })
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in GetLightingProperty: " .. tostring(result))
    end
end

return execute
