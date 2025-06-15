-- IsMouseButtonDown.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local UserInputService = game:GetService("UserInputService")

local function execute(args)
    local success, pcall_result = pcall(function()
        local mouseButtonString = args.mouse_button_string -- e.g., "Enum.UserInputType.MouseButton1" or "MouseButton1"

        if not mouseButtonString or type(mouseButtonString) ~= "string" then
            return ToolHelpers.FormatErrorResult("'mouse_button_string' is required (e.g., 'MouseButton1', 'Enum.UserInputType.MouseButton2').")
        end

        if not UserInputService then
            return ToolHelpers.FormatErrorResult("UserInputService not available in this context.")
        end

        local mouseButtonEnum
        if string.sub(mouseButtonString, 1, 5) == "Enum." then
            local parsedEnum, err = ToolHelpers.StringToEnum(mouseButtonString)
            if not parsedEnum then
                return ToolHelpers.FormatErrorResult("Invalid UserInputType enum string for mouse button: " .. mouseButtonString .. ". " .. (err or ""))
            end
            -- Check if it's actually a mouse button type
            if parsedEnum.EnumType ~= Enum.UserInputType or not string.match(parsedEnum.Name, "MouseButton") then
                 return ToolHelpers.FormatErrorResult("Provided enum string is not a valid mouse button UserInputType: " .. mouseButtonString)
            end
            mouseButtonEnum = parsedEnum
        else
            -- Try to find UserInputType directly
            if Enum.UserInputType[mouseButtonString] and string.match(Enum.UserInputType[mouseButtonString].Name, "MouseButton") then
                mouseButtonEnum = Enum.UserInputType[mouseButtonString]
            else
                return ToolHelpers.FormatErrorResult("Invalid mouse button string: " .. mouseButtonString .. ". Use full Enum path or valid short name like 'MouseButton1'.")
            end
        end

        if not mouseButtonEnum then
            return ToolHelpers.FormatErrorResult("Could not determine UserInputType for mouse button from: " .. mouseButtonString)
        end

        local isDown = UserInputService:IsMouseButtonPressed(mouseButtonEnum)

        return ToolHelpers.FormatSuccessResult({
            message = ("Mouse button %s is currently %s."):format(tostring(mouseButtonEnum), isDown and "pressed" or "not pressed"),
            mouse_button = tostring(mouseButtonEnum),
            is_down = isDown
        })
    end)

    if success then
        return pcall_result
    else
        if string.find(tostring(pcall_result), "UserInputService not available") or string.find(tostring(pcall_result), "Invalid UserInputType") then
             return ToolHelpers.FormatErrorResult(tostring(pcall_result))
        end
        return ToolHelpers.FormatErrorResult("Internal error in IsMouseButtonDown: " .. tostring(pcall_result))
    end
end

return execute
