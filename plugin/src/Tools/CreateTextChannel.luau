-- CreateTextChannel.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local TextChatService = game:GetService("TextChatService")

local function execute(args)
    local success, pcall_result = pcall(function()
        local channelName = args.channel_name
        local propertiesJson = args.properties -- Optional

        if not channelName or type(channelName) ~= "string" or channelName == "" then
            return ToolHelpers.FormatErrorResult("'channel_name' is required and must be a non-empty string.")
        end
        if propertiesJson ~= nil and type(propertiesJson) ~= "table" then
            return ToolHelpers.FormatErrorResult("'properties' must be a table if provided.")
        end

        if not TextChatService then
            return ToolHelpers.FormatErrorResult("TextChatService not available or not enabled.")
        end

        -- Check if channel already exists
        if TextChatService:FindFirstChild(channelName, true) then -- Recursive search
            return ToolHelpers.FormatErrorResult(("TextChannel '%s' already exists."):format(channelName))
        end

        local newChannel = Instance.new("TextChannel")
        newChannel.Name = channelName

        if propertiesJson then
            for propName, propValueJson in pairs(propertiesJson) do
                local convertedValue = ToolHelpers.JsonToRobloxValue(propValueJson)
                -- Add specific type checks if necessary for TextChannel properties
                local setSuccess, setError = pcall(function()
                    newChannel[propName] = convertedValue
                end)
                if not setSuccess then
                    print(("CreateTextChannel: Error setting property '%s' on new TextChannel: %s"):format(propName, setError))
                    -- Potentially accumulate errors or fail early
                end
            end
        end

        newChannel.Parent = TextChatService -- Parent after setting properties

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully created TextChannel '%s'."):format(channelName),
            channel_name = newChannel.Name,
            channel_path = newChannel:GetFullName()
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in CreateTextChannel: " .. tostring(pcall_result))
    end
end

return execute
