-- PlaySoundId.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)

local function execute(args)
    -- Arguments are expected directly on args table
    local success, pcall_result = pcall(function()
        local soundId = args.sound_id
        local parentPath = args.parent_path -- Optional, if nil, sound is parented to a temporary container or not at all if not playing.
        local properties = args.properties or {}

        if not soundId or type(soundId) ~= "string" then
            return ToolHelpers.FormatErrorResult("'sound_id' is required and must be a string (e.g., 'rbxassetid://123').")
        end
        if parentPath ~= nil and type(parentPath) ~= "string" then -- Only validate if provided
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
        else
            -- If no parentPath, sound will be created but not parented by default.
            -- PlayOnRemove will handle cleanup if it's temporary.
            -- Alternatively, create a temporary container in SoundService or Workspace.
            -- For now, let it be nil and rely on PlayOnRemove or explicit parenting in properties.
        end

        local soundInstance = Instance.new("Sound")
        soundInstance.SoundId = soundId

        local propertyErrors = {}
        for propName, propValueInput in pairs(properties) do
            if string.lower(propName) == "parent" then
                if parentInstance then
                    table.insert(propertyErrors, "Cannot set 'Parent' via properties if 'parent_path' argument is also used. Parent is already determined.")
                else
                    -- Allow Parent property if parent_path arg was not given
                    if type(propValueInput) == "string" then
                        local foundParentFromProp, errProp = ToolHelpers.FindInstanceByPath(propValueInput)
                        if foundParentFromProp then
                            parentInstance = foundParentFromProp
                        else
                            table.insert(propertyErrors, ("Parent path '%s' from properties not found. Error: %s"):format(propValueInput, errProp or ""))
                        end
                    elseif typeof(propValueInput) == "Instance" then
                        parentInstance = propValueInput
                    else
                        table.insert(propertyErrors, "'Parent' property must be a string path or Instance.")
                    end
                end
            else
                local convertedValue, convertError = ToolHelpers.JsonToRobloxValue(propValueInput, "Sound."..propName)
                if convertError then
                    table.insert(propertyErrors, ("Property '%s': Failed to convert input value: %s"):format(propName, convertError))
                else
                    local setSuccess, setError = pcall(function()
                        soundInstance[propName] = convertedValue
                    end)
                    if not setSuccess then
                        table.insert(propertyErrors, ("Property '%s': Error setting value: %s"):format(propName, setError))
                    end
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
            -- If no parent determined from args or properties, parent to SoundService for playing globally
            -- or consider not parenting if PlayOnRemove is true (which is default for SoundService children)
            soundInstance.Parent = game:GetService("SoundService")
            if not properties.PlayOnRemove then soundInstance.PlayOnRemove = true end
        end

        if not soundInstance.IsLoaded then
            soundInstance.Loaded:Wait(5) -- Increased wait time
        end

        if not soundInstance.IsLoaded then
            local msg = ("Sound '%s' (ID: %s) created under %s but failed to load in time. Playback skipped."):format(soundInstance.Name, soundId, soundInstance.Parent and soundInstance.Parent:GetFullName() or "SoundService")
            -- This is still a "success" in terms of tool execution (sound instance created), but playback failed.
            return ToolHelpers.FormatSuccessResult({
                message = msg,
                sound_path = soundInstance:GetFullName(),
                sound_id = soundId,
                is_playing = false,
                details = "Sound not loaded after wait time."
            })
        end

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
        return ToolHelpers.FormatErrorResult("Internal error in PlaySoundId: " .. tostring(pcall_result))
    end
end

return execute
