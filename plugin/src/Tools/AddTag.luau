-- AddTag.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local CollectionService = ToolHelpers.GetCollectionService()

local function execute(args: Types.AddTagArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local instancePath = args.instance_path
        local tagName = args.tag_name

        if not instancePath or type(instancePath) ~= "string" then
            return "'instance_path' is required and must be a string." -- Return error string
        end
        if not tagName or type(tagName) ~= "string" or tagName == "" then
            return "'tag_name' is required and must be a non-empty string." -- Return error string
        end

        local instance, err = ToolHelpers.FindInstanceByPath(instancePath)
        if not instance then
            return ("Failed to find instance at path: %s. %s"):format(instancePath, err or "Unknown error") -- Return error string
        end

        CollectionService:AddTag(instance, tagName)

        -- Return AddTagResultData table
        local resultData: Types.AddTagResultData = {
            message = ("Successfully added tag '%s' to instance '%s'."):format(tagName, instance:GetFullName()), -- Use instance:GetFullName() for consistency
            instance_path = instance:GetFullName(), -- Use instance:GetFullName()
            tag_name = tagName,
        }
        return resultData
    end)

    if success then
        -- Pass the XXXResultData to FormatSuccessResult
        return ToolHelpers.FormatSuccessResult(resultOrError)
    else
        -- Pass the error message string to FormatErrorResult
        return ToolHelpers.FormatErrorResult("Internal error in AddTag: " .. tostring(resultOrError))
    end
end

return execute
