-- PromptPurchase.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local MarketplaceService = game:GetService("MarketplaceService")
local PlayersService = game:GetService("Players")

local function find_player(pathOrName)
    if not pathOrName then return nil end
    if string.find(pathOrName, "%.") then
        local obj, err = ToolHelpers.FindInstanceByPath(pathOrName)
        if obj and obj:IsA("Player") then
            return obj
        end
    end
    -- Fallback to searching by name if not a full path or if path resolution failed
    for _, player in ipairs(PlayersService:GetPlayers()) do
        if player.Name == pathOrName then
            return player
        end
    end
    return nil
end

local function execute(args)
    local success, pcall_result = pcall(function()
        local playerPath = args.player_path
        local assetId = args.asset_id

        if not playerPath or type(playerPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'player_path' is required and must be a string (e.g., 'Players.Username' or just username).")
        end
        if not assetId or type(assetId) ~= "number" or assetId <= 0 then
            return ToolHelpers.FormatErrorResult("'asset_id' is required and must be a positive number.")
        end

        local player = find_player(playerPath)
        if not player then
            return ToolHelpers.FormatErrorResult("Player not found: " .. playerPath .. ". This tool requires the game to be running with the specified player.")
        end

        -- As per refined Python description: "Prompts a player to purchase a general asset (like a model or UGC item) using its asset ID.
        -- For game passes, a different specific prompt might be needed on the Roblox side."
        -- MarketplaceService:PromptPurchase is used for assets like models, decals, plugins.
        -- MarketplaceService:PromptProductPurchase is for Developer Products.
        -- MarketplaceService:PromptGamePassPurchase is for Game Passes.
        -- This tool will use PromptPurchase, suitable for general assets.
        -- Gemini should be guided to use this for e.g. models, decals, etc.
        -- If a specific product type (DevProduct, GamePass) is intended, a more specific tool or parameter would be needed.

        local promptSuccess, promptError = pcall(MarketplaceService.PromptPurchase, MarketplaceService, player, assetId)

        if not promptSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to initiate purchase prompt for player %s, asset ID %d: %s"):format(player.Name, assetId, tostring(promptError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("General asset purchase prompt initiated for player %s for asset ID %d. Player must complete transaction on their client."):format(player.Name, assetId),
            player_name = player.Name,
            asset_id = assetId,
            purchase_type_prompted = "GeneralAsset (using MarketplaceService:PromptPurchase)"
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in PromptPurchase: " .. tostring(pcall_result))
    end
end

return execute
