-- ToolHelpers.luau
local ToolHelpers = {}

local HttpService = game:GetService("HttpService")

-- Helper to safely decode JSON
function ToolHelpers.SafeJsonDecode(jsonString)
    local success, result = pcall(function()
        return HttpService:JSONDecode(jsonString)
    end)
    if success then
        return result
    else
        return nil, "Error decoding JSON: " .. tostring(result)
    end
end

-- Helper to safely encode to JSON
function ToolHelpers.SafeJsonEncode(data)
    local success, result = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if success then
        return result
    else
        return nil, "Error encoding to JSON: " .. tostring(result)
    end
end

function ToolHelpers.FindInstanceByPath(pathString)
    if not pathString or type(pathString) ~= "string" or pathString == "" then
        return nil, "Path is nil, not a string, or empty."
    end

    local lowerPath = string.lower(pathString)
    if lowerPath == "workspace" then return workspace, nil end
    if lowerPath == "lighting" then return game:GetService("Lighting"), nil end
    if lowerPath == "soundservice" then return game:GetService("SoundService"), nil end
    if lowerPath == "replicatedstorage" then return game:GetService("ReplicatedStorage"), nil end
    if lowerPath == "serverstorage" then return game:GetService("ServerStorage"), nil end
    if lowerPath == "serverplayers" or lowerPath == "players" then return game:GetService("Players"), nil end
    if lowerPath == "starterplayer" then return game:GetService("StarterPlayer"), nil end
    if lowerPath == "starterplayerscripts" then return game:GetService("StarterPlayer").StarterPlayerScripts, nil end
    if lowerPath == "startercharacterscripts" then return game:GetService("StarterPlayer").StarterCharacterScripts, nil end
    if lowerPath == "startergui" then return game:GetService("StarterGui"), nil end
    if lowerPath == "starterpack" then return game:GetService("StarterPack"), nil end
    if lowerPath == "serverscriptservice" then return game:GetService("ServerScriptService"), nil end
    if lowerPath == "teams" then return game:GetService("Teams"), nil end
    if lowerPath == "textchatservice" then return game:GetService("TextChatService"), nil end
    if lowerPath == "userinputservice" then return game:GetService("UserInputService"), nil end
     -- Path for PlayerGui typically needs player name, e.g. "Players.LocalPlayer.PlayerGui"
    -- However, if just "PlayerGui" is passed for a ScreenGui, some tools might try to resolve LocalPlayer.PlayerGui.
    -- For direct access, a full path is better. This helper won't assume LocalPlayer here.


    local current = game
    for part in string.gmatch(pathString, "[^%.]+") do
        if not current or typeof(current) ~= "Instance" then
             return nil, "Invalid path segment: " .. part .. " - parent is not an Instance or nil."
        end
        current = current:FindFirstChild(part)
        if not current then
            return nil, "Instance not found at segment: " .. part .. " in path " .. pathString
        end
    end
    return current
end

