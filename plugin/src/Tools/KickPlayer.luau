-- KickPlayer.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local PlayersService = game:GetService("Players")

local function find_player(pathOrName)
    -- Try finding by full name first (more specific)
    if string.find(pathOrName, "%.") then -- It's likely a path
        local obj, err = ToolHelpers.FindInstanceByPath(pathOrName)
        if obj and obj:IsA("Player") then
            return obj
        end
    end
    -- Try finding by name among players
    for _, player in ipairs(PlayersService:GetPlayers()) do
        if player.Name == pathOrName then
            return player
        end
    end
    return nil
end

local function execute(args)
    local success, result = pcall(function()
        local playerPathOrName = args.player_path_or_name
        local kickMessage = args.kick_message or "You have been kicked from the game by an admin." -- Default message

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

        local kickSuccess, kickError = pcall(function()
            playerToKick:Kick(kickMessage)
        end)

        if not kickSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to kick player '%s': %s"):format(playerPathOrName, tostring(kickError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully kicked player %s with message: %s"):format(playerToKick.Name, kickMessage),
            kicked_player_name = playerToKick.Name
        })
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in KickPlayer: " .. tostring(result))
    end
end

return execute
