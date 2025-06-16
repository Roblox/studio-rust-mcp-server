-- GetProperties.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added

-- This function is now standardized like GetInstanceProperties
local function execute(args: Types.GetPropertiesArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local path = args.path
        local propertyNames = args.property_names

        if not path or type(path) ~= "string" then
            return "'path' is required and must be a string."
        end

        if type(propertyNames) ~= "table" then
            if type(propertyNames) == "string" then -- Allow single string for convenience
                propertyNames = { propertyNames }
            else
                return "'property_names' must be an array of strings or a single string."
            end
        end

        for i, propName in ipairs(propertyNames) do
            if type(propName) ~= "string" then
                return ("All 'property_names' must be strings. Found entry at index %d with type: %s"):format(i, type(propName))
            end
        end

        local instance, err = ToolHelpers.FindInstanceByPath(path) -- Standardized path finding
        if not instance then
            return ("Failed to find instance at path: %s. %s"):format(path, err or "Unknown error")
        end

        local retrievedProperties: {[string]: any} = {}
        local accessErrors: {Types.PropertyAccessError} = {}

        for _, propNameString in ipairs(propertyNames) do
            local getSuccess, propValue = pcall(function()
                return instance[propNameString]
            end)

            if getSuccess then
                retrievedProperties[propNameString] = propValue -- Store raw Roblox value
            else
                table.insert(accessErrors, {name = propNameString, error = tostring(propValue)}) -- propValue is error msg
            end
        end

        local resultData: Types.GetPropertiesResultData = {
            instance_path = path,
            properties = retrievedProperties,
        }
        if #accessErrors > 0 then
            resultData.errors = accessErrors
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
        return ToolHelpers.FormatErrorResult("Internal error in GetProperties: " .. tostring(resultOrError))
    end
end

return execute
