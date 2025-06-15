-- DeleteInstance.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)

local function execute(args)
    local success, result = pcall(function()
        local path = args.path

        if not path or type(path) ~= "string" then
            return ToolHelpers.FormatErrorResult("'path' is required and must be a string.")
        end

        local instance, err = ToolHelpers.FindInstanceByPath(path)
        if not instance then
            -- If instance already doesn't exist, consider it a success for deletion.
            return ToolHelpers.FormatSuccessResult({
                message = "Instance at path '" .. path .. "' not found, presumed already deleted. " .. (err or "")
            })
        end

        -- Check if the instance can be deleted (e.g. not a service)
        if instance == workspace or instance:IsA("ServiceProvider") then
             return ToolHelpers.FormatErrorResult("Cannot delete core services or the workspace root: " .. path)
        end

        local destroySuccess, destroyError = pcall(function()
            instance:Destroy()
        end)

        if not destroySuccess then
            return ToolHelpers.FormatErrorResult(("Failed to delete instance at path '%s': %s"):format(path, tostring(destroyError)))
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully deleted instance at path %s."):format(path)
        })
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in DeleteInstance: " .. tostring(result))
    end
end

return execute
