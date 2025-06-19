-- SendChatMessage.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local TextChatService = game:GetService("TextChatService")
local PlayersService = game:GetService("Players")

local function execute(args: Types.SendChatMessageArgs)
    -- Arguments are expected directly on args table
    local success, pcall_result = pcall(function()
        local messageText = args.message_text
        local channelName = args.channel_name -- Optional
        local speakerPath = args.speaker_path -- Optional

        if messageText == nil or type(messageText) ~= "string" then
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
                -- Try finding by name if path fails, for convenience if user just gives player name
                foundSpeaker = PlayersService:FindFirstChild(speakerPath)
                if not foundSpeaker then
                     return ToolHelpers.FormatErrorResult(("Speaker not found at path or by name: %s. %s"):format(speakerPath, err or "Not found by name."))
                end
            end

            if foundSpeaker:IsA("Player") then
                textSource = foundSpeaker
            elseif foundSpeaker:IsA("TextChatSpeaker") then
                 textSource = foundSpeaker
            elseif foundSpeaker:FindFirstChildOfClass("TextChatSpeaker") then
                textSource = foundSpeaker:FindFirstChildOfClass("TextChatSpeaker")
            else
                 return ToolHelpers.FormatErrorResult("Speaker path does not point to a Player, TextChatSpeaker, or an Instance containing one. Found type: " .. foundSpeaker:GetClass())
            end
        end

        local targetChannel = nil
        if channelName then
            -- Attempt to find channel under TextChatService. It could be nested.
            targetChannel = TextChatService:FindFirstChild(channelName, true)
            if not targetChannel or not targetChannel:IsA("TextChannel") then
                return ToolHelpers.FormatErrorResult(("TextChannel '%s' not found under TextChatService."):format(channelName))
            end
        end

        local sendSuccess, sendError

        if textSource then
            -- If a TextSource is provided, use its SendAsync method.
            -- If targetChannel is nil, it sends to the TextSource's default channel(s).
            sendSuccess, sendError = pcall(textSource.SendAsync, textSource, messageText, targetChannel)
        elseif targetChannel then
            -- No TextSource, but a targetChannel is specified: send as system message to that channel.
            sendSuccess, sendError = pcall(targetChannel.SendAsync, targetChannel, messageText)
        else
            -- No TextSource and no specific channel: try sending to a default system channel.
            -- This usually means finding RBXSystemMessages or similar, or ChatInputBarConfiguration.TargetTextChannel
            local defaultSystemChannel = TextChatService:FindFirstChild("RBXSystemMessages")
            if defaultSystemChannel and defaultSystemChannel:IsA("TextChannel") then
                targetChannel = defaultSystemChannel
                sendSuccess, sendError = pcall(targetChannel.SendAsync, targetChannel, messageText)
            else
                -- Fallback if RBXSystemMessages isn't found, try RBXGeneral (less common for system messages)
                targetChannel = TextChatService:FindFirstChild("RBXGeneral")
                 if targetChannel and targetChannel:IsA("TextChannel") then
                     sendSuccess, sendError = pcall(targetChannel.SendAsync, targetChannel, messageText)
                 else
                    sendSuccess = false
                    sendError = "Could not determine a default TextChannel (e.g., RBXSystemMessages or RBXGeneral) to send the message to, and no specific channel or speaker provided."
                end
            end
        end

        if not sendSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to send chat message: %s"):format(tostring(sendError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = "Chat message sent successfully.",
            message_sent = messageText,
            channel_used = targetChannel and targetChannel.Name or "Default/Determined by TextSource",
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
