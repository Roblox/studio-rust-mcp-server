-- TeleportPlayerToPlace.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local TeleportService = ToolHelpers.GetTeleportService()
local PlayersService = ToolHelpers.GetPlayersService()

local function execute(args)
    -- Arguments are expected directly on args table
    local success, pcall_result = pcall(function()
        local playerPaths = args.player_paths
        local placeId = args.place_id
        local jobId = args.job_id -- Optional
        local teleportData = args.teleport_data -- Optional (Lua table)
        local customLoadingScreenGuiPath = args.custom_loading_screen_gui_path -- Optional

        if not playerPaths or type(playerPaths) ~= "table" or #playerPaths == 0 then
            return ToolHelpers.FormatErrorResult("'player_paths' is required and must be a non-empty array of strings.")
        end
        for i, pPath in ipairs(playerPaths) do
            if type(pPath) ~= "string" then
                 return ToolHelpers.FormatErrorResult(("Entry at index %d in 'player_paths' is not a string."):format(i))
            end
        end
        if not placeId or type(placeId) ~= "number" then
            return ToolHelpers.FormatErrorResult("'place_id' is required and must be a number.")
        end
        if jobId ~= nil and type(jobId) ~= "string" then
            return ToolHelpers.FormatErrorResult("'job_id' must be a string if provided.")
        end
        if teleportData ~= nil and type(teleportData) ~= "table" then
            -- Allow nil for teleportData, but if provided, must be a table.
            return ToolHelpers.FormatErrorResult("'teleport_data' must be a table if provided.")
        end
        if customLoadingScreenGuiPath ~= nil and type(customLoadingScreenGuiPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'custom_loading_screen_gui_path' must be a string if provided.")
        end

        local playersToTeleport = {}
        local playerPathErrors = {}
        for _, playerPathStr in ipairs(playerPaths) do
            local playerInstance, err = ToolHelpers.FindInstanceByPath(playerPathStr)
            if playerInstance and playerInstance:IsA("Player") then
                table.insert(playersToTeleport, playerInstance)
            else
                -- Fallback: try finding by name if not a full path
                local playerByName = PlayersService:FindFirstChild(playerPathStr)
                if playerByName and playerByName:IsA("Player") then
                    table.insert(playersToTeleport, playerByName)
                else
                    table.insert(playerPathErrors, {path = playerPathStr, error = err or "Not found or not a Player."})
                end
            end
        end

        if #playerPathErrors > 0 then
            return ToolHelpers.FormatErrorResult("Error finding some player(s).", {errors = playerPathErrors})
        end
        if #playersToTeleport == 0 then
            return ToolHelpers.FormatErrorResult("No valid players found from the provided paths to teleport.")
        end


        local teleportOptions = Instance.new("TeleportOptions")
        if jobId then
            teleportOptions.ServerInstanceId = jobId
        end
        if teleportData then
            teleportOptions:SetTeleportData(teleportData)
        end

        local loadingScreenGui = nil
        if customLoadingScreenGuiPath then
            local foundGui, guiErr = ToolHelpers.FindInstanceByPath(customLoadingScreenGuiPath)
            if foundGui and foundGui:IsA("ScreenGui") then
                loadingScreenGui = foundGui
                -- TeleportService:SetCustomLoadingScreen must be called on client, or server for specific cases.
                -- For plugin-driven teleport, this might not work as expected unless the plugin has client context.
                -- If this is server-side, custom loading screen for server->server teleports is complex.
                -- For now, assume this tool primarily triggers client teleports if used in Studio 'Run' mode.
                -- The actual SetCustomLoadingScreen call might be better handled by a LocalScript triggered by this server action.
                -- For simplicity, we'll pcall it, but acknowledge limitations.
                local setGuiSuccess, setGuiError = pcall(TeleportService.SetCustomLoadingScreen, TeleportService, loadingScreenGui)
                if not setGuiSuccess then
                    print(("TeleportPlayerToPlace: Warning - Failed to set custom loading screen GUI: %s. Path: %s. Error: %s"):format(customLoadingScreenGuiPath, guiErr or "Error during SetCustomLoadingScreen", tostring(setGuiError)))
                end
            else
                 print(("TeleportPlayerToPlace: Warning - Custom loading screen GUI not found or invalid at path: %s. %s"):format(customLoadingScreenGuiPath, guiErr or ""))
            end
        end

        local tpSuccess, tpResultOrError = pcall(TeleportService.TeleportAsync, TeleportService, placeId, playersToTeleport, teleportOptions)

        if loadingScreenGui then
            -- Attempt to clear, acknowledging same context limitations as setting it.
            pcall(TeleportService.SetCustomLoadingScreen, TeleportService, nil)
        end

        if not tpSuccess then
            return ToolHelpers.FormatErrorResult(("TeleportAsync failed: %s"):format(tostring(tpResultOrError)))
        end

        -- TeleportAsync doesn't return a useful value on success, it's the client that teleports.
        -- The "result" (tpResultOrError) on success is often nil or an empty table.

        local playerNames = {}
        for _,p in ipairs(playersToTeleport) do table.insert(playerNames, p.Name) end

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully initiated teleport for player(s) %s to place ID %d."):format(table.concat(playerNames, ", "), placeId),
            players_teleported_names = playerNames,
            place_id = placeId,
            job_id_used = jobId, -- Use different key to avoid confusion with 'job_id' arg
            teleport_data_sent = teleportData
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in TeleportPlayerToPlace: " .. tostring(pcall_result))
    end
end

return execute