function ToolHelpers.JsonToRobloxValue(jsonValue, targetTypeHint) -- targetTypeHint is not used yet, but could be for disambiguation
    if jsonValue == nil then return nil end
    local valueType = type(jsonValue)

    if valueType == "table" then
        -- Vector3: { "x": number, "y": number, "z": number }
        if jsonValue.x ~= nil and jsonValue.y ~= nil and jsonValue.z ~= nil and jsonValue.w == nil and #jsonValue == 0 then -- #jsonValue to avoid arrays
            -- Check if all values are numbers
            if type(jsonValue.x) == "number" and type(jsonValue.y) == "number" and type(jsonValue.z) == "number" then
                 return Vector3.new(jsonValue.x, jsonValue.y, jsonValue.z)
            end
        -- UDim2: { "scale_x": number, "offset_x": number, "scale_y": number, "offset_y": number }
        elseif jsonValue.scale_x ~= nil and jsonValue.offset_x ~= nil and jsonValue.scale_y ~= nil and jsonValue.offset_y ~= nil and #jsonValue == 0 then
            if type(jsonValue.scale_x) == "number" and type(jsonValue.offset_x) == "number" and type(jsonValue.scale_y) == "number" and type(jsonValue.offset_y) == "number" then
                return UDim2.new(jsonValue.scale_x, jsonValue.offset_x, jsonValue.scale_y, jsonValue.offset_y)
            end
        -- Color3: { "r": number, "g": number, "b": number } (values 0-1)
        elseif jsonValue.r ~= nil and jsonValue.g ~= nil and jsonValue.b ~= nil and #jsonValue == 0 then
            if type(jsonValue.r) == "number" and type(jsonValue.g) == "number" and type(jsonValue.b) == "number" then
                return Color3.new(jsonValue.r, jsonValue.g, jsonValue.b)
            end
        -- CFrame: { "position": {"x":0,"y":0,"z":0}, "orientation": {"x":0,"y":0,"z":0_degrees}}
        elseif jsonValue.position and jsonValue.orientation and #jsonValue == 0 then
            if type(jsonValue.position) == "table" and type(jsonValue.orientation) == "table" and
               type(jsonValue.position.x) == "number" and type(jsonValue.position.y) == "number" and type(jsonValue.position.z) == "number" and
               type(jsonValue.orientation.x) == "number" and type(jsonValue.orientation.y) == "number" and type(jsonValue.orientation.z) == "number" then
                local pos = Vector3.new(jsonValue.position.x, jsonValue.position.y, jsonValue.position.z)
                local orient = jsonValue.orientation
                return CFrame.new(pos) * CFrame.Angles(math.rad(orient.x), math.rad(orient.y), math.rad(orient.z))
            end
        -- ColorSequence: {start_color, end_color} or {keys=[{time,value={r,g,b}}]}
        elseif (jsonValue.start_color and jsonValue.end_color) or (jsonValue.keys and targetTypeHint == "ColorSequence") then
            if jsonValue.keys then -- Full format
                local keypoints = {}
                for _, keyData in ipairs(jsonValue.keys) do
                    if type(keyData.time) == "number" and type(keyData.value) == "table" then
                        local colorVal = ToolHelpers.JsonToRobloxValue(keyData.value, "Color3") -- Hint for Color3
                        if typeof(colorVal) == "Color3" then
                            table.insert(keypoints, ColorSequenceKeypoint.new(keyData.time, colorVal))
                        end
                    end
                end
                if #keypoints > 0 then return ColorSequence.new(keypoints) end
            elseif jsonValue.start_color and jsonValue.end_color then -- Simplified format
                local startColor = ToolHelpers.JsonToRobloxValue(jsonValue.start_color, "Color3")
                local endColor = ToolHelpers.JsonToRobloxValue(jsonValue.end_color, "Color3")
                if typeof(startColor) == "Color3" and typeof(endColor) == "Color3" then
                    return ColorSequence.new({ColorSequenceKeypoint.new(0, startColor), ColorSequenceKeypoint.new(1, endColor)})
                end
            end
        -- NumberSequence: {start_value, end_value} or {keys=[{time,value=num}]}
        elseif (jsonValue.start_value ~=nil and jsonValue.end_value ~=nil) or (jsonValue.keys and targetTypeHint == "NumberSequence") then
             if jsonValue.keys then -- Full format
                local keypoints = {}
                for _, keyData in ipairs(jsonValue.keys) do
                    if type(keyData.time) == "number" and type(keyData.value) == "number" then
                        table.insert(keypoints, NumberSequenceKeypoint.new(keyData.time, keyData.value))
                    end
                end
                if #keypoints > 0 then return NumberSequence.new(keypoints) end
            elseif jsonValue.start_value ~= nil and jsonValue.end_value ~= nil then -- Simplified format
                 if type(jsonValue.start_value) == "number" and type(jsonValue.end_value) == "number" then
                    return NumberSequence.new({NumberSequenceKeypoint.new(0, jsonValue.start_value), NumberSequenceKeypoint.new(1, jsonValue.end_value)})
                end
            end
        end
        -- If it's an array-like table, recursively convert its elements
        if #jsonValue > 0 and not (jsonValue.x and jsonValue.y and jsonValue.z) and not (jsonValue.r and jsonValue.g and jsonValue.b) and not (jsonValue.scale_x and jsonValue.offset_x) then -- Avoid re-processing known dicts
            local newTable = {}
            for i, v in ipairs(jsonValue) do
                newTable[i] = ToolHelpers.JsonToRobloxValue(v) -- Recursive call for elements
            end
            return newTable
        end
        -- If it's a dictionary-like table, recursively convert its values (keys assumed to be strings)
        local newDict = {}
        for k, v in pairs(jsonValue) do
            newDict[k] = ToolHelpers.JsonToRobloxValue(v) -- Recursive call for values
        end
        return newDict

    elseif valueType == "string" then
        -- Enum: "Enum.Material.Plastic"
        if string.sub(jsonValue, 1, 5) == "Enum." then
            local enumItem, err = ToolHelpers.StringToEnum(jsonValue)
            if not enumItem then
                print("JsonToRobloxValue: Error parsing enum string '" .. jsonValue .. "': " .. (err or "Unknown error"))
            end
            return enumItem -- Will be nil if error, which is fine.
        end
    end
    return jsonValue -- Return as is if no conversion rule matched (e.g. string, number, boolean)
