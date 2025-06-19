-- GetMousePosition.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local UserInputService = ToolHelpers.GetUserInputService()

local function execute(args: Types.GetMousePositionArgs)
    -- This tool typically doesn't take arguments, but args table is passed anyway.
    local success, pcall_result = pcall(function()
        if not UserInputService then
            -- This primarily occurs if the environment is not a client or Studio plugin context.
            return ToolHelpers.FormatErrorResult("UserInputService not available in this context.")
        end

        local mouseLocation = UserInputService:GetMouseLocation()

        return ToolHelpers.FormatSuccessResult({
            message = "Successfully retrieved mouse 2D position.",
            x = mouseLocation.X,
            y = mouseLocation.Y,
            viewport_size = {x = ToolHelpers.GetWorkspaceService().CurrentCamera and ToolHelpers.GetWorkspaceService().CurrentCamera.ViewportSize.X or 0, y = ToolHelpers.GetWorkspaceService().CurrentCamera and ToolHelpers.GetWorkspaceService().CurrentCamera.ViewportSize.Y or 0}
        })
    end)

    if success then
        return pcall_result -- This is already a ToolHelpers formatted table
    else
        -- pcall_result contains the error message string
        return ToolHelpers.FormatErrorResult("Internal error in GetMousePosition: " .. tostring(pcall_result))
    end
end

return execute
