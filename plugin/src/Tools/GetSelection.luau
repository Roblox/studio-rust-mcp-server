-- GetSelection.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local Selection = game:GetService("Selection")

local function execute(args: Types.GetSelectionArgs) -- Type annotation added, args currently unused
    local success, resultOrError = pcall(function()
        local selectedObjects = Selection:Get()
        local resultsInfo: {Types.InstanceInfo} = {}

        for _, instance in ipairs(selectedObjects) do
            table.insert(resultsInfo, {
                name = instance.Name,
                path = instance:GetFullName(),
                class_name = instance.ClassName,
            })
        end

        local resultData: Types.GetSelectionResultData = {
            selected_instances = resultsInfo,
        }
        return resultData
    end)

    if success then
        -- GetSelection's core logic should not return an error string directly
        return ToolHelpers.FormatSuccessResult(resultOrError)
    else
        return ToolHelpers.FormatErrorResult("Internal error in GetSelection: " .. tostring(resultOrError))
    end
end

return execute
