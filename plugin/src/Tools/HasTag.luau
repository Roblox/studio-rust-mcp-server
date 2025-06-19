-- HasTag.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local CollectionService = game:GetService("CollectionService")

local function execute(args: Types.HasTagArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local instancePath = args.instance_path
        local tagName = args.tag_name

        if not instancePath or type(instancePath) ~= "string" then
            return "'instance_path' is required and must be a string."
        end
        if not tagName or type(tagName) ~= "string" or tagName == "" then
            return "'tag_name' is required and must be a non-empty string."
        end

        local instance, err = ToolHelpers.FindInstanceByPath(instancePath)
        if not instance then
            return ("Failed to find instance at path: %s. %s"):format(instancePath, err or "Unknown error")
        end

        local hasTag = CollectionService:HasTag(instance, tagName)
        local resultData: Types.HasTagResultData = {
            instance_path = instancePath,
            tag_name = tagName,
            has_tag = hasTag,
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
        return ToolHelpers.FormatErrorResult("Internal error in HasTag: " .. tostring(resultOrError))
    end
end

return execute
