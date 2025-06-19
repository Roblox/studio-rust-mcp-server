-- TweenProperties.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local TweenService = ToolHelpers.GetTweenService()

local function execute(args: Types.TweenPropertiesArgs)
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

        local HttpService = game:GetService("HttpService") -- Ensure it's available
        local propertiesGoal = {}
        -- local conversionErrorsFound = false -- Flag to stop processing if an error occurs -- Not needed if returning immediately

        for propName, propValueInput in pairs(propertiesToTween) do
            local finalValueToSet = propValueInput
            local conversionErrorMsg = nil

            if type(propValueInput) == "table" then
                -- Pass 'instance' for context-aware conversion
                local converted_value, err_msg = ToolHelpers.ConvertTableToRobloxType(propValueInput, propName, instance)
                if err_msg then
                    conversionErrorMsg = err_msg
                else
                    finalValueToSet = converted_value
                end
            end

            if conversionErrorMsg then
                -- Important: If any conversion fails, stop and return an error immediately.
                -- TweenService.Create might not give clear errors if it receives a table where it expects a Color3 etc.
                return ToolHelpers.FormatErrorResult(
                    ("Property '%s' in 'properties_to_tween': Conversion error: %s. Original value was: %s"):format(
                        propName,
                        conversionErrorMsg,
                        HttpService:JSONEncode(propValueInput)
                    )
                )
                -- No need for conversionErrorsFound flag if we return immediately
            end
            propertiesGoal[propName] = finalValueToSet
        end

        -- This check for empty propertiesGoal should ideally be after successful conversion of all items.
        -- If propertiesToTween was not empty but all conversions failed (and returned errors above), this won't be hit.
        -- If propertiesToTween was not empty, and all items were converted (or didn't need conversion),
        -- then propertiesGoal will also not be empty.
        -- The original check for propertiesToTween being empty is still valid and important before this loop.
        if next(propertiesGoal) == nil and next(propertiesToTween) ~= nil then
            -- This case implies propertiesToTween was not empty initially, but resulted in an empty propertiesGoal
            -- This shouldn't happen if errors cause an immediate return above, or if propertiesToTween was valid.
            -- It covers a scenario where propertiesToTween might contain items that are not tables and also not directly usable,
            -- though the main concern (table conversion errors) is handled above.
            return ToolHelpers.FormatErrorResult("No valid properties to tween after processing 'properties_to_tween'. Original input might have been problematic or became empty.")
        end
        -- If propertiesToTween itself was empty, the earlier check `if next(propertiesToTween) == nil then` handles it.


        local tweenCreateSuccess, tweenOrError = pcall(TweenService.Create, TweenService, instance, tweenInfo, propertiesGoal)
        if not tweenCreateSuccess then
             return ToolHelpers.FormatErrorResult("TweenService:Create failed: " .. tostring(tweenOrError) .. ". Goal: " .. HttpService:JSONEncode(propertiesGoal))
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
            properties_goal = propertiesGoal -- Pass the raw Lua table
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in TweenProperties: " .. tostring(pcall_result))
    end
end

return execute
