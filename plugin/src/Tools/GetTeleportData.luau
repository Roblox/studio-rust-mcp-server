-- GetTeleportData.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local PlayersService = ToolHelpers.GetPlayersService()

local function execute(args: Types.GetTeleportDataArgs)
    -- This tool does not take arguments from the 'args' table for its core logic.
    local success, pcall_result = pcall(function()
        local localPlayer = PlayersService.LocalPlayer

        if not localPlayer then
            return ToolHelpers.FormatErrorResult("GetTeleportData: LocalPlayer not available. This tool is intended for client-side use or specific contexts where LocalPlayer exists.")
        end

        local joinData = localPlayer:GetJoinData()

        -- joinData.TeleportData can be nil if no data was sent, or any Lua type/table.
        local teleportDataContent = joinData and joinData.TeleportData -- This is the actual data passed via TeleportService

        if teleportDataContent == nil then -- Explicitly check for nil to differentiate from false or empty string/table
            return ToolHelpers.FormatSuccessResult({
                message = "No TeleportData found for the local player (TeleportData was nil).",
                teleport_data = nil,
                source_place_id = joinData and joinData.SourcePlaceId or nil
            })
        end

        -- The teleportDataContent is already a Lua value/table.
        -- FormatSuccessResult will handle its JSON encoding.
        return ToolHelpers.FormatSuccessResult({
            message = "Successfully retrieved TeleportData for the local player.",
            teleport_data = teleportDataContent, -- Pass the raw Lua data
            source_place_id = joinData and joinData.SourcePlaceId or nil
        })
    end)

    if success then
        return pcall_result -- This is already a ToolHelpers formatted table
    else
        -- pcall_result contains the error message string
        return ToolHelpers.FormatErrorResult("Internal error in GetTeleportData: " .. tostring(pcall_result))
    end
end

return execute
