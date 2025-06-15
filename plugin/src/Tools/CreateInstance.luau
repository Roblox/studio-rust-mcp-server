-- CreateInstance.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)

local function execute(args)
    local success, result = pcall(function()
        local className = args.class_name
        local properties = args.properties

        if not className or type(className) ~= "string" then
            return ToolHelpers.FormatErrorResult("'class_name' is required and must be a string.")
        end
        if not properties or type(properties) ~= "table" then
            return ToolHelpers.FormatErrorResult("'properties' is required and must be a table.")
        end

        local newInstance = Instance.new(className)

        for propName, propValueJson in pairs(properties) do
            if string.lower(propName) == "parent" then
                if type(propValueJson) == "string" then
                    local parentInstance, err = ToolHelpers.FindInstanceByPath(propValueJson)
                    if parentInstance then
                        newInstance.Parent = parentInstance
                    else
                        -- Log warning or decide if this should be an error
                        print("CreateInstance: Could not find parent at path: " .. propValueJson .. " Error: " .. (err or "Unknown"))
                        -- Optionally return error: return ToolHelpers.FormatErrorResult("Failed to set parent: " .. propValueJson .. ". " .. (err or ""))
                    end
                else
                     print("CreateInstance: Parent property value must be a string path. Got: " .. type(propValueJson))
                end
            else
                local convertedValue = ToolHelpers.JsonToRobloxValue(propValueJson)
                local setSuccess, setError = pcall(function()
                    newInstance[propName] = convertedValue
                end)
                if not setSuccess then
                    print("CreateInstance: Error setting property '" .. propName .. "' on new " .. className .. ": " .. setError)
                    -- Decide if one failed property should halt the whole operation or just be skipped
                    -- For now, we'll let it continue and attempt to set other properties
                end
            end
        end

        return ToolHelpers.FormatSuccessResult({
            path = newInstance:GetFullName(),
            message = ("Successfully created %s instance named '%s' with path %s"):format(className, newInstance.Name, newInstance:GetFullName())
        })
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in CreateInstance: " .. tostring(result))
    end
end

return execute
