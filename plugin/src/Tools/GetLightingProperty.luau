-- GetLightingProperty.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local Lighting = ToolHelpers.GetLightingService()

local function execute(args: Types.GetLightingPropertyArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local propertyName = args.property_name

        if not propertyName or type(propertyName) ~= "string" then
            return "'property_name' is required and must be a string."
        end

        local propertyValue
        local getSuccess, valueOrError = pcall(function()
            return Lighting[propertyName]
        end)

        if not getSuccess then
            if string.find(tostring(valueOrError), "is not a valid member of Lighting") then
                 return ("Property '%s' is not a valid member of Lighting."):format(propertyName)
            end
            return ("Failed to get Lighting property '%s': %s"):format(propertyName, tostring(valueOrError))
        end
        propertyValue = valueOrError

        local resultData: Types.GetLightingPropertyResultData = {
            property_name = propertyName,
            value = propertyValue, -- Raw Roblox value
        }
        return resultData
    end)

    if success then
		if type(resultOrError) == "string" then -- An error message string was returned
            return ToolHelpers.FormatErrorResult(resultOrError)
		elseif resultOrError == nil then
			return ToolHelpers.FormatErrorResult("GetLightingProperty returned nil unexpectedly.")
		else -- A resultData table was returned
            return ToolHelpers.FormatSuccessResult(resultOrError)
        end
    else
		-- pcall itself failed
        return ToolHelpers.FormatErrorResult("Internal error in GetLightingProperty: " .. tostring(resultOrError))
    end
end

return execute
