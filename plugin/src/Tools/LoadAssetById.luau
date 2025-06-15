-- LoadAssetById.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local InsertService = game:GetService("InsertService")

local function execute(args)
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

        -- Check if InsertService can be used (e.g. in Studio or specific server contexts)
        -- This check might be too restrictive or not necessary depending on environment.
        -- For now, assume it is available if the service itself is present.

        local parentInstance = workspace -- Default to workspace
        if parentPath then
            local foundParent, err = ToolHelpers.FindInstanceByPath(parentPath)
            if foundParent then
                parentInstance = foundParent
            else
                print(("LoadAssetById: Parent path '%s' not found (%s), defaulting to Workspace."):format(parentPath, err or ""))
            end
        end

        local assetModelContainer
        local loadSuccess, loadErrorOrModel = pcall(InsertService.LoadAsset, InsertService, assetId)

        if not loadSuccess then
            return ToolHelpers.FormatErrorResult(("Failed to load asset ID %d: %s"):format(assetId, tostring(loadErrorOrModel)))
        end
        assetModelContainer = loadErrorOrModel -- This is typically a Model instance

        if not assetModelContainer or not assetModelContainer:IsA("Model") then
            -- Sometimes LoadAsset might return other things or fail silently for certain asset types
            -- For simplicity, we expect a Model. If not, try to parent it directly.
             if assetModelContainer and assetModelContainer:IsA("Instance") then
                 assetModelContainer.Parent = parentInstance
                 if desiredName then assetModelContainer.Name = desiredName end
                 return ToolHelpers.FormatSuccessResult({
                    message = ("Asset ID %d loaded. It was not a Model, but an Instance of type %s. Parented to %s."):format(assetId, assetModelContainer:GetClass(), parentInstance:GetFullName()),
                    asset_path = assetModelContainer:GetFullName(),
                    asset_id = assetId,
                    asset_type = assetModelContainer:GetClass()
                })
             else
                return ToolHelpers.FormatErrorResult(("Asset ID %d did not load as a Model or Instance, or failed to load correctly."):format(assetId))
             end
        end

        -- If it's a Model, and it might contain multiple items, often it's a good idea to
        -- take the first child if it's the primary asset, or just parent the whole model.
        -- For this tool, we'll parent the container model.
        assetModelContainer.Parent = parentInstance
        if desiredName then
            assetModelContainer.Name = desiredName
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Asset ID %d loaded successfully as Model '%s' under %s."):format(assetId, assetModelContainer.Name, parentInstance:GetFullName()),
            asset_path = assetModelContainer:GetFullName(),
            asset_id = assetId,
            asset_type = assetModelContainer:GetClass()
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in LoadAssetById: " .. tostring(pcall_result))
    end
end

return execute
