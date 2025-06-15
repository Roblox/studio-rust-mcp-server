-- GetDescendantsOfInstance.luau
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

        local descendants = instance:GetDescendants()
        local descendantPaths = {}

        for _, descendant in ipairs(descendants) do
            table.insert(descendantPaths, descendant:GetFullName())
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Found %d descendants for instance %s."):format(#descendantPaths, instancePath),
            instance_path = instancePath,
            descendant_paths = descendantPaths
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in GetDescendantsOfInstance: " .. tostring(pcall_result))
    end
end

return execute
