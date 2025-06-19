-- LoadData.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local DataStoreService = game:GetService("DataStoreService")

local function execute(args: Types.LoadDataArgs)
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
        local loadedData

        -- GetAsync can error for various reasons (network, throttling, etc.)
        local dsSuccess, dsResultOrError = pcall(dataStore.GetAsync, dataStore, key)

        if not dsSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to load data from DataStore '%s' with key '%s': %s"):format(storeName, key, tostring(dsResultOrError)))
        end
        loadedData = dsResultOrError -- This is the actual data from the datastore

        if loadedData == nil then
             return ToolHelpers.FormatSuccessResult({
                message = ("No data found in DataStore '%s' for key '%s' (value was nil)."):format(storeName, key),
                store_name = storeName,
                key = key,
                data = nil -- Explicitly nil
            })
        end

        -- loadedData is already a Lua value/table. FormatSuccessResult will handle JSON encoding.
        return ToolHelpers.FormatSuccessResult({
            message = ("Data successfully loaded from DataStore '%s' with key '%s'."):format(storeName, key),
            store_name = storeName,
            key = key,
            data = loadedData -- Pass the raw Lua data
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in LoadData: " .. tostring(pcall_result))
    end
end

return execute
