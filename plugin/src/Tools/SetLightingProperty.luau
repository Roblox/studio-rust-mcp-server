-- SetLightingProperty.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local Lighting = game:GetService("Lighting")

local function execute(args)
    local success, result = pcall(function()
        local propertyName = args.property_name
        local valueJson = args.value

        if not propertyName or type(propertyName) ~= "string" then
            return ToolHelpers.FormatErrorResult("'property_name' is required and must be a string.")
        end
        if args.value == nil then -- Check for explicit nil for value
            return ToolHelpers.FormatErrorResult("'value' is required.")
        end

        local convertedValue = ToolHelpers.JsonToRobloxValue(valueJson)

        local setSuccess, setError = pcall(function()
            Lighting[propertyName] = convertedValue
        end)

        if not setSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to set Lighting property '%s': %s"):format(propertyName, tostring(setError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully set Lighting property '%s'."):format(propertyName),
            property_name = propertyName,
            new_value = ToolHelpers.RobloxValueToJson(Lighting[propertyName]) -- Confirm by sending back the actual value
        })
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in SetLightingProperty: " .. tostring(result))
    end
end

return execute
