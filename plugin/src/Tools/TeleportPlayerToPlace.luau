-- TeleportPlayerToPlace.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local TeleportService = game:GetService("TeleportService")
local PlayersService = game:GetService("Players")

local function execute(args)
    local success, pcall_result = pcall(function()
        local playerPaths = args.player_paths
        local placeId = args.place_id
        local jobId = args.job_id -- Optional
        local teleportData = args.teleport_data -- Optional (Lua table)
        local customLoadingScreenGuiPath = args.custom_loading_screen_gui_path -- Optional

        if not playerPaths or type(playerPaths) ~= "table" or #playerPaths == 0 then
            return ToolHelpers.FormatErrorResult("'player_paths' is required and must be a non-empty array of strings.")
        end
        if not placeId or type(placeId) ~= "number" then
            return ToolHelpers.FormatErrorResult("'place_id' is required and must be a number.")
        end
        if jobId ~= nil and type(jobId) ~= "string" then
            return ToolHelpers.FormatErrorResult("'job_id' must be a string if provided.")
        end
        if teleportData ~= nil and type(teleportData) ~= "table" then
            return ToolHelpers.FormatErrorResult("'teleport_data' must be a table if provided.")
        end
         if customLoadingScreenGuiPath ~= nil and type(customLoadingScreenGuiPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'custom_loading_screen_gui_path' must be a string if provided.")
        end

        local playersToTeleport = {}
        for _, playerPath in ipairs(playerPaths) do
            local playerInstance, err = ToolHelpers.FindInstanceByPath(playerPath)
            if playerInstance and playerInstance:IsA("Player") then
                table.insert(playersToTeleport, playerInstance)
            else
                return ToolHelpers.FormatErrorResult(("Player not found or invalid at path: %s. %s"):format(playerPath, err or ""))
            end
        end

        if #playersToTeleport == 0 then
            return ToolHelpers.FormatErrorResult("No valid players found to teleport.")
        end

        local teleportOptions = Instance.new("TeleportOptions")
        if jobId then
            teleportOptions.ServerInstanceId = jobId
        end
        if teleportData then
            -- TeleportData must be a Lua table. The input 'teleportData' is already a Lua table
            -- as it's decoded from JSON by the HttpService on the main server script.
            teleportOptions:SetTeleportData(teleportData)
        end

        local loadingScreenGui = nil
        if customLoadingScreenGuiPath then
            local foundGui, guiErr = ToolHelpers.FindInstanceByPath(customLoadingScreenGuiPath)
            if foundGui and foundGui:IsA("ScreenGui") then
                loadingScreenGui = foundGui
                TeleportService:SetCustomLoadingScreen(loadingScreenGui)
            else
                 print(("TeleportPlayerToPlace: Warning - Custom loading screen GUI not found or invalid at path: %s. %s"):format(customLoadingScreenGuiPath, guiErr or ""))
                -- Proceed without custom loading screen if not found/invalid
            end
        end

        -- TeleportService:TeleportAsync can only be called on the server and for specific players.
        -- If this plugin is running in Studio, this will likely error unless in a server script context during Play Solo.
        local tpSuccess, tpError = pcall(TeleportService.TeleportAsync, TeleportService, placeId, playersToTeleport, teleportOptions)

        if loadingScreenGui then -- Clear custom loading screen after setting it, even if teleport fails, to not affect next teleports.
            TeleportService:SetCustomLoadingScreen(nil)
        end

        if not tpSuccess then
            return ToolHelpers.FormatErrorResult(("Teleport failed: %s"):format(tostring(tpError)))
        end

        local playerNames = {}
        for _,p in ipairs(playersToTeleport) do table.insert(playerNames, p.Name) end

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully initiated teleport for player(s) %s to place ID %d."):format(table.concat(playerNames, ", "), placeId),
            players_teleported = playerNames,
            place_id = placeId,
            job_id = jobId,
            teleport_data_sent = teleportData -- Confirm what was attempted to be sent
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in TeleportPlayerToPlace: " .. tostring(pcall_result))
    end
end

return execute
