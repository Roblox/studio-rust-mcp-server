-- SetLightingProperty.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local Lighting = game:GetService("Lighting")

local function execute(args: Types.SetLightingPropertyArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local propertyName = args.property_name
        local propertyValueJson = args.value

        if not propertyName or type(propertyName) ~= "string" then
            return "'property_name' is required and must be a string."
        end
        if propertyValueJson == nil then
            return "'value' is required for the property."
        end

        local convertedValue, convertError = ToolHelpers.JsonToRobloxValue(propertyValueJson, "Lighting."..propertyName)
        if convertError then
            return ("Invalid value format for Lighting property '%s': %s"):format(propertyName, convertError)
        end

        local setSuccess, setError = pcall(function()
            Lighting[propertyName] = convertedValue
        end)

        if not setSuccess then
            if string.find(tostring(setError), "not a valid member") or string.find(tostring(setError), "cannot be assigned to") then
                 return ("Property '%s' on Lighting is not settable or does not exist. Error: %s"):format(propertyName,tostring(setError))
            end
            return ("Failed to set Lighting property '%s': %s"):format(propertyName, tostring(setError))
        end

        local actualValue = Lighting[propertyName]
        local resultData: Types.SetLightingPropertyResultData = {
            property_name = propertyName,
            new_value_set = actualValue, -- Raw Roblox value
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
