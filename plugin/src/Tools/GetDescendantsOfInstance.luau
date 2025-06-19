-- GetDescendantsOfInstance.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added

local function execute(args: Types.GetDescendantsOfInstanceArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local instancePath = args.instance_path

        if not instancePath or type(instancePath) ~= "string" or instancePath == "" then
            return "'instance_path' is required and must be a non-empty string."
        end

        local instance, err = ToolHelpers.FindInstanceByPath(instancePath)
        if not instance then
            return ("Instance not found at path: %s. %s"):format(instancePath, err or "Unknown error")
        end

        local descendants = instance:GetDescendants()
        local descendantPaths: {string} = {}

        for _, descendant in ipairs(descendants) do
            -- Small check to ensure it's an instance, GetDescendants should only return instances though.
            if typeof(descendant) == "Instance" then
                table.insert(descendantPaths, descendant:GetFullName())
            end
        end

        local HttpService = game:GetService("HttpService")
        local jsonEncodedDescendantPaths = HttpService:JSONEncode(descendantPaths)

        return jsonEncodedDescendantPaths -- This will be the actual data returned on success
    end)

    if success then
        if type(resultOrError) == "string" and (string.find(resultOrError, "Instance not found") or string.find(resultOrError, "is required")) then
            -- This was an error string returned from within the pcall (instance not found or invalid args)
            local error_type = "InvalidArguments"
            if string.find(resultOrError, "Instance not found") then error_type = "InstanceNotFound" end
            return ToolHelpers.FormatErrorResult(resultOrError, {error_type = error_type})
        else
            -- Successful execution, resultOrError is the JSON string of descendant paths
            -- Manually construct the success response structure
            return { content = { { type = "text", text = resultOrError } }, isError = false }
        end
    else
        -- This is an error from the pcall itself (e.g. HttpService not available, or other script error)
        local err_msg = "Internal error in GetDescendantsOfInstance: " .. tostring(resultOrError)
        return ToolHelpers.FormatErrorResult(err_msg, {internal_error_details = tostring(resultOrError), is_luau_error = true})
    end
end

return execute
