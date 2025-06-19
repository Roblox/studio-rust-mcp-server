-- FilterTextForPlayer.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local TextService = ToolHelpers.GetTextService()
local PlayersService = ToolHelpers.GetPlayersService()

local function execute(args: Types.FilterTextForPlayerArgs)
    -- Arguments are now expected directly on args table
    local success, pcall_result = pcall(function()
        local textToFilter = args.text_to_filter
        local playerPath = args.player_path

        if textToFilter == nil or type(textToFilter) ~= "string" then
            return ToolHelpers.FormatErrorResult("'text_to_filter' is required and must be a string.")
        end
        if not playerPath or type(playerPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'player_path' (for context) is required and must be a string path to a Player instance.")
        end

        local playerInstance, err = ToolHelpers.FindInstanceByPath(playerPath)
        if not playerInstance or not playerInstance:IsA("Player") then
            playerInstance = PlayersService:FindFirstChild(playerPath)
            if not playerInstance or not playerInstance:IsA("Player") then
                 return ToolHelpers.FormatErrorResult(("Player for context not found or invalid at path/name: %s. Error: %s"):format(playerPath, err or "Not found by name either."))
            end
        end

        local filterSuccess, filterErrorOrResult = pcall(TextService.FilterStringAsync, TextService, textToFilter, playerInstance.UserId, Enum.TextFilterContext.PublicChat)

        if not filterSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to filter text (FilterStringAsync error): %s"):format(tostring(filterErrorOrResult)))
        end

        local textFilterResultObj = filterErrorOrResult
        local finalFilteredText
        local getTextSuccess, getTextErrorOrResult = pcall(textFilterResultObj.GetNonChatStringForBroadcastAsync, textFilterResultObj)

        if not getTextSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to retrieve filtered text string from TextFilterResult (e.g., GetNonChatStringForBroadcastAsync error): %s"):format(tostring(getTextErrorOrResult)))
        end
        finalFilteredText = getTextErrorOrResult

        return ToolHelpers.FormatSuccessResult({
            message = "Text filtered successfully.",
            original_text = textToFilter,
            filtered_text = finalFilteredText,
            player_context_path = playerPath,
            player_user_id_used = playerInstance.UserId
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in FilterTextForPlayer: " .. tostring(pcall_result))
    end
end

return execute
