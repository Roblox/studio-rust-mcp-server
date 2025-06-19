-- CallInstanceMethod.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local HttpService = game:GetService("HttpService") -- Added

local function execute(args: Types.CallInstanceMethodArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local path = args.path
        local methodName = args.method_name
        local methodArguments = args.arguments -- Expecting an array of Luau values

        if not path or type(path) ~= "string" then
            return "'path' is required and must be a string."
        end
        if not methodName or type(methodName) ~= "string" then
            return "'method_name' is required and must be a string."
        end
        if not methodArguments or type(methodArguments) ~= "table" then -- Check if it's a table (array)
            return "'arguments' is required and must be an array (can be empty)."
        end

        local instance, err = ToolHelpers.FindInstanceByPath(path)
        if not instance then
            return ("Failed to find instance at path: %s. %s"):format(path, err or "Unknown error")
        end

        if type(instance[methodName]) ~= "function" then
            return ("Method '%s' not found or is not a function on instance %s (type is %s)."):format(methodName, path, type(instance[methodName]))
        end

        local processedMethodArguments = {}
        for i, argInput in ipairs(methodArguments) do
            if type(argInput) == "table" then
                -- Pass instance context, which might be useful for some conversions if ConvertTableToRobloxType uses it.
                -- PropertyName hint is generic here.
                local convertedArg, convErr = ToolHelpers.ConvertTableToRobloxType(argInput, "methodArgument" .. tostring(i), instance)
                if convErr then
                    return ("Error converting argument #%d for method '%s': %s. Original table: %s"):format(
                        i,
                        methodName,
                        convErr,
                        HttpService:JSONEncode(argInput)
                    ) -- Return error string directly
                end
                table.insert(processedMethodArguments, convertedArg)
            else
                table.insert(processedMethodArguments, argInput)
            end
        end

        -- The 'convertedArguments' variable is no longer needed as we use processedMethodArguments directly.
        local callSuccess, resultsPack = pcall(function()
            -- Use processedMethodArguments for unpack
            return table.pack(instance[methodName](instance, unpack(processedMethodArguments, 1, #processedMethodArguments)))
        end)

        if not callSuccess then
            return ("Error calling method '%s' on instance '%s': %s"):format(methodName, path, tostring(resultsPack))
        end

        local resultsProcessed: {any} = {}
        if resultsPack and resultsPack.n > 0 then
            for i = 1, resultsPack.n do
                table.insert(resultsProcessed, resultsPack[i]) -- Store raw Roblox values
            end
        end

        local returnMessage
        if resultsPack and resultsPack.n > 0 then
            returnMessage = ("Successfully called method '%s' on instance %s. Method returned %d value(s)."):format(methodName, path, resultsPack.n)
        else
            returnMessage = ("Successfully called method '%s' on instance %s. Method returned no values."):format(methodName, path)
        end

        local resultData: Types.CallInstanceMethodResultData = {
            message = returnMessage,
            results = resultsProcessed,
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
        return ToolHelpers.FormatErrorResult("Internal error in CallInstanceMethod: " .. tostring(resultOrError))
    end
end

return execute
