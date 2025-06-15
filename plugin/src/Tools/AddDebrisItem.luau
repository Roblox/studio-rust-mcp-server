-- AddDebrisItem.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local DebrisService = game:GetService("Debris")

local function execute(args)
    local success, pcall_result = pcall(function()
        local instancePath = args.instance_path
        local lifetime = args.lifetime

        if not instancePath or type(instancePath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'instance_path' is required and must be a string.")
        end
        if not lifetime or type(lifetime) ~= "number" or lifetime < 0 then
            return ToolHelpers.FormatErrorResult("'lifetime' is required and must be a non-negative number.")
        end

        local instance, err = ToolHelpers.FindInstanceByPath(instancePath)
        if not instance then
            return ToolHelpers.FormatErrorResult("Failed to find instance at path: " .. instancePath .. ". " .. (err or ""))
        end

        -- Cannot add services or workspace root to Debris
        if instance == workspace or instance:IsA("ServiceProvider") then
             return ToolHelpers.FormatErrorResult("Cannot add core services or the workspace root to Debris: " .. instancePath)
        end

        DebrisService:AddItem(instance, lifetime)

        return ToolHelpers.FormatSuccessResult({
            message = ("Instance %s added to Debris with a lifetime of %.2f seconds."):format(instancePath, lifetime),
            instance_path = instancePath,
            lifetime = lifetime
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in AddDebrisItem: " .. tostring(pcall_result))
    end
end

return execute
