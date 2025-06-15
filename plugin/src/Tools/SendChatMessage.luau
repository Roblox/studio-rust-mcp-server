-- SendChatMessage.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local TextChatService = game:GetService("TextChatService")
local PlayersService = game:GetService("Players")

local function execute(args)
    local success, pcall_result = pcall(function()
        local messageText = args.message_text
        local channelName = args.channel_name -- Optional
        local speakerPath = args.speaker_path -- Optional
        -- targetPlayerPath is removed as per refined description; whispers are simulated by Gemini in message_text

        if messageText == nil or type(messageText) ~= "string" then -- message_text can be empty
            return ToolHelpers.FormatErrorResult("'message_text' is required and must be a string.")
        end
        if channelName ~= nil and type(channelName) ~= "string" then
            return ToolHelpers.FormatErrorResult("'channel_name' must be a string if provided.")
        end
        if speakerPath ~= nil and type(speakerPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'speaker_path' must be a string if provided.")
        end

        if not TextChatService then
            return ToolHelpers.FormatErrorResult("TextChatService is not available in this context.")
        end

        local textSource = nil
        if speakerPath then
            local foundSpeaker, err = ToolHelpers.FindInstanceByPath(speakerPath)
            if not foundSpeaker then
                return ToolHelpers.FormatErrorResult(("Speaker not found at path: %s. %s"):format(speakerPath, err or ""))
            end
            -- A TextSource can be a Player object or a TextChatSpeaker instance.
            if foundSpeaker:IsA("Player") then
                textSource = foundSpeaker
            elseif foundSpeaker:IsA("TextChatSpeaker") then
                 textSource = foundSpeaker
            elseif foundSpeaker:FindFirstChildOfClass("TextChatSpeaker") then -- Check if it's a model with a speaker
                textSource = foundSpeaker:FindFirstChildOfClass("TextChatSpeaker")
            else
                 -- Try to get Player object if speakerPath is a direct player name not in "Players.Name" format
                local playerByName = PlayersService:FindFirstChild(speakerPath)
                if playerByName and playerByName:IsA("Player") then
                    textSource = playerByName
                else
                    return ToolHelpers.FormatErrorResult("Speaker path does not point to a Player, TextChatSpeaker, or an Instance containing one.")
                end
            end
        end

        local targetChannel = nil
        if channelName then
            targetChannel = TextChatService:FindFirstChild(channelName, true) -- Recursive search for channel by name
            if not targetChannel or not targetChannel:IsA("TextChannel") then
                return ToolHelpers.FormatErrorResult(("TextChannel '%s' not found."):format(channelName))
            end
        end

        local sendSuccess, sendError

        if textSource then
            -- If a TextSource is provided, use its SendAsync method.
            -- If targetChannel is nil, it will send to the TextSource's default channel(s).
            sendSuccess, sendError = pcall(textSource.SendAsync, textSource, messageText, targetChannel)
        elseif targetChannel then
            -- If no TextSource, but a targetChannel is specified, send to that channel (system message).
            sendSuccess, sendError = pcall(targetChannel.SendAsync, targetChannel, messageText)
        else
            -- No TextSource and no specific channel, try sending to the default system channel.
            -- This relies on ChatInputBarConfiguration.TargetTextChannel or a general default.
            local config = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
            if config and config.TargetTextChannel then
                targetChannel = config.TargetTextChannel
                sendSuccess, sendError = pcall(targetChannel.SendAsync, targetChannel, messageText)
            else
                -- Fallback to RBXGeneral if no other default can be determined
                targetChannel = TextChatService:FindFirstChild("RBXGeneral")
                if targetChannel and targetChannel:IsA("TextChannel") then
                     sendSuccess, sendError = pcall(targetChannel.SendAsync, targetChannel, messageText)
                else
                    sendSuccess = false
                    sendError = "Could not determine a default TextChannel to send the message to."
                end
            end
        end

        if not sendSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to send chat message: %s"):format(tostring(sendError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = "Chat message sent successfully.",
            message_sent = messageText,
            channel_used = targetChannel and targetChannel.Name or "Default/Unknown",
            speaker_used = textSource and textSource.Name or "System/Default"
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in SendChatMessage: " .. tostring(pcall_result))
    end
end

return execute
