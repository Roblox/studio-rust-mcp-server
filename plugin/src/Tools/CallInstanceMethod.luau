-- CallInstanceMethod.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)

local function execute(args)
    local success, result = pcall(function()
        local path = args.path
        local methodName = args.method_name
        local methodArgsJson = args.arguments

        if not path or type(path) ~= "string" then
            return ToolHelpers.FormatErrorResult("'path' is required and must be a string.")
        end
        if not methodName or type(methodName) ~= "string" then
            return ToolHelpers.FormatErrorResult("'method_name' is required and must be a string.")
        end
        if not methodArgsJson or type(methodArgsJson) ~= "table" then
            return ToolHelpers.FormatErrorResult("'arguments' is required and must be an array.")
        end

        local instance, err = ToolHelpers.FindInstanceByPath(path)
        if not instance then
            return ToolHelpers.FormatErrorResult("Failed to find instance at path: " .. path .. ". " .. (err or ""))
        end

        if type(instance[methodName]) ~= "function" then
            return ToolHelpers.FormatErrorResult(("Method '%s' not found or is not a function on instance %s."):format(methodName, path))
        end

        local convertedArgs = {}
        for i, argJson in ipairs(methodArgsJson) do
            convertedArgs[i] = ToolHelpers.JsonToRobloxValue(argJson)
        end

        local callSuccess, callResultOrError = pcall(function()
            return {instance[methodName](instance, unpack(convertedArgs, 1, #convertedArgs))}
            -- Wrap result in a table to capture multiple return values
        end)

        if not callSuccess then
            return ToolHelpers.FormatErrorResult(("Error calling method '%s' on instance '%s': %s"):format(methodName, path, tostring(callResultOrError)))
        end

        -- Process results: Convert Roblox values to JSON-friendly format
        local resultsJson = {}
        if callResultOrError then
            for i, retVal in ipairs(callResultOrError) do
                table.insert(resultsJson, ToolHelpers.RobloxValueToJson(retVal))
            end
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully called method '%s' on instance %s."):format(methodName, path),
            results = resultsJson -- Array of returned values, converted to JSON
        })
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in CallInstanceMethod: " .. tostring(result))
    end
end

return execute
