-- PromptPurchase.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
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
    for _, player in ipairs(PlayersService:GetPlayers()) do
        if player.Name == pathOrName then
            return player
        end
    end
    return nil
end

local function execute(args: Types.PromptPurchaseArgs)
    -- Arguments are expected directly on args table
    local success, pcall_result = pcall(function()
        local playerPath = args.player_path
        local assetId = args.asset_id
        -- Optional: equip_if_purchased (for accessories, gear - not directly supported by PromptPurchase, would be a post-purchase action)
        -- local equipIfPurchased = args.equip_if_purchased == nil and true or args.equip_if_purchased

        if not playerPath or type(playerPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'player_path' is required and must be a string (e.g., 'Players.Username' or just username).")
        end
        if not assetId or type(assetId) ~= "number" or assetId <= 0 then
            return ToolHelpers.FormatErrorResult("'asset_id' is required and must be a positive number.")
        end
        -- if type(equipIfPurchased) ~= "boolean" then
        --     return ToolHelpers.FormatErrorResult("'equip_if_purchased' must be a boolean if provided.")
        -- end


        local player = find_player(playerPath)
        if not player then
            return ToolHelpers.FormatErrorResult("Player not found: " .. playerPath .. ". This tool requires the game to be running with the specified player.")
        end

        -- MarketplaceService:PromptPurchase is for assets like models, decals, plugins (items that can be taken or added to inventory).
        -- It is NOT for Developer Products (use PromptProductPurchase) or Game Passes (use PromptGamePassPurchase).
        local promptSuccess, promptError = pcall(MarketplaceService.PromptPurchase, MarketplaceService, player, assetId)

        if not promptSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to initiate purchase prompt for player %s, asset ID %d: %s"):format(player.Name, assetId, tostring(promptError)))
        end

        -- Note: The actual success of the purchase is handled by client-side callbacks connected to PromptPurchaseFinished event.
        -- This tool can only report that the prompt was initiated.
        return ToolHelpers.FormatSuccessResult({
            message = ("General asset purchase prompt initiated for player %s for asset ID %d. Player must complete transaction on their client."):format(player.Name, assetId),
            player_name = player.Name,
            asset_id = assetId,
            purchase_type_prompted = "GeneralAsset (using MarketplaceService:PromptPurchase)"
            -- equip_if_purchased_setting = equipIfPurchased -- Would require further logic post-purchase
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in PromptPurchase: " .. tostring(pcall_result))
    end
end

return execute