end

function ToolHelpers.RobloxValueToJson(robloxValue)
    if robloxValue == nil then return nil end
    local robloxType = typeof(robloxValue)

    if robloxType == "Vector3" then
        return {x=robloxValue.X, y=robloxValue.Y, z=robloxValue.Z}
    elseif robloxType == "UDim2" then
        return {scale_x=robloxValue.X.Scale, offset_x=robloxValue.X.Offset, scale_y=robloxValue.Y.Scale, offset_y=robloxValue.Y.Offset}
    elseif robloxType == "Color3" then
        return {r=robloxValue.R, g=robloxValue.G, b=robloxValue.B}
    elseif robloxType == "CFrame" then
        local pos = robloxValue.Position
        -- Ensure XYZ order for output orientation degrees
        local ex, ey, ez = robloxValue:ToEulerAnglesXYZ()
        return {
            position = {x=pos.X, y=pos.Y, z=pos.Z},
            orientation = {x=math.deg(ex), y=math.deg(ey), z=math.deg(ez)}
        }
    elseif robloxType == "ColorSequence" then
        local keypointsJson = {}
        for _, kp in ipairs(robloxValue.Keypoints) do
            table.insert(keypointsJson, {time = kp.Time, value = ToolHelpers.RobloxValueToJson(kp.Value)})
        end
        return {keys = keypointsJson}
    elseif robloxType == "NumberSequence" then
        local keypointsJson = {}
        for _, kp in ipairs(robloxValue.Keypoints) do
            table.insert(keypointsJson, {time = kp.Time, value = kp.Value}) -- Value is already a number
        end
        return {keys = keypointsJson}
    elseif string.find(robloxType, "EnumItem") == 1 or string.find(robloxType, "Enum") == 1 then -- typeof can return "EnumItem" or "Enum.Material" etc.
        return tostring(robloxValue)
    elseif robloxType == "Instance" then
        return robloxValue:GetFullName()
    elseif robloxType == "table" then
        -- Check if it's an array-like table
        if #robloxValue > 0 and robloxValue[1] ~= nil then
            local jsonArray = {}
            for i = 1, #robloxValue do
                jsonArray[i] = ToolHelpers.RobloxValueToJson(robloxValue[i])
            end
            return jsonArray
        else -- Treat as dictionary
            local jsonMap = {}
            for k, v in pairs(robloxValue) do
                if type(k) == "string" then -- Only string keys for JSON objects
                    jsonMap[k] = ToolHelpers.RobloxValueToJson(v)
                end
            end
            return jsonMap
        end
    end
    return robloxValue -- Return as is if no conversion rule matched (string, number, boolean)
end

-- Standard response formatters
function ToolHelpers.FormatSuccessResult(data)
    local responseText
    if type(data) == "string" then
        responseText = data
    elseif data == nil then
        responseText = "" -- Represent nil data as empty string for TextContent part
    else
        local success, encoded = pcall(ToolHelpers.SafeJsonEncode, data)
        if success then
            responseText = encoded
        else
            -- This case itself should return an error structure
            local errorContent = { { type = "text", text = "Error: Could not encode successful result data: " .. tostring(encoded) } }
            return { content = errorContent, isError = true }
        end
    end
    return { content = { { type = "text", text = responseText } }, isError = false }
end

function ToolHelpers.FormatErrorResult(errorMessageString, _errorType) -- _errorType is not used in the new format
    return { content = { { type = "text", text = errorMessageString or "An unspecified error occurred." } }, isError = true }
end

function ToolHelpers.StringToEnum(enumString)
    if type(enumString) ~= "string" then return nil, "Input not a string" end
    if string.sub(enumString, 1, 5) ~= "Enum." then return nil, "Not an Enum string format" end

    local parts = {}
    for part in string.gmatch(enumString, "[^%.]+") do table.insert(parts, part) end

    if #parts < 3 then return nil, "Enum string format incorrect (e.g., Enum.Category.Item)" end

    local enumCategoryName = parts[2]
    local enumItemName = table.concat(parts, ".", 3) -- Handles cases like Enum.UserInputType.MouseButton1

    if Enum[enumCategoryName] then
        local enumCategory = Enum[enumCategoryName]
        if enumCategory[enumItemName] then
            return enumCategory[enumItemName]
        else
            return nil, ("Enum item '%s' not found in Enum.%s"):format(enumItemName, enumCategoryName)
        end
    else
        return nil, ("Enum category '%s' not found."):format(enumCategoryName)
    end
end


return ToolHelpers
