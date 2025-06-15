-- FilterTextForPlayer.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local TextService = game:GetService("TextService")
local PlayersService = game:GetService("Players")

local function execute(args)
    local success, pcall_result = pcall(function()
        local textToFilter = args.text_to_filter
        local playerPath = args.player_path -- This is the player *for whom* the text is being filtered, i.e., the viewer.

        if textToFilter == nil or type(textToFilter) ~= "string" then
            return ToolHelpers.FormatErrorResult("'text_to_filter' is required and must be a string.")
        end
        if not playerPath or type(playerPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'player_path' (for context) is required and must be a string.")
        end

        local playerInstance, err = ToolHelpers.FindInstanceByPath(playerPath)
        if not playerInstance or not playerInstance:IsA("Player") then
            playerInstance = PlayersService:FindFirstChild(playerPath)
            if not playerInstance or not playerInstance:IsA("Player") then
                return ToolHelpers.FormatErrorResult(("Player for context not found or invalid at path: %s. %s"):format(playerPath, err or ""))
            end
        end

        local filteredTextResult
        local filterSuccess, filterErrorOrResult = pcall(function()
            -- Using PublicChat context as a general default.
            -- The text is filtered based on the perspective of playerInstance.UserId
            return TextService:FilterStringAsync(textToFilter, playerInstance.UserId, Enum.TextFilterContext.PublicChat)
        end)

        if not filterSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to filter text (FilterStringAsync): %s"):format(tostring(filterErrorOrResult)))
        end

        -- TextFilterResult object from FilterStringAsync
        -- GetNonChatStringForBroadcastAsync is generally preferred for displaying to all if the original source is not a chat.
        -- If this text was from another player, GetChatForUserAsync(recipientUserId) would be used.
        -- Since the prompt asks to filter *for* a player, implies it's for their viewing or for text they generated to be seen by others.
        -- GetNonChatStringForBroadcastAsync is a good general choice here.
        local finalFilteredText
        local getTextSuccess, getTextErrorOrResult = pcall(filterErrorOrResult.GetNonChatStringForBroadcastAsync, filterErrorOrResult)

        if not getTextSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to retrieve filtered text string (GetNonChatStringForBroadcastAsync): %s"):format(tostring(getTextErrorOrResult)))
        end
        finalFilteredText = getTextErrorOrResult

        return ToolHelpers.FormatSuccessResult({
            message = "Text filtered successfully.",
            original_text = textToFilter,
            filtered_text = finalFilteredText,
            player_context_path = playerPath
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in FilterTextForPlayer: " .. tostring(pcall_result))
    end
end

return execute
