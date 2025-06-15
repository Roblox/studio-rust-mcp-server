-- GetInstanceProperties.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)

local function execute(args)
    local success, result = pcall(function()
        local path = args.path
        local propertyNames = args.property_names

        if not path or type(path) ~= "string" then
            return ToolHelpers.FormatErrorResult("'path' is required and must be a string.")
        end
        if not propertyNames or type(propertyNames) ~= "table" or #propertyNames == 0 then
            return ToolHelpers.FormatErrorResult("'property_names' is required and must be a non-empty array of strings.")
        end

        local instance, err = ToolHelpers.FindInstanceByPath(path)
        if not instance then
            return ToolHelpers.FormatErrorResult("Failed to find instance at path: " .. path .. ". " .. (err or ""))
        end

        local retrievedProperties = {}
        local accessErrors = {}

        for _, propName in ipairs(propertyNames) do
            if type(propName) == "string" then
                local getSuccess, propValueOrError = pcall(function()
                    return instance[propName]
                end)

                if getSuccess then
                    retrievedProperties[propName] = ToolHelpers.RobloxValueToJson(propValueOrError)
                else
                    table.insert(accessErrors, {name = propName, error = tostring(propValueOrError)})
                    print(("GetInstanceProperties: Error getting property '%s' from instance '%s': %s"):format(propName, path, propValueOrError))
                end
            else
                table.insert(accessErrors, {name = tostring(propName), error = "Property name is not a string."})
            end
        end

        if #accessErrors > 0 then
             return ToolHelpers.FormatSuccessResult({
                message = "Retrieved some properties with errors.",
                properties = retrievedProperties,
                errors = accessErrors
            })
        else
            return ToolHelpers.FormatSuccessResult({
                message = ("Successfully retrieved %d properties for instance %s."):format(#propertyNames, path),
                properties = retrievedProperties
            })
        end
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in GetInstanceProperties: " .. tostring(result))
    end
end

return execute
