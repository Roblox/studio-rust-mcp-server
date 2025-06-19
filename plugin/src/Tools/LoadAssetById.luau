-- LoadAssetById.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local InsertService = ToolHelpers.GetInsertService()

local function execute(args: Types.LoadAssetByIdArgs)
    -- Arguments are expected directly on args table
    local success, pcall_result = pcall(function()
        local assetId = args.asset_id
        local parentPath = args.parent_path -- Optional
        local desiredName = args.desired_name -- Optional

        if not assetId or type(assetId) ~= "number" or assetId <= 0 then
            return ToolHelpers.FormatErrorResult("'asset_id' is required and must be a positive number.")
        end
        if parentPath ~= nil and type(parentPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'parent_path' must be a string if provided.")
        end
        if desiredName ~= nil and type(desiredName) ~= "string" then
            return ToolHelpers.FormatErrorResult("'desired_name' must be a string if provided.")
        end

        if not InsertService then
            return ToolHelpers.FormatErrorResult("InsertService not available in this context.")
        end

        local parentInstance = ToolHelpers.GetWorkspaceService() -- Default to workspace
        if parentPath then
            local foundParent, err = ToolHelpers.FindInstanceByPath(parentPath)
            if foundParent then
                parentInstance = foundParent
            else
                -- If a parent_path is specified but not found, it should be an error.
                return ToolHelpers.FormatErrorResult(("Specified 'parent_path' (%s) not found. Error: %s"):format(parentPath, err or "Not found."))
            end
        end

        local loadedAsset -- This is usually a Model
        local loadSuccess, loadResult = pcall(InsertService.LoadAsset, InsertService, assetId)

        if not loadSuccess then
            return ToolHelpers.FormatErrorResult(("InsertService:LoadAsset failed for asset ID %d: %s"):format(assetId, tostring(loadResult)))
        end

        loadedAsset = loadResult

        if not loadedAsset or not loadedAsset:IsA("Instance") then
             return ToolHelpers.FormatErrorResult(("Asset ID %d did not load as a valid Instance, or failed to load correctly. Loaded type: %s"):format(assetId, typeof(loadedAsset)))
        end

        -- Parent the loaded asset
        loadedAsset.Parent = parentInstance
        if desiredName then
            loadedAsset.Name = desiredName
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Asset ID %d loaded as '%s' (type: %s) under %s."):format(assetId, loadedAsset.Name, loadedAsset:GetClass(), parentInstance:GetFullName()),
            asset_path = loadedAsset:GetFullName(),
            asset_id = assetId,
            asset_class_name = loadedAsset:GetClass()
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in LoadAssetById: " .. tostring(pcall_result))
    end
end

return execute
