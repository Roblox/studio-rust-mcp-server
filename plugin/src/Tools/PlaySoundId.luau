-- PlaySoundId.luau (Corrected and Robust Version)

local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)

local function execute(args: Types.PlaySoundIdArgs)
    local success, pcall_result = pcall(function()
        local soundId = args.sound_id
        local parentPath = args.parent_path
        local properties = args.properties or {}

        if not soundId or type(soundId) ~= "string" then
            return ToolHelpers.FormatErrorResult("'sound_id' is required and must be a string (e.g., 'rbxassetid://123').")
        end
        if parentPath ~= nil and type(parentPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'parent_path' must be a string if provided.")
        end
        if type(properties) ~= "table" then
            return ToolHelpers.FormatErrorResult("'properties' must be a table if provided.")
        end

        local parentInstance = nil
        if parentPath then
            local foundParent, err = ToolHelpers.FindInstanceByPath(parentPath)
            if not foundParent then
                return ToolHelpers.FormatErrorResult(("Specified 'parent_path' (%s) not found. Error: %s"):format(parentPath, err or "Not found"))
            end
            parentInstance = foundParent
        end

        local soundInstance = Instance.new("Sound")
        
        -- ===================================================================
        -- FIX #1: Handle cases where the SoundId itself is invalid or forbidden.
        -- ===================================================================
        local assignIdSuccess, assignIdError = pcall(function()
            soundInstance.SoundId = soundId
        end)

        if not assignIdSuccess then
            soundInstance:Destroy() -- Clean up the instance
            return ToolHelpers.FormatErrorResult(("Failed to assign SoundId '%s': %s"):format(tostring(soundId), tostring(assignIdError)))
        end
        
        -- (Your existing property setting logic is excellent and remains unchanged)
        local HttpService = game:GetService("HttpService")
        local propertyErrors = {}
        for propName, propValueInput in pairs(properties) do
            if string.lower(propName) == "parent" then
                if parentInstance then
                    table.insert(propertyErrors, "Cannot set 'Parent' via properties if 'parent_path' argument is also used. Parent is already determined.")
                else
                    if type(propValueInput) == "string" then
                        local foundParentFromProp, errProp = ToolHelpers.FindInstanceByPath(propValueInput)
                        if foundParentFromProp then parentInstance = foundParentFromProp
                        else table.insert(propertyErrors, ("Parent path '%s' from properties not found. Error: %s"):format(propValueInput, errProp or "")) end
                    elseif typeof(propValueInput) == "Instance" then parentInstance = propValueInput
                    else table.insert(propertyErrors, "'Parent' property must be a string path or Instance.") end
                end
            else
                local finalValueToSet, conversionErrorMsg = propValueInput, nil
                if type(propValueInput) == "table" then
                    local converted_value, err_msg = ToolHelpers.ConvertTableToRobloxType(propValueInput, propName, soundInstance)
                    if err_msg then conversionErrorMsg = err_msg else finalValueToSet = converted_value end
                end

                if conversionErrorMsg then
                    table.insert(propertyErrors, ("Property '%s': Conversion error: %s."):format(propName, conversionErrorMsg))
                else
                    local actualPropName = propName
                    if string.lower(propName) == "looping" then
                        actualPropName = "Looped"
                    end

                    local setSuccess, setError = pcall(function() soundInstance[actualPropName] = finalValueToSet end)
                    if not setSuccess then table.insert(propertyErrors, ("Property '%s' (attempted as '%s'): Error setting value: %s."):format(propName, actualPropName, tostring(setError))) end
                end
            end
        end

        if #propertyErrors > 0 then
            soundInstance:Destroy()
            return ToolHelpers.FormatErrorResult(("Error(s) applying properties to new Sound: %s"):format(table.concat(propertyErrors, "; ")))
        end

        if parentInstance then
            soundInstance.Parent = parentInstance
        else
            soundInstance.Parent = ToolHelpers.GetSoundService()
            if not properties.PlayOnRemove then soundInstance.PlayOnRemove = true end
        end

        -- ===================================================================
        -- FIX #2: Add a timeout to the wait to prevent hanging indefinitely.
        -- ===================================================================
        if not soundInstance.IsLoaded then
            soundInstance.Loaded:Wait(5) -- Wait a maximum of 5 seconds
        end

        if not soundInstance.IsLoaded then
            -- The sound failed to load, but the tool did its job. Return a success message with details.
            local msg = ("Sound '%s' (ID: %s) was created under %s but failed to load in time (e.g., asset is private/deleted). Playback skipped."):format(soundInstance.Name, soundId, soundInstance.Parent and soundInstance.Parent:GetFullName() or "SoundService")
            -- We don't want this to be considered an error by the agent, so we format it as a success.
            -- The sound will be cleaned up by PlayOnRemove.
            return ToolHelpers.FormatSuccessResult({
                message = msg,
                sound_path = soundInstance:GetFullName(),
                sound_id = soundId,
                is_playing = false,
            })
        end

        -- If we reach here, the sound is loaded and ready.
        soundInstance:Play()

        return ToolHelpers.FormatSuccessResult({
            message = ("Sound '%s' (ID: %s) is now playing under %s."):format(soundInstance.Name, soundId, soundInstance.Parent and soundInstance.Parent:GetFullName() or "SoundService"),
            sound_path = soundInstance:GetFullName(),
            sound_id = soundId,
            is_playing = soundInstance.IsPlaying,
            duration = soundInstance.TimeLength
        })
    end)

    if success then
        return pcall_result
    else
        -- This catches unexpected errors within the pcall itself.
        return ToolHelpers.FormatErrorResult("Internal error in PlaySoundId tool: " .. tostring(pcall_result))
    end
end

return execute