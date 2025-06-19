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

        if instance == ToolHelpers.GetWorkspaceService() or instance:IsA("ServiceProvider") or instance:IsA("Terrain") then
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

    local finalResult
    if success then
		if type(resultOrError) == "string" then -- An error message string was returned from the pcall'd function
            finalResult = ToolHelpers.FormatErrorResult(resultOrError)
		elseif type(resultOrError) == "table" then -- A resultData table was returned from the pcall'd function
			-- This handles both genuine success payloads and "path_not_found" custom payloads.
            finalResult = ToolHelpers.FormatSuccessResult(resultOrError)
		elseif resultOrError == nil then -- Should ideally not be reached if pcall'd function always returns a value
			finalResult = ToolHelpers.FormatErrorResult("DeleteInstance: pcall succeeded but returned nil unexpectedly.")
		else -- Catch any other unexpected types returned by the pcall'd function
			finalResult = ToolHelpers.FormatErrorResult("DeleteInstance: Unexpected result type from pcall: " .. type(resultOrError))
        end
    else
		-- pcall itself failed
        finalResult = ToolHelpers.FormatErrorResult("Internal error in DeleteInstance: " .. tostring(resultOrError))
    end
    return finalResult
end

return execute
