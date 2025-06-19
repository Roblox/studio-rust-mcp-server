-- GetInstancesWithTag.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local CollectionService = ToolHelpers.GetCollectionService()

local function execute(args: Types.GetInstancesWithTagArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local tagName = args.tag_name

        if not tagName or type(tagName) ~= "string" or tagName == "" then
            return "'tag_name' is required and must be a non-empty string."
        end

        local taggedInstances = CollectionService:GetTagged(tagName)
        local instancePaths: {string} = {}

        for _, instance in ipairs(taggedInstances) do
            if instance and instance.Parent ~= nil then -- Ensure instance is valid and in DataModel
                -- And ensure it's actually an instance that can have a FullName
                if typeof(instance) == "Instance" then
                    table.insert(instancePaths, instance:GetFullName())
                end
            end
        end

        local HttpService = game:GetService("HttpService")
        local jsonEncodedInstancePaths = HttpService:JSONEncode(instancePaths)

        return jsonEncodedInstancePaths -- This will be the actual data returned on success
    end)

    if success then
        if type(resultOrError) == "string" and string.find(resultOrError, "tag_name") then
            -- This was an error string for invalid arguments from within the pcall
            return ToolHelpers.FormatErrorResult(resultOrError, {error_type = "InvalidArguments"})
        else
            -- Successful execution, resultOrError is the JSON string of instance paths
            -- Manually construct the success response structure
            return { content = { { type = "text", text = resultOrError } }, isError = false }
        end
    else
        -- This is an error from the pcall itself (e.g. HttpService not available, or other script error)
        local err_msg = "Internal error in GetInstancesWithTag: " .. tostring(resultOrError)
        return ToolHelpers.FormatErrorResult(err_msg, {internal_error_details = tostring(resultOrError), is_luau_error = true})
    end
end

return execute
