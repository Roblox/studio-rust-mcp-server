-- SetLightingProperty.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local function execute(args: Types.SetLightingPropertyArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local propertyName = args.property_name
        local propertyValueInput = args.value

        if not propertyName or type(propertyName) ~= "string" then
            return "'property_name' is required and must be a string."
        end
        if propertyValueInput == nil then
            return "'value' is required for the property."
        end

        local finalValueToSet = propertyValueInput
        local conversionErrorMsg = nil

        if type(propertyValueInput) == "table" then
            local converted_value_from_helper, err_msg_from_helper = ToolHelpers.ConvertTableToRobloxType(propertyValueInput, propertyName, Lighting)
            if err_msg_from_helper then
                conversionErrorMsg = err_msg_from_helper
            else
                finalValueToSet = converted_value_from_helper
            end
        end

        if conversionErrorMsg then
            return ("Conversion error for Lighting property '%s': %s. Original value was: %s"):format(
                propertyName,
                conversionErrorMsg,
                HttpService:JSONEncode(propertyValueInput) -- Using JSONEncode for a clearer table representation in error
            )
        end

        local setSuccess, setError = pcall(function()
            Lighting[propertyName] = finalValueToSet
        end)

        if not setSuccess then
            local originalValueStr = HttpService:JSONEncode(propertyValueInput)
            local attemptedValueStr = HttpService:JSONEncode(finalValueToSet)
            local errorDetail = tostring(setError)
            if string.find(errorDetail, "not a valid member") or string.find(errorDetail, "cannot be assigned to") then
                 return ("Property '%s' on Lighting is not settable or does not exist. Error: %s. Original: %s, Attempted: %s"):format(
                    propertyName,
                    errorDetail,
                    originalValueStr,
                    attemptedValueStr
                 )
            end
            return ("Failed to set Lighting property '%s': %s. Original: %s, Attempted: %s"):format(
                propertyName,
                errorDetail,
                originalValueStr,
                attemptedValueStr
            )
        end

        local actualValue = Lighting[propertyName]
        local resultData: Types.SetLightingPropertyResultData = {
            property_name = propertyName,
            new_value_set = actualValue,
            original_value_sent = propertyValueInput, -- Include original value for clarity
            value_after_conversion = finalValueToSet -- Include value after conversion
        }
        return resultData
    end)

    if success then
        if type(resultOrError) == "string" then
            return ToolHelpers.FormatErrorResult(resultOrError)
        else
            return ToolHelpers.FormatSuccessResult(resultOrError)
        end
    else
        return ToolHelpers.FormatErrorResult("Internal error in SetLightingProperty: " .. tostring(resultOrError))
    end
end

return execute
