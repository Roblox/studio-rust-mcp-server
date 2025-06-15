-- SetInstanceProperties.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)

local function execute(args)
    local success, result = pcall(function()
        local path = args.path
        local propertiesToSet = args.properties

        if not path or type(path) ~= "string" then
            return ToolHelpers.FormatErrorResult("'path' is required and must be a string.")
        end
        if not propertiesToSet or type(propertiesToSet) ~= "table" then
            return ToolHelpers.FormatErrorResult("'properties' is required and must be a table.")
        end

        local instance, err = ToolHelpers.FindInstanceByPath(path)
        if not instance then
            return ToolHelpers.FormatErrorResult("Failed to find instance at path: " .. path .. ". " .. (err or ""))
        end

        local appliedProperties = {}
        local failedProperties = {}

        for propName, propValueJson in pairs(propertiesToSet) do
            local convertedValue = ToolHelpers.JsonToRobloxValue(propValueJson)
            local setSuccess, setError = pcall(function()
                instance[propName] = convertedValue
            end)

            if setSuccess then
                table.insert(appliedProperties, propName)
            else
                table.insert(failedProperties, {name = propName, error = tostring(setError)})
                print(("SetInstanceProperties: Error setting property '%s' on instance '%s': %s"):format(propName, path, setError))
            end
        end

        if #failedProperties > 0 then
            local summaryMessage = ("Partially set properties for %s. Applied: %s. Failed: %s"):format(
                path,
                table.concat(appliedProperties, ", "),
                ToolHelpers.SafeJsonEncode(failedProperties) or "encoding_failed"
            )
            -- Decide if partial success is an error or success with details
            return ToolHelpers.FormatSuccessResult({
                message = summaryMessage,
                applied = appliedProperties,
                failed = failedProperties
            })
        else
            return ToolHelpers.FormatSuccessResult({
                message = ("Successfully set %d properties for instance %s."):format(#appliedProperties, path),
                applied_properties = appliedProperties
            })
        end
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in SetInstanceProperties: " .. tostring(result))
    end
end

return execute
