-- GetInstanceProperties.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added

local function execute(args: Types.GetInstancePropertiesArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local path = args.path
        local propertyNames = args.property_names

        if not path or type(path) ~= "string" then
            return "'path' is required and must be a string."
        end

        if type(propertyNames) ~= "table" then
            -- Ensure it's an array if only one string is passed (optional convenience)
            if type(propertyNames) == "string" then
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

        local instance, err = ToolHelpers.FindInstanceByPath(path)
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

        local resultData: Types.GetInstancePropertiesResultData = {
            instance_path = path,
            properties = retrievedProperties,
        }
        if #accessErrors > 0 then
            resultData.errors = accessErrors
        end
        return resultData
    end)

    if success then
        if type(resultOrError) == "string" then -- Error string from validation before property access
            return ToolHelpers.FormatErrorResult(resultOrError)
        else -- ResultData table from property access attempt
            return ToolHelpers.FormatSuccessResult(resultOrError)
        end
    else
        return ToolHelpers.FormatErrorResult("Internal error in GetInstanceProperties: " .. tostring(resultOrError))
    end
end

return execute
