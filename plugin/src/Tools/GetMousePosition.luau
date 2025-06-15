-- GetMousePosition.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local UserInputService = game:GetService("UserInputService")

local function execute(args)
    local success, pcall_result = pcall(function()
        -- This tool is client-side or needs a mechanism to get client input.
        -- The MCP server architecture determines how this is bridged if called from a server context.
        -- For now, we directly attempt to use UserInputService.

        if not UserInputService then
            return ToolHelpers.FormatErrorResult("UserInputService not available in this context.")
        end

        local mouseLocation = UserInputService:GetMouseLocation()

        return ToolHelpers.FormatSuccessResult({
            message = "Successfully retrieved mouse position.",
            x = mouseLocation.X,
            y = mouseLocation.Y
        })
    end)

    if success then
        return pcall_result
    else
        -- Catch errors like UserInputService not being available if run in a pure server script without bridging
        if string.find(tostring(pcall_result), "UserInputService not available") then
             return ToolHelpers.FormatErrorResult(tostring(pcall_result))
        end
        return ToolHelpers.FormatErrorResult("Internal error in GetMousePosition: " .. tostring(pcall_result))
    end
end

return execute
