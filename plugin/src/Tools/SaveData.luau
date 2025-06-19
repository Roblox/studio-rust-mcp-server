-- SaveData.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local DataStoreService = game:GetService("DataStoreService")

local function execute(args: Types.SaveDataArgs)
    -- Arguments are expected directly on args table
    local success, pcall_result = pcall(function()
        local storeName = args.store_name
        local key = args.key
        local dataToSave = args.data

        if not storeName or type(storeName) ~= "string" or storeName == "" then
            return ToolHelpers.FormatErrorResult("'store_name' is required and must be a non-empty string.")
        end
        if not key or type(key) ~= "string" or key == "" then
            return ToolHelpers.FormatErrorResult("'key' is required and must be a non-empty string.")
        end
        if dataToSave == nil then
            return ToolHelpers.FormatErrorResult("'data' is required. To store a nil value explicitly, consider if DataStore handles this or if an alternative representation is needed (e.g., a special string or table). For 'remove', use RemoveData tool.")
        end

        local dataStore = DataStoreService:GetDataStore(storeName)

        -- DataStore's SetAsync expects Lua data.
        -- The 'dataToSave' argument is assumed to be valid Lua data,
        -- as it would have been decoded from JSON by the calling environment (Main.server.luau).
        local dsSuccess, dsError = pcall(dataStore.SetAsync, dataStore, key, dataToSave)

        if not dsSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to save data to DataStore '%s' with key '%s': %s"):format(storeName, key, tostring(dsError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Data successfully saved to DataStore '%s' with key '%s'."):format(storeName, key),
            store_name = storeName,
            key = key
            -- Data saved is not returned in the response to keep it concise.
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in SaveData: " .. tostring(pcall_result))
    end
end

return execute
