-- TweenProperties.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local TweenService = game:GetService("TweenService")

local function execute(args)
    -- Arguments are expected directly on args table
    local success, pcall_result = pcall(function()
        local instancePath = args.instance_path
        local duration = args.duration
        local easingStyleStr = args.easing_style
        local easingDirectionStr = args.easing_direction
        local propertiesToTween = args.properties_to_tween -- Expecting Lua table {propName = value, ...}

        -- Optional params for TweenInfo
        local repeatCount = args.repeat_count
        local reverses = args.reverses
        local delayTime = args.delay_time

        if not instancePath or type(instancePath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'instance_path' is required and must be a string.")
        end
        if not duration or type(duration) ~= "number" or duration <= 0 then
            return ToolHelpers.FormatErrorResult("'duration' must be a positive number.")
        end
        if not easingStyleStr or type(easingStyleStr) ~= "string" then
            return ToolHelpers.FormatErrorResult("'easing_style' (Enum.EasingStyle name) is required and must be a string.")
        end
        if not easingDirectionStr or type(easingDirectionStr) ~= "string" then
            return ToolHelpers.FormatErrorResult("'easing_direction' (Enum.EasingDirection name) is required and must be a string.")
        end
        if not propertiesToTween or type(propertiesToTween) ~= "table" then
            return ToolHelpers.FormatErrorResult("'properties_to_tween' is required and must be a table.")
        end
        if next(propertiesToTween) == nil then
             return ToolHelpers.FormatErrorResult("'properties_to_tween' table cannot be empty.")
        end

        local instance, err = ToolHelpers.FindInstanceByPath(instancePath)
        if not instance then
            return ToolHelpers.FormatErrorResult("Failed to find instance at path: " .. instancePath .. ". " .. (err or ""))
        end

        local easingStyle = Enum.EasingStyle[easingStyleStr]
        if not easingStyle then
            return ToolHelpers.FormatErrorResult("Invalid EasingStyle: " .. easingStyleStr .. ". Refer to Enum.EasingStyle.")
        end
        local easingDirection = Enum.EasingDirection[easingDirectionStr]
        if not easingDirection then
            return ToolHelpers.FormatErrorResult("Invalid EasingDirection: " .. easingDirectionStr .. ". Refer to Enum.EasingDirection.")
        end

        local tweenInfo = TweenInfo.new(
            duration,
            easingStyle,
            easingDirection,
            repeatCount or 0, -- Default to 0 if nil
            reverses or false,  -- Default to false if nil
            delayTime or 0    -- Default to 0 if nil
        )

        local propertiesGoal = {}
        local conversionErrors = {}
        for propName, propValueInput in pairs(propertiesToTween) do
            -- Values in propertiesToTween are Lua values; JsonToRobloxValue converts tables to Color3/Vector3 etc.
            local convertedValue, convertError = ToolHelpers.JsonToRobloxValue(propValueInput, instance:GetClass().."."..propName)
            if convertError then
                table.insert(conversionErrors, ("Property '%s': Failed to convert input value: %s"):format(propName, convertError))
            else
                propertiesGoal[propName] = convertedValue
            end
        end

        if #conversionErrors > 0 then
            return ToolHelpers.FormatErrorResult("Error(s) converting property values for tween: " .. table.concat(conversionErrors, "; "))
        end

        if next(propertiesGoal) == nil then
            -- This might happen if all properties had conversion errors
            return ToolHelpers.FormatErrorResult("No valid properties to tween after conversion attempts.")
        end

        local tweenCreateSuccess, tweenOrError = pcall(TweenService.Create, TweenService, instance, tweenInfo, propertiesGoal)
        if not tweenCreateSuccess then
             return ToolHelpers.FormatErrorResult("TweenService:Create failed: " .. tostring(tweenOrError))
        end
        local tween = tweenOrError

        tween:Play()
        -- This tool fires the tween and returns. It does not yield/wait for tween completion.

        return ToolHelpers.FormatSuccessResult({
            message = ("Tween started for instance %s with duration %.2fs."):format(instancePath, duration),
            instance_path = instancePath,
            duration = duration,
            easing_style_used = easingStyleStr,
            easing_direction_used = easingDirectionStr,
            properties_goal = ToolHelpers.RobloxValueToJson(propertiesGoal) -- Confirm the goal table used
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in TweenProperties: " .. tostring(pcall_result))
    end
end

return execute
