-- GetInstancesWithTag.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local CollectionService = game:GetService("CollectionService")

local function execute(args: Types.GetInstancesWithTagArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local tagName = args.tag_name

        if not tagName or type(tagName) ~= "string" or tagName == "" then
            return "'tag_name' is required and must be a non-empty string."
        end

        local taggedInstances = CollectionService:GetTagged(tagName)
        local instancesInfo: {Types.InstanceInfo} = {}

        for _, instance in ipairs(taggedInstances) do
            if instance and instance.Parent ~= nil then -- Ensure instance is valid and in DataModel
                table.insert(instancesInfo, {
                    name = instance.Name,
                    path = instance:GetFullName(),
                    class_name = instance.ClassName,
                })
            end
        end

        local resultData: Types.GetInstancesWithTagResultData = {
            tag_name = tagName,
            instances = instancesInfo,
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
        return ToolHelpers.FormatErrorResult("Internal error in GetInstancesWithTag: " .. tostring(resultOrError))
    end
end

return execute
