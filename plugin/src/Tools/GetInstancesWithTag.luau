-- GetInstancesWithTag.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local CollectionService = game:GetService("CollectionService")

local function execute(args)
    local success, pcall_result = pcall(function()
        local tagName = args.tag_name

        if not tagName or type(tagName) ~= "string" or tagName == "" then
            return ToolHelpers.FormatErrorResult("'tag_name' is required and must be a non-empty string.")
        end

        local instances = CollectionService:GetTagged(tagName)
        local instancePaths = {}

        for _, instance in ipairs(instances) do
            if instance then -- Make sure instance hasn't been destroyed since tagging
                table.insert(instancePaths, instance:GetFullName())
            end
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Found %d instance(s) with tag '%s'."):format(#instancePaths, tagName),
            tag_name = tagName,
            instance_paths = instancePaths
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in GetInstancesWithTag: " .. tostring(pcall_result))
    end
end

return execute
