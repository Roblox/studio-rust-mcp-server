-- IsMouseButtonDown.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local UserInputService = ToolHelpers.GetUserInputService()

local function execute(args: Types.IsMouseButtonDownArgs)
    -- Arguments are expected directly on args table
    local success, pcall_result = pcall(function()
        local mouseButtonString = args.mouse_button_string -- e.g., "MouseButton1", "MouseButton2"

        if not mouseButtonString or type(mouseButtonString) ~= "string" then
            return ToolHelpers.FormatErrorResult("'mouse_button_string' is required (e.g., 'MouseButton1', 'MouseButton2').")
        end

        if not UserInputService then
            return ToolHelpers.FormatErrorResult("UserInputService not available in this context.")
        end

        local mouseButtonEnum = Enum.UserInputType[mouseButtonString]

        -- Attempt to handle if user provides "Enum.UserInputType.MouseButton1" format
        if not mouseButtonEnum and string.match(mouseButtonString, "^Enum%.UserInputType%.(.+)$") then
            local actualButton = string.match(mouseButtonString, "^Enum%.UserInputType%.(.+)$")
            if actualButton and Enum.UserInputType[actualButton] then
                mouseButtonEnum = Enum.UserInputType[actualButton]
            end
        end

        -- Validate that the resolved enum is indeed a mouse button
        if not mouseButtonEnum or typeof(mouseButtonEnum) ~= "EnumItem" or not string.match(mouseButtonEnum.Name, "MouseButton") then
             return ToolHelpers.FormatErrorResult(("Invalid or unsupported mouse button string: '%s'. Must correspond to a valid mouse button UserInputType (e.g., 'MouseButton1')."):format(mouseButtonString))
        end

        -- Use IsMouseButtonDown for state checking
        local isDown = UserInputService:IsMouseButtonDown(mouseButtonEnum)

        return ToolHelpers.FormatSuccessResult({
            message = ("Mouse button %s is currently %s."):format(tostring(mouseButtonEnum), isDown and "pressed" or "not pressed"),
            mouse_button_checked = tostring(mouseButtonEnum),
            is_down = isDown
        })
    end)

    if success then
        return pcall_result -- This is already a ToolHelpers formatted table
    else
        -- pcall_result contains the error message string
        return ToolHelpers.FormatErrorResult("Internal error in IsMouseButtonDown: " .. tostring(pcall_result))
    end
end

return execute
