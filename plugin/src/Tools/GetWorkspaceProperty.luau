-- GetWorkspaceProperty.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added

local function execute(args: Types.GetWorkspacePropertyArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local propertyName = args.property_name

        if not propertyName or type(propertyName) ~= "string" then
            return "'property_name' is required and must be a string."
        end

        local propertyValue
        local getSuccess, valueOrError = pcall(function()
            return ToolHelpers.GetWorkspaceService()[propertyName]
        end)

        if not getSuccess then
            if string.find(tostring(valueOrError), "is not a valid member of Workspace") then
                 return ("Property '%s' is not a valid member of Workspace."):format(propertyName)
            end
            return ("Failed to get Workspace property '%s': %s"):format(propertyName, tostring(valueOrError))
        end
        propertyValue = valueOrError

        local resultData: Types.GetWorkspacePropertyResultData = {
            property_name = propertyName,
            value = propertyValue, -- Raw Roblox value
        }
        return resultData
    end)

    if success then
        if type(resultOrError) == "string" then
            return ToolHelpers.FormatErrorResult(resultOrError)
        else
            return ToolHelpers.FormatSuccessResult(resultOrError)
        end
    else
        return ToolHelpers.FormatErrorResult("Internal error in GetWorkspaceProperty: " .. tostring(resultOrError))
    end
end

return execute
