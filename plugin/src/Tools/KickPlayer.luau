-- KickPlayer.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local PlayersService = ToolHelpers.GetPlayersService()

local function find_player(pathOrName)
    -- Try finding by full name first (more specific)
    if string.find(pathOrName, "%.") then -- It's likely a path
        local obj, err = ToolHelpers.FindInstanceByPath(pathOrName)
        if obj and obj:IsA("Player") then
            return obj
        end
    end
    -- Try finding by name among players
    -- This is case-sensitive. For case-insensitive, use string.lower on both.
    for _, player in ipairs(PlayersService:GetPlayers()) do
        if player.Name == pathOrName then
            return player
        end
    end
    return nil
end

local function execute(args: Types.KickPlayerArgs)
    -- Arguments are expected directly on args table
    local success, pcall_result = pcall(function()
        local playerPathOrName = args.player_path_or_name
        local kickMessage = args.kick_message or "You have been kicked from the game." -- Default message

        if not playerPathOrName or type(playerPathOrName) ~= "string" then
            return ToolHelpers.FormatErrorResult("'player_path_or_name' is required and must be a string.")
        end
        if type(kickMessage) ~= "string" then
            return ToolHelpers.FormatErrorResult("'kick_message' must be a string if provided.")
        end

        local playerToKick = find_player(playerPathOrName)

        if not playerToKick then
            return ToolHelpers.FormatErrorResult(("Player '%s' not found."):format(playerPathOrName))
        end

        -- player:Kick() can error if, for example, the player is already leaving.
        local kickActualSuccess, kickActualError = pcall(playerToKick.Kick, playerToKick, kickMessage)

        if not kickActualSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to kick player '%s': %s"):format(playerPathOrName, tostring(kickActualError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully kicked player %s with message: \"%s\""):format(playerToKick.Name, kickMessage),
            kicked_player_name = playerToKick.Name,
            kick_message_used = kickMessage
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in KickPlayer: " .. tostring(pcall_result))
    end
end

return execute
