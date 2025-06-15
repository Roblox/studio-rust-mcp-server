-- IsKeyDown.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local UserInputService = game:GetService("UserInputService")

local function execute(args)
    local success, pcall_result = pcall(function()
        local keyCodeString = args.key_code_string -- e.g., "Enum.KeyCode.E" or just "E"

        if not keyCodeString or type(keyCodeString) ~= "string" then
            return ToolHelpers.FormatErrorResult("'key_code_string' is required and must be a string (e.g., 'E', 'Space', 'Enum.KeyCode.LeftShift').")
        end

        if not UserInputService then
            return ToolHelpers.FormatErrorResult("UserInputService not available in this context.")
        end

        local keyCodeEnum
        if string.sub(keyCodeString, 1, 5) == "Enum." then
            local parsedEnum, err = ToolHelpers.StringToEnum(keyCodeString)
            if not parsedEnum then
                 return ToolHelpers.FormatErrorResult("Invalid KeyCode enum string: " .. keyCodeString .. ". " .. (err or ""))
            end
            if parsedEnum.EnumType ~= Enum.KeyCode then
                return ToolHelpers.FormatErrorResult("Provided enum string is not a KeyCode: " .. keyCodeString)
            end
            keyCodeEnum = parsedEnum
        else
            -- Try to find KeyCode directly if short form like "E" is used
            if Enum.KeyCode[keyCodeString] then
                keyCodeEnum = Enum.KeyCode[keyCodeString]
            else
                return ToolHelpers.FormatErrorResult("Invalid KeyCode string: " .. keyCodeString .. ". Use full Enum path or valid short name.")
            end
        end

        if not keyCodeEnum then
             return ToolHelpers.FormatErrorResult("Could not determine KeyCode from: " .. keyCodeString)
        end

        local isDown = UserInputService:IsKeyDown(keyCodeEnum)

        return ToolHelpers.FormatSuccessResult({
            message = ("Key %s is currently %s."):format(tostring(keyCodeEnum), isDown and "pressed" or "not pressed"),
            key_code = tostring(keyCodeEnum),
            is_down = isDown
        })
    end)

    if success then
        return pcall_result
    else
        if string.find(tostring(pcall_result), "UserInputService not available") or string.find(tostring(pcall_result), "Invalid KeyCode") then
             return ToolHelpers.FormatErrorResult(tostring(pcall_result))
        end
        return ToolHelpers.FormatErrorResult("Internal error in IsKeyDown: " .. tostring(pcall_result))
    end
end

return execute
