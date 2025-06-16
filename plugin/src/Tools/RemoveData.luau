-- RemoveData.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local DataStoreService = game:GetService("DataStoreService")

local function execute(args)
    -- Arguments are expected directly on args table
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

        local dsSuccess, dsError = pcall(dataStore.RemoveAsync, dataStore, key)

        if not dsSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to remove data from DataStore '%s' for key '%s': %s"):format(storeName, key, tostring(dsError)))
        end

        -- RemoveAsync returns nil on success, or throws an error.
        -- The pcall captures the error. If dsSuccess is true, it means nil was returned (operation successful).
        return ToolHelpers.FormatSuccessResult({
            message = ("Data successfully removed/marked for removal from DataStore '%s' for key '%s'."):format(storeName, key),
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
