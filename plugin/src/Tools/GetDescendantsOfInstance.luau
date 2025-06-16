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
        local descendantsInfo: {Types.InstanceInfo} = {}

        for _, descendant in ipairs(descendants) do
            table.insert(descendantsInfo, {
                name = descendant.Name,
                path = descendant:GetFullName(),
                class_name = descendant.ClassName,
            })
        end

        local resultData: Types.GetDescendantsOfInstanceResultData = {
            instance_path = instancePath,
            descendants = descendantsInfo,
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
        return ToolHelpers.FormatErrorResult("Internal error in GetDescendantsOfInstance: " .. tostring(resultOrError))
    end
end

return execute
