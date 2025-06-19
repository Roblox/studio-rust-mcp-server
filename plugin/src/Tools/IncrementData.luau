-- IncrementData.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local DataStoreService = ToolHelpers.GetDataStoreService()

local function execute(args: Types.IncrementDataArgs)
    -- Arguments are expected directly on args table
    local success, pcall_result = pcall(function()
        local storeName = args.store_name
        local key = args.key
        local incrementBy = args.increment_by -- Default to 1 if not provided? Current requires it.

        if not storeName or type(storeName) ~= "string" or storeName == "" then
            return ToolHelpers.FormatErrorResult("'store_name' is required and must be a non-empty string.")
        end
        if not key or type(key) ~= "string" or key == "" then
            return ToolHelpers.FormatErrorResult("'key' is required and must be a non-empty string.")
        end
        if incrementBy == nil then -- Allow for default increment of 1
            incrementBy = 1
        end
        if type(incrementBy) ~= "number" then
            return ToolHelpers.FormatErrorResult("'increment_by' must be a number.")
        end

        local dataStore = DataStoreService:GetDataStore(storeName)
        local newValue

        local dsSuccess, dsResultOrError = pcall(dataStore.IncrementAsync, dataStore, key, incrementBy)

        if not dsSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to increment data in DataStore '%s' for key '%s': %s"):format(storeName, key, tostring(dsResultOrError)))
        end
        newValue = dsResultOrError -- IncrementAsync returns the new value

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
