-- PlaySoundId.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)

local function execute(args)
    local success, result = pcall(function()
        local soundId = args.sound_id
        local parentPath = args.parent_path or "Workspace" -- Default to Workspace
        local properties = args.properties or {}

        if not soundId or type(soundId) ~= "string" then
            return ToolHelpers.FormatErrorResult("'sound_id' is required and must be a string (e.g., 'rbxassetid://123').")
        end
        if type(parentPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'parent_path' must be a string.")
        end
        if type(properties) ~= "table" then
            return ToolHelpers.FormatErrorResult("'properties' must be a table if provided.")
        end

        local parentInstance, err = ToolHelpers.FindInstanceByPath(parentPath)
        if not parentInstance then
            print(("PlaySoundId: Parent '%s' not found, defaulting to Workspace. Error: %s"):format(parentPath, err or "nil"))
            parentInstance = workspace -- Fallback to workspace
        end

        local soundInstance = Instance.new("Sound")
        soundInstance.SoundId = soundId
        soundInstance.Parent = parentInstance -- Parent it first

        -- Apply optional properties
        for propName, propValueJson in pairs(properties) do
            local convertedValue = ToolHelpers.JsonToRobloxValue(propValueJson)
            local setSuccess, setError = pcall(function()
                soundInstance[propName] = convertedValue
            end)
            if not setSuccess then
                -- Log warning, but don't necessarily fail the whole operation
                print(("PlaySoundId: Error setting property '%s' on new Sound: %s"):format(propName, setError))
            end
        end

        -- Ensure sound is loaded before playing, wait a short moment
        if not soundInstance.IsLoaded then
            soundInstance.Loaded:Wait(2) -- Wait up to 2 seconds for sound to load
        end

        if not soundInstance.IsLoaded then
             -- If still not loaded, don't try to play, return info
            local msg = ("Sound '%s' created under %s but failed to load in time. Playback skipped."):format(soundInstance.Name, soundInstance.Parent:GetFullName())
            return ToolHelpers.FormatSuccessResult({ -- Still success as it was created
                message = msg,
                sound_path = soundInstance:GetFullName(),
                sound_id = soundId,
                is_playing = false,
                details = "Sound not loaded after wait time."
            })
        end

        soundInstance:Play()

        return ToolHelpers.FormatSuccessResult({
            message = ("Sound '%s' is now playing under %s."):format(soundInstance.Name, soundInstance.Parent:GetFullName()),
            sound_path = soundInstance:GetFullName(),
            sound_id = soundId,
            is_playing = soundInstance.IsPlaying
        })
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in PlaySoundId: " .. tostring(result))
    end
end

return execute
