-- GetSelection.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local Selection = game:GetService("Selection")

local function execute(args: Types.GetSelectionArgs) -- Type annotation added, args currently unused
    local success, resultOrError = pcall(function()
        local selectedObjects = Selection:Get()
        local selectedPaths: {string} = {}

        for _, instance in ipairs(selectedObjects) do
            if typeof(instance) == "Instance" then -- Ensure it's an instance before calling GetFullName
                table.insert(selectedPaths, instance:GetFullName())
            end
        end

        local HttpService = game:GetService("HttpService")
        local jsonEncodedSelectedPaths = HttpService:JSONEncode(selectedPaths)

        return jsonEncodedSelectedPaths -- This will be the actual data returned on success
    end)

    if success then
        -- Successful execution, resultOrError is the JSON string of selected paths
        -- Manually construct the success response structure
        return { content = { { type = "text", text = resultOrError } }, isError = false }
    else
        -- This is an error from the pcall itself (e.g. HttpService not available, or other script error)
        local err_msg = "Internal error in GetSelection: " .. tostring(resultOrError)
        return ToolHelpers.FormatErrorResult(err_msg, {internal_error_details = tostring(resultOrError), is_luau_error = true})
    end
end

return execute
