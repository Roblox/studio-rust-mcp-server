-- GetMousePosition.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local UserInputService = game:GetService("UserInputService")

local function execute(args)
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
            viewport_size = {x = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 0, y = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 0}
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
