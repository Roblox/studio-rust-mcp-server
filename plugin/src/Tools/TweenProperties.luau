-- TweenProperties.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local TweenService = game:GetService("TweenService")

local function execute(args)
    local success, pcall_result = pcall(function()
        local instancePath = args.instance_path
        local duration = args.duration
        local easingStyleStr = args.easing_style
        local easingDirectionStr = args.easing_direction
        local propertiesToTweenJson = args.properties_to_tween

        -- Optional params
        local repeatCount = args.repeat_count -- nil if not provided
        local reverses = args.reverses       -- nil if not provided
        local delayTime = args.delay_time     -- nil if not provided

        if not instancePath or type(instancePath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'instance_path' is required and must be a string.")
        end
        if not duration or type(duration) ~= "number" or duration <= 0 then
            return ToolHelpers.FormatErrorResult("'duration' must be a positive number.")
        end
        if not easingStyleStr or type(easingStyleStr) ~= "string" then
            return ToolHelpers.FormatErrorResult("'easing_style' (Enum.EasingStyle) is required and must be a string.")
        end
        if not easingDirectionStr or type(easingDirectionStr) ~= "string" then
            return ToolHelpers.FormatErrorResult("'easing_direction' (Enum.EasingDirection) is required and must be a string.")
        end
        if not propertiesToTweenJson or type(propertiesToTweenJson) ~= "table" then
            return ToolHelpers.FormatErrorResult("'properties_to_tween' is required and must be a table.")
        end

        local instance, err = ToolHelpers.FindInstanceByPath(instancePath)
        if not instance then
            return ToolHelpers.FormatErrorResult("Failed to find instance at path: " .. instancePath .. ". " .. (err or ""))
        end

        local easingStyle = Enum.EasingStyle[easingStyleStr]
        if not easingStyle then
            return ToolHelpers.FormatErrorResult("Invalid EasingStyle: " .. easingStyleStr)
        end
        local easingDirection = Enum.EasingDirection[easingDirectionStr]
        if not easingDirection then
            return ToolHelpers.FormatErrorResult("Invalid EasingDirection: " .. easingDirectionStr)
        end

        local tweenInfo = TweenInfo.new(
            duration,
            easingStyle,
            easingDirection,
            repeatCount or 0,
            reverses or false,
            delayTime or 0
        )

        local propertiesGoal = {}
        for propName, propValueJson in pairs(propertiesToTweenJson) do
            propertiesGoal[propName] = ToolHelpers.JsonToRobloxValue(propValueJson)
            if propertiesGoal[propName] == nil and propValueJson ~= nil then
                 -- If JsonToRobloxValue returned nil for a non-nil input, it might be an invalid complex type format
                print(("TweenProperties: Warning - property '%s' received a nil value after conversion from JSON. Original JSON: %s"):format(propName, ToolHelpers.SafeJsonEncode(propValueJson) or "encode_failed"))
                -- Potentially return an error here if strictness is required
                -- return ToolHelpers.FormatErrorResult(("Invalid format for property '%s'. Could not convert from JSON."):format(propName))
            end
        end

        if next(propertiesGoal) == nil then
            return ToolHelpers.FormatErrorResult("No valid properties to tween after conversion.")
        end

        local tween = TweenService:Create(instance, tweenInfo, propertiesGoal)
        tween:Play()
        -- Note: This tool does NOT wait for tween completion.

        return ToolHelpers.FormatSuccessResult({
            message = ("Tween started for instance %s with duration %.2fs."):format(instancePath, duration),
            instance_path = instancePath,
            duration = duration,
            easing_style = easingStyleStr,
            easing_direction = easingDirectionStr,
            properties_tweened = ToolHelpers.RobloxValueToJson(propertiesGoal) -- Show what we attempted to tween to
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in TweenProperties: " .. tostring(pcall_result))
    end
end

return execute
