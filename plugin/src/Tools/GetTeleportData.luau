-- GetTeleportData.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local PlayersService = game:GetService("Players")

local function execute(args)
    -- This function is intended to be called by a LocalScript on the client after a teleport.
    -- Or, if called on server, it might get data if server itself was "teleported" to (not typical for players).
    -- For now, assumes LocalPlayer context for typical use case.
    local success, pcall_result = pcall(function()
        local localPlayer = PlayersService.LocalPlayer -- This will be nil if not in a LocalScript or client context

        if not localPlayer then
            return ToolHelpers.FormatErrorResult("Cannot get LocalPlayer. This tool is primarily for client-side use after a teleport or requires specific server context.")
        end

        local teleportData = localPlayer:GetJoinData() -- GetJoinData contains TeleportData among other things

        if not teleportData or not teleportData.TeleportData then
            return ToolHelpers.FormatSuccessResult({
                message = "No teleport data found for the local player.",
                teleport_data = nil
            })
        end

        -- teleportData.TeleportData is already a Lua table.
        -- We use RobloxValueToJson to ensure it's in a JSON-friendly format if it contains complex Roblox types (unlikely for pure teleport data).
        local jsonData = ToolHelpers.RobloxValueToJson(teleportData.TeleportData)

        return ToolHelpers.FormatSuccessResult({
            message = "Successfully retrieved teleport data for the local player.",
            teleport_data = jsonData
        })
    end)

    if success then
        return pcall_result
    else
        if string.find(tostring(pcall_result), "Cannot get LocalPlayer") then
             return ToolHelpers.FormatErrorResult(tostring(pcall_result))
        end
        return ToolHelpers.FormatErrorResult("Internal error in GetTeleportData: " .. tostring(pcall_result))
    end
end

return execute
