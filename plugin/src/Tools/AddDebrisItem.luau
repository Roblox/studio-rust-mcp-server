-- AddDebrisItem.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local DebrisService = ToolHelpers.GetDebrisService()

local function execute(args: Types.AddDebrisItemArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local instancePath = args.instance_path
        local lifetime = args.lifetime

        if not instancePath or type(instancePath) ~= "string" then
            return "'instance_path' is required and must be a string."
        end
        if not lifetime or type(lifetime) ~= "number" or lifetime < 0 then
            return "'lifetime' is required and must be a non-negative number."
        end

        local instance, err = ToolHelpers.FindInstanceByPath(instancePath)
        if not instance then
            return ("Failed to find instance at path: %s. %s"):format(instancePath, err or "Unknown error")
        end

        if instance == workspace or instance:IsA("ServiceProvider") then
             return ("Cannot add core services or the workspace root to Debris: %s"):format(instancePath)
        end

        DebrisService:AddItem(instance, lifetime)

        local resultData: Types.AddDebrisItemResultData = {
            message = ("Instance %s added to Debris with a lifetime of %.2f seconds."):format(instancePath, lifetime),
            instance_path = instancePath,
            lifetime = lifetime,
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
        return ToolHelpers.FormatErrorResult("Internal error in AddDebrisItem: " .. tostring(resultOrError))
    end
end

return execute
