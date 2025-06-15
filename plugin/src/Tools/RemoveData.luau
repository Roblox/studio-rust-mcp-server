-- RemoveData.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local DataStoreService = game:GetService("DataStoreService")

local function execute(args)
    local success, pcall_result = pcall(function()
        local storeName = args.store_name
        local key = args.key

        if not storeName or type(storeName) ~= "string" or storeName == "" then
            return ToolHelpers.FormatErrorResult("'store_name' is required and must be a non-empty string.")
        end
        if not key or type(key) ~= "string" or key == "" then
            return ToolHelpers.FormatErrorResult("'key' is required and must be a non-empty string.")
        end

        local dataStore = DataStoreService:GetDataStore(storeName)

        -- RemoveAsync does not return the old value, just success/error.
        local dsSuccess, dsError = pcall(function()
            dataStore:RemoveAsync(key)
        end)

        if not dsSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to remove data from DataStore '%s' for key '%s': %s"):format(storeName, key, tostring(dsError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Data successfully removed from DataStore '%s' for key '%s'."):format(storeName, key),
            store_name = storeName,
            key = key
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in RemoveData: " .. tostring(pcall_result))
    end
end

return execute
