-- GetChildrenOfInstance.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)

local function execute(args)
    local success, pcall_result = pcall(function()
        local instancePath = args.instance_path

        if not instancePath or type(instancePath) ~= "string" or instancePath == "" then
            return ToolHelpers.FormatErrorResult("'instance_path' is required and must be a non-empty string.")
        end

        local instance, err = ToolHelpers.FindInstanceByPath(instancePath)
        if not instance then
            return ToolHelpers.FormatErrorResult(("Instance not found at path: %s. %s"):format(instancePath, err or ""))
        end

        local children = instance:GetChildren()
        local childrenPaths = {}

        for _, child in ipairs(children) do
            table.insert(childrenPaths, child:GetFullName())
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Found %d children for instance %s."):format(#childrenPaths, instancePath),
            instance_path = instancePath,
            children_paths = childrenPaths
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in GetChildrenOfInstance: " .. tostring(pcall_result))
    end
end

return execute
