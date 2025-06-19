-- GetProductInfo.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local MarketplaceService = ToolHelpers.GetMarketplaceService()

local function execute(args: Types.GetProductInfoArgs)
    local success, pcall_result = pcall(function()
        local assetId = args.asset_id
        local infoTypeStr = args.info_type -- String like "Asset" or "Product"

        if not assetId or type(assetId) ~= "number" or assetId <= 0 then
            return ToolHelpers.FormatErrorResult("'asset_id' is required and must be a positive number.")
        end
        if not infoTypeStr or type(infoTypeStr) ~= "string" then
            return ToolHelpers.FormatErrorResult("'info_type' (Enum.InfoType) is required and must be a string like 'Asset' or 'Product'.")
        end

        local infoTypeEnum = Enum.InfoType[infoTypeStr]
        if not infoTypeEnum then
            return ToolHelpers.FormatErrorResult("Invalid InfoType string: " .. infoTypeStr .. ". Must be 'Asset' or 'Product'.")
        end

        local productInfo
        -- GetProductInfo can sometimes error for valid IDs if the asset is moderated or unavailable.
        local getInfoSuccess, resultOrError = pcall(MarketplaceService.GetProductInfo, MarketplaceService, assetId, infoTypeEnum)

        if not getInfoSuccess then
            return ToolHelpers.FormatErrorResult(("MarketplaceService:GetProductInfo failed for asset ID %d (InfoType: %s): %s"):format(assetId, infoTypeStr, tostring(resultOrError)))
        end
        productInfo = resultOrError

        -- productInfo is a table. ToolHelpers.FormatSuccessResult will handle its JSON encoding.
        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully retrieved product info for asset ID %d."):format(assetId),
            asset_id = assetId,
            info_type_used = infoTypeStr,
            product_info = productInfo -- Pass the raw Lua table here
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in GetProductInfo: " .. tostring(pcall_result))
    end
end

return execute
