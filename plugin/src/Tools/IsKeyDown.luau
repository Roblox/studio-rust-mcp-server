-- IsKeyDown.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local UserInputService = ToolHelpers.GetUserInputService()

local function execute(args: Types.IsKeyDownArgs)
    -- Arguments are expected directly on args table
    local success, pcall_result = pcall(function()
        local keyCodeString = args.key_code_string -- e.g., "E", "Space", "LeftShift"

        if not keyCodeString or type(keyCodeString) ~= "string" then
            return ToolHelpers.FormatErrorResult("'key_code_string' is required and must be a string (e.g., 'E', 'Space', 'LeftShift').")
        end

        if not UserInputService then
            return ToolHelpers.FormatErrorResult("UserInputService not available in this context.")
        end

        local keyCodeEnum = Enum.KeyCode[keyCodeString]

        -- Attempt to handle if user provides "Enum.KeyCode.E" format
        if not keyCodeEnum and string.match(keyCodeString, "^Enum%.KeyCode%.(.+)$") then
            local actualKey = string.match(keyCodeString, "^Enum%.KeyCode%.(.+)$")
            if actualKey and Enum.KeyCode[actualKey] then
                keyCodeEnum = Enum.KeyCode[actualKey]
            end
        end

        if not keyCodeEnum or typeof(keyCodeEnum) ~= "EnumItem" then -- Validate it's an actual EnumItem
             return ToolHelpers.FormatErrorResult(("Invalid or unsupported KeyCode string: '%s'. Ensure it's a direct member of Enum.KeyCode (e.g., 'LeftShift', not 'Enum.KeyCode.LeftShift' directly if using short names)."):format(keyCodeString))
        end

        local isDown = UserInputService:IsKeyDown(keyCodeEnum)

        return ToolHelpers.FormatSuccessResult({
            message = ("Key %s is currently %s."):format(tostring(keyCodeEnum), isDown and "pressed" or "not pressed"),
            key_code_used = tostring(keyCodeEnum), -- Use the resolved enum string
            is_down = isDown
        })
    end)

    if success then
        return pcall_result -- This is already a ToolHelpers formatted table
    else
        -- pcall_result contains the error message string
        return ToolHelpers.FormatErrorResult("Internal error in IsKeyDown: " .. tostring(pcall_result))
    end
end

return execute
