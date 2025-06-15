-- GetProductInfo.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local MarketplaceService = game:GetService("MarketplaceService")

local function execute(args)
    local success, pcall_result = pcall(function()
        local assetId = args.asset_id
        local infoTypeStr = args.info_type -- String like "Asset" or "Product"

        if not assetId or type(assetId) ~= "number" or assetId <= 0 then
            return ToolHelpers.FormatErrorResult("'asset_id' is required and must be a positive number.")
        end
        if not infoTypeStr or type(infoTypeStr) ~= "string" then
            return ToolHelpers.FormatErrorResult("'info_type' (Enum.InfoType) is required and must be a string.")
        end

        local infoTypeEnum = Enum.InfoType[infoTypeStr]
        if not infoTypeEnum then
            return ToolHelpers.FormatErrorResult("Invalid InfoType string: " .. infoTypeStr .. ". Must be 'Asset' or 'Product'.")
        end

        local productInfo
        local getInfoSuccess, resultOrError = pcall(MarketplaceService.GetProductInfo, MarketplaceService, assetId, infoTypeEnum)

        if not getInfoSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to get product info for asset ID %d: %s"):format(assetId, tostring(resultOrError)))
        end
        productInfo = resultOrError

        -- Convert productInfo table to a JSON-friendly format (it's mostly primitive types already)
        -- ToolHelpers.RobloxValueToJson will handle basic table conversion.
        local productInfoJson = ToolHelpers.RobloxValueToJson(productInfo)

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully retrieved product info for asset ID %d."):format(assetId),
            asset_id = assetId,
            info_type_used = infoTypeStr,
            product_info = productInfoJson
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in GetProductInfo: " .. tostring(pcall_result))
    end
end

return execute
