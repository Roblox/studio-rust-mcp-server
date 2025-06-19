-- SetWorkspaceProperty.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local HttpService = game:GetService("HttpService") -- Added

local function execute(args: Types.SetWorkspacePropertyArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local propertyName = args.property_name
        local propertyValueInput = args.value -- Renamed for clarity

        if not propertyName or type(propertyName) ~= "string" then
            return "'property_name' is required and must be a string."
        end
        if propertyValueInput == nil then
            return "'value' is required for the property."
        end

        local finalValueToSet = propertyValueInput
        local conversionErrorMsg = nil

        if type(propertyValueInput) == "table" then
            -- Pass 'workspace' as the instance for context-aware conversion (e.g. Vector3 vs UDim2 for Size)
            local converted_value_from_helper, err_msg_from_helper = ToolHelpers.ConvertTableToRobloxType(propertyValueInput, propertyName, ToolHelpers.GetWorkspaceService())
            if err_msg_from_helper then
                conversionErrorMsg = err_msg_from_helper
            else
                finalValueToSet = converted_value_from_helper
            end
        end

        if conversionErrorMsg then
            return ("Conversion error for Workspace property '%s': %s. Original value was: %s"):format(
                propertyName,
                conversionErrorMsg,
                HttpService:JSONEncode(propertyValueInput)
            )
        end

        local setSuccess, setError = pcall(function()
            ToolHelpers.GetWorkspaceService()[propertyName] = finalValueToSet
        end)

        if not setSuccess then
            local originalValueStr = HttpService:JSONEncode(propertyValueInput)
            local attemptedValueStr = HttpService:JSONEncode(finalValueToSet)
            local errorDetail = tostring(setError)

            if string.find(errorDetail, "not a valid member") or string.find(errorDetail, "cannot be assigned to") then
                 return ("Property '%s' on Workspace is not settable or does not exist. Error: %s. Original: %s, Attempted: %s"):format(
                    propertyName,
                    errorDetail,
                    originalValueStr,
                    attemptedValueStr
                 )
            end
            return ("Failed to set Workspace property '%s': %s. Original: %s, Attempted: %s"):format(
                propertyName,
                errorDetail,
                originalValueStr,
                attemptedValueStr
            )
        end

        local actualValue = ToolHelpers.GetWorkspaceService()[propertyName]
        local resultData: Types.SetWorkspacePropertyResultData = {
            property_name = propertyName,
            new_value_set = actualValue,
            original_value_sent = propertyValueInput,
            value_after_conversion = finalValueToSet
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
        return ToolHelpers.FormatErrorResult("Internal error in SetWorkspaceProperty: " .. tostring(resultOrError))
    end
end

return execute
