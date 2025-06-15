-- LoadData.luau
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
        local loadedData
        local dsSuccess, dsResultOrError = pcall(function()
            loadedData = dataStore:GetAsync(key)
        end)

        if not dsSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to load data from DataStore '%s' with key '%s': %s"):format(storeName, key, tostring(dsResultOrError)))
        end

        -- The loadedData is already in Lua format.
        -- ToolHelpers.RobloxValueToJson is used here to ensure any Roblox instances *accidentally*
        -- stored in tables (not best practice for DataStores) are converted, but primarily
        -- it handles converting Lua tables to a JSON-friendly structure if they weren't already.
        -- For pure Lua types (string, number, boolean, simple tables), this will mostly pass them through
        -- or ensure table keys are strings if they are to be JSON encoded later by ToolHelpers.FormatSuccessResult.
        local jsonData = ToolHelpers.RobloxValueToJson(loadedData)

        if loadedData == nil then
             return ToolHelpers.FormatSuccessResult({
                message = ("No data found in DataStore '%s' for key '%s'."):format(storeName, key),
                store_name = storeName,
                key = key,
                data = nil
            })
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Data successfully loaded from DataStore '%s' with key '%s'."):format(storeName, key),
            store_name = storeName,
            key = key,
            data = jsonData
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in LoadData: " .. tostring(pcall_result))
    end
end

return execute
