-- CreateTextChannel.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local TextChatService = ToolHelpers.GetTextChatService()
local HttpService = game:GetService("HttpService") -- Added

local function execute(args: Types.CreateTextChannelArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local channelName = args.channel_name
        local propertiesJson = args.properties or {} -- Default to empty table

        if not channelName or type(channelName) ~= "string" or channelName == "" then
            return "'channel_name' is required and must be a non-empty string."
        end
        if type(propertiesJson) ~= "table" then
            return "'properties', if provided, must be a table."
        end

        if not TextChatService then
            return "TextChatService not available."
        end

        local existingChannel = TextChatService:FindFirstChild(channelName)
        if existingChannel and existingChannel:IsA("TextChannel") then
            return ("TextChannel '%s' already exists."):format(channelName)
        end

        local newChannel = Instance.new("TextChannel")
        newChannel.Name = channelName

        local propertyErrors = {}
        for propName, propValueInput in pairs(propertiesJson) do
            if string.lower(propName) == "parent" then
                -- Parent is TextChatService, handled later
            else
                local finalValueToSet = propValueInput
                local conversionErrorMsg = nil

                if type(propValueInput) == "table" then
                    -- Pass newChannel instance for context
                    local converted_value, err_msg = ToolHelpers.ConvertTableToRobloxType(propValueInput, propName, newChannel)
                    if err_msg then
                        conversionErrorMsg = err_msg
                    else
                        finalValueToSet = converted_value
                    end
                end

                if conversionErrorMsg then
                    table.insert(propertyErrors, ("Property '%s': Conversion error: %s. Original: %s"):format(
                        propName,
                        conversionErrorMsg,
                        HttpService:JSONEncode(propValueInput)
                    ))
                else
                    local setSuccess, setError = pcall(function()
                        newChannel[propName] = finalValueToSet
                    end)
                    if not setSuccess then
                        table.insert(propertyErrors, ("Property '%s': Error setting value: %s. Original: %s, Attempted: %s"):format(
                            propName,
                            tostring(setError),
                            HttpService:JSONEncode(propValueInput),
                            HttpService:JSONEncode(finalValueToSet)
                        ))
                    end
                end
            end
        end

        if #propertyErrors > 0 then
            newChannel:Destroy()
            return ("Error(s) applying properties to new TextChannel '%s': %s"):format(channelName, table.concat(propertyErrors, "; "))
        end

        newChannel.Parent = TextChatService

        local resultData: Types.CreateTextChannelResultData = {
            message = ("Successfully created TextChannel '%s'."):format(channelName),
            channel_name = newChannel.Name,
            channel_path = newChannel:GetFullName(),
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
        return ToolHelpers.FormatErrorResult("Internal error in CreateTextChannel: " .. tostring(resultOrError))
    end
end

return execute
