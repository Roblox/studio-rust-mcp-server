-- GetMouseHitCFrame.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local UserInputService = ToolHelpers.GetUserInputService()

local function execute(args: Types.GetMouseHitCFrameArgs)
    -- args.camera_path is optional
    local success, pcall_result = pcall(function()
        local cameraPath = args.camera_path

        if cameraPath ~= nil and type(cameraPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'camera_path' must be a string if provided.")
        end

        if not UserInputService then
            -- This case should be rare in a Studio plugin context where UserInputService is usually available.
            return ToolHelpers.FormatErrorResult("UserInputService not available in this context.")
        end

        local cameraToUse = ToolHelpers.GetWorkspaceService().CurrentCamera
        if cameraPath then
            local foundCam, err = ToolHelpers.FindInstanceByPath(cameraPath)
            if foundCam and foundCam:IsA("Camera") then
                cameraToUse = foundCam
            else
                return ToolHelpers.FormatErrorResult(("Camera at path '%s' not found or invalid. %s"):format(cameraPath, err or "Ensure path is correct."))
            end
        end

        if not cameraToUse then
            return ToolHelpers.FormatErrorResult("No valid camera available (Workspace.CurrentCamera is nil and no valid camera_path provided).")
        end

        local mouseLocation = UserInputService:GetMouseLocation()
        local unitRay = cameraToUse:ViewportPointToRay(mouseLocation.X, mouseLocation.Y, 0)

        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        -- Example: Exclude player's character if needed
        -- local player = game:GetService("Players").LocalPlayer
        -- if player and player.Character then
        --    raycastParams.FilterDescendantsInstances = {player.Character}
        -- end

        local raycastResult = ToolHelpers.GetWorkspaceService():Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)

        if raycastResult and raycastResult.Instance then
            local hitPosition = raycastResult.Position
            local hitNormal = raycastResult.Normal
            local hitCFrame = CFrame.lookAt(hitPosition, hitPosition + hitNormal)

            return ToolHelpers.FormatSuccessResult({
                message = "Mouse hit CFrame retrieved.",
                instance_hit_path = raycastResult.Instance:GetFullName(),
                position = hitCFrame.Position, -- Pass raw Vector3
                cframe_components = hitCFrame   -- Pass raw CFrame
            })
        else
            return ToolHelpers.FormatSuccessResult({
                message = "Mouse is not currently pointing at any object in 3D space within 1000 studs, or the object is ignored by raycast.",
                instance_hit_path = nil,
                position = nil,
                cframe_components = nil
            })
        end
    end)

    if success then
        return pcall_result -- This is already a ToolHelpers formatted table
    else
        -- pcall_result contains the error message string
        return ToolHelpers.FormatErrorResult("Internal error in GetMouseHitCFrame: " .. tostring(pcall_result))
    end
end

return execute
