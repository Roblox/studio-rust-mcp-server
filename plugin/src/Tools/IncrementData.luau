-- IncrementData.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local DataStoreService = game:GetService("DataStoreService")

local function execute(args)
    local success, pcall_result = pcall(function()
        local storeName = args.store_name
        local key = args.key
        local incrementBy = args.increment_by

        if not storeName or type(storeName) ~= "string" or storeName == "" then
            return ToolHelpers.FormatErrorResult("'store_name' is required and must be a non-empty string.")
        end
        if not key or type(key) ~= "string" or key == "" then
            return ToolHelpers.FormatErrorResult("'key' is required and must be a non-empty string.")
        end
        if type(incrementBy) ~= "number" then
            return ToolHelpers.FormatErrorResult("'increment_by' is required and must be a number.")
        end

        local dataStore = DataStoreService:GetDataStore(storeName)
        local newValue

        -- IncrementAsync returns the new value after incrementing.
        -- If the key doesn't exist, DataStore initializes it to 0 before incrementing,
        -- so the first value will be the incrementBy amount itself.
        local dsSuccess, dsResultOrError = pcall(function()
            newValue = dataStore:IncrementAsync(key, incrementBy)
        end)

        if not dsSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to increment data in DataStore '%s' for key '%s': %s"):format(storeName, key, tostring(dsResultOrError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Data successfully incremented in DataStore '%s' for key '%s'. New value is %s."):format(storeName, key, tostring(newValue)),
            store_name = storeName,
            key = key,
            new_value = newValue,
            incremented_by = incrementBy
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in IncrementData: " .. tostring(pcall_result))
    end
end

return execute
