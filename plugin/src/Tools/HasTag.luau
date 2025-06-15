-- HasTag.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local CollectionService = game:GetService("CollectionService")

local function execute(args)
    local success, pcall_result = pcall(function()
        local instancePath = args.instance_path
        local tagName = args.tag_name

        if not instancePath or type(instancePath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'instance_path' is required and must be a string.")
        end
        if not tagName or type(tagName) ~= "string" or tagName == "" then
            return ToolHelpers.FormatErrorResult("'tag_name' is required and must be a non-empty string.")
        end

        local instance, err = ToolHelpers.FindInstanceByPath(instancePath)
        if not instance then
            return ToolHelpers.FormatErrorResult("Failed to find instance at path: " .. instancePath .. ". " .. (err or ""))
        end

        local hasTag = CollectionService:HasTag(instance, tagName)

        return ToolHelpers.FormatSuccessResult({
            message = ("Instance %s %s the tag '%s'."):format(instancePath, hasTag and "has" or "does not have", tagName),
            instance_path = instancePath,
            tag_name = tagName,
            has_tag = hasTag
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in HasTag: " .. tostring(pcall_result))
    end
end

return execute
