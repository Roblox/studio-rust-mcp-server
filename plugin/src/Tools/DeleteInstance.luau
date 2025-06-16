-- DeleteInstance.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added

local function execute(args: Types.DeleteInstanceArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local path = args.path

        if not path or type(path) ~= "string" then
            return "'path' is required and must be a string." -- Return error string
        end

        local instance, err = ToolHelpers.FindInstanceByPath(path)
        if not instance then
            -- Return specific result data for path not found
            local resultData: Types.DeleteInstanceResultData = {
                message = "Instance at path '" .. path .. "' not found, presumed already deleted. " .. (err or ""),
                deleted_path = path, -- Path that was intended for deletion
                path_not_found = path,
            }
            return resultData -- This will be handled by FormatSuccessResult
        end

        if instance == workspace or instance:IsA("ServiceProvider") or instance:IsA("Terrain") then
             return ("Cannot delete core services, the workspace root, or Terrain: %s"):format(path) -- Return error string
        end

        local destroySuccess, destroyError = pcall(instance.Destroy, instance)

        if not destroySuccess then
            return ("Failed to delete instance at path '%s': %s"):format(path, tostring(destroyError)) -- Return error string
        end

        local resultData: Types.DeleteInstanceResultData = {
            message = ("Successfully deleted instance at path %s."):format(path),
            deleted_path = path,
        }
        return resultData
    end)

    if success then
        if type(resultOrError) == "string" then -- Error string returned from pcall function
            return ToolHelpers.FormatErrorResult(resultOrError)
        else -- Data table returned
            return ToolHelpers.FormatSuccessResult(resultOrError)
        end
    else
        return ToolHelpers.FormatErrorResult("Internal error in DeleteInstance: " .. tostring(resultOrError))
    end
end

return execute
