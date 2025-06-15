-- GetMouseHitCFrame.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local UserInputService = game:GetService("UserInputService")

local function execute(args)
    local success, pcall_result = pcall(function()
        local cameraPath = args.camera_path -- Optional

        if cameraPath ~= nil and type(cameraPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'camera_path' must be a string if provided.")
        end

        if not UserInputService then
            return ToolHelpers.FormatErrorResult("UserInputService not available in this context.")
        end

        local cameraToUse = workspace.CurrentCamera
        if cameraPath then
            local foundCam, err = ToolHelpers.FindInstanceByPath(cameraPath)
            if foundCam and foundCam:IsA("Camera") then
                cameraToUse = foundCam
            else
                return ToolHelpers.FormatErrorResult(("Camera at path '%s' not found or invalid. %s"):format(cameraPath, err or ""))
            end
        end

        if not cameraToUse then
            return ToolHelpers.FormatErrorResult("No valid camera available (Workspace.CurrentCamera is nil and no valid camera_path provided).")
        end

        local mouseLocation = UserInputService:GetMouseLocation()
        -- ViewportPointToRay takes X, Y, and an optional depth (0 is fine for mouse picking)
        local unitRay = cameraToUse:ViewportPointToRay(mouseLocation.X, mouseLocation.Y, 0)

        -- Raycast parameters: origin, direction * length, RaycastParams (optional)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        -- Potentially add items to FilterDescendantsInstances if needed, e.g., player's character, accessories.
        -- raycastParams.FilterDescendantsInstances = { game:GetService("Players").LocalPlayer.Character }

        local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams) -- 1000 is max distance

        if raycastResult then
            local hitPosition = raycastResult.Position
            local hitNormal = raycastResult.Normal
            -- Construct a CFrame. The orientation part is tricky.
            -- For many use cases, just the position is needed, or a CFrame looking from hit towards camera.
            -- A simple CFrame at the hit point with default orientation:
            -- local hitCFrame = CFrame.new(hitPosition)
            -- Or, a CFrame oriented with the surface normal:
            local hitCFrame = CFrame.lookAt(hitPosition, hitPosition + hitNormal)


            return ToolHelpers.FormatSuccessResult({
                message = "Mouse hit position retrieved.",
                instance_hit_path = raycastResult.Instance:GetFullName(),
                position = ToolHelpers.RobloxValueToJson(hitCFrame.Position), -- Just position for simplicity
                cframe = ToolHelpers.RobloxValueToJson(hitCFrame) -- Full CFrame
            })
        else
            return ToolHelpers.FormatSuccessResult({
                message = "Mouse is not pointing at any object in 3D space or object is too far.",
                instance_hit_path = nil,
                position = nil,
                cframe = nil
            })
        end
    end)

    if success then
        return pcall_result
    else
         if string.find(tostring(pcall_result), "UserInputService not available") or string.find(tostring(pcall_result), "No valid camera available") then
             return ToolHelpers.FormatErrorResult(tostring(pcall_result))
        end
        return ToolHelpers.FormatErrorResult("Internal error in GetMouseHitCFrame: " .. tostring(pcall_result))
    end
end

return execute
