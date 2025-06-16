-- GetChildrenOfInstance.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added

local function execute(args: Types.GetChildrenOfInstanceArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local instancePath = args.instance_path

        if not instancePath or type(instancePath) ~= "string" or instancePath == "" then
            return "'instance_path' is required and must be a non-empty string."
        end

        local instance, err = ToolHelpers.FindInstanceByPath(instancePath)
        if not instance then
            return ("Instance not found at path: %s. %s"):format(instancePath, err or "Unknown error")
        end

        local children = instance:GetChildren()
        local childrenInfo: {Types.InstanceInfo} = {}

        for _, child in ipairs(children) do
            table.insert(childrenInfo, {
                name = child.Name,
                path = child:GetFullName(),
                class_name = child.ClassName,
            })
        end

        local resultData: Types.GetChildrenOfInstanceResultData = {
            instance_path = instancePath,
            children = childrenInfo,
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
        return ToolHelpers.FormatErrorResult("Internal error in GetChildrenOfInstance: " .. tostring(resultOrError))
    end
end

return execute
