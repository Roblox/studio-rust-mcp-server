-- SaveData.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local DataStoreService = game:GetService("DataStoreService")

local function execute(args)
    local success, pcall_result = pcall(function()
        local storeName = args.store_name
        local key = args.key
        local dataToSave = args.data -- This data is already in JSON-friendly Lua table/primitive format from Gemini

        if not storeName or type(storeName) ~= "string" or storeName == "" then
            return ToolHelpers.FormatErrorResult("'store_name' is required and must be a non-empty string.")
        end
        if not key or type(key) ~= "string" or key == "" then
            return ToolHelpers.FormatErrorResult("'key' is required and must be a non-empty string.")
        end
        if dataToSave == nil then -- Explicitly checking for nil, as false or 0 are valid data
            return ToolHelpers.FormatErrorResult("'data' is required.")
        end

        local dataStore = DataStoreService:GetDataStore(storeName)

        -- DataStore only accepts Lua primitives or tables that can be saved.
        -- The 'dataToSave' from Gemini is already in a Lua table/primitive format that
        -- should be directly usable by SetAsync after HttpService:JSONDecode on the Python side.
        -- No further ToolHelpers.JsonToRobloxValue is typically needed here for the *data itself*
        -- unless the data contained specific Roblox types that needed conversion, which is not
        -- standard for pure DataStore usage (as it stores serializable Lua types).

        local dsSuccess, dsError = pcall(function()
            dataStore:SetAsync(key, dataToSave)
        end)

        if not dsSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to save data to DataStore '%s' with key '%s': %s"):format(storeName, key, tostring(dsError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Data successfully saved to DataStore '%s' with key '%s'."):format(storeName, key),
            store_name = storeName,
            key = key
            -- Not returning the data itself to avoid large payloads, client should know what it saved.
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in SaveData: " .. tostring(pcall_result))
    end
end

return execute
