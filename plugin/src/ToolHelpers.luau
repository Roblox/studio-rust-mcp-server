-- ToolHelpers.luau
local ToolHelpers = {}

local _services = {}
local HttpService = game:GetService("HttpService")

function ToolHelpers.InitServices(servicesTable)
	if type(servicesTable) ~= "table" then
		warn("ToolHelpers.InitServices expects a table, got: " .. type(servicesTable))
		return
	end
	for serviceName, serviceInstance in pairs(servicesTable) do
		_services[serviceName] = serviceInstance
	end
end

function ToolHelpers.GetDebrisService()
	return _services.DebrisService
end

function ToolHelpers.GetCollectionService()
	return _services.CollectionService
end

function ToolHelpers.GetPathfindingService()
	return _services.PathfindingService
end

function ToolHelpers.GetTextService()
	return _services.TextService
end

function ToolHelpers.GetPlayersService()
	return _services.Players
end

function ToolHelpers.GetStarterGuiService()
	return _services.StarterGui
end

function ToolHelpers.GetTeamsService()
	return _services.Teams
end

function ToolHelpers.GetTextChatService()
	return _services.TextChatService
end

function ToolHelpers.GetLightingService()
	return _services.Lighting
end

function ToolHelpers.GetUserInputService()
	return _services.UserInputService
end

function ToolHelpers.GetMarketplaceService()
	return _services.MarketplaceService
end

function ToolHelpers.GetDataStoreService()
	return _services.DataStoreService
end

function ToolHelpers.GetInsertService()
	return _services.InsertService
end

function ToolHelpers.GetSelectionService()
	return _services.Selection
end

function ToolHelpers.GetWorkspaceService()
	return _services.Workspace
end

function ToolHelpers.GetSoundService()
	return _services.SoundService
end

function ToolHelpers.GetTeleportService()
	return _services.TeleportService
end

function ToolHelpers.GetTweenService()
	return _services.TweenService
end

function ToolHelpers.FindInstanceByPath(pathString)
    if not pathString or type(pathString) ~= "string" or pathString == "" then
        return nil, "Path is nil, not a string, or empty."
    end

    local lowerPath = string.lower(pathString)
    if lowerPath == "workspace" then return _services.Workspace, nil end
    if lowerPath == "lighting" then return _services.Lighting, nil end
    if lowerPath == "soundservice" then return _services.SoundService, nil end
    if lowerPath == "replicatedstorage" then return _services.ReplicatedStorage, nil end
    if lowerPath == "serverstorage" then return _services.ServerStorage, nil end
    if lowerPath == "serverplayers" or lowerPath == "players" then return _services.Players, nil end
    if lowerPath == "starterplayer" then return _services.StarterPlayer, nil end
    if lowerPath == "starterplayerscripts" then return _services.StarterPlayer.StarterPlayerScripts, nil end
    if lowerPath == "startercharacterscripts" then return _services.StarterPlayer.StarterCharacterScripts, nil end
    if lowerPath == "startergui" then return _services.StarterGui, nil end
    if lowerPath == "starterpack" then return _services.StarterPack, nil end
    if lowerPath == "serverscriptservice" then return _services.ServerScriptService, nil end
    if lowerPath == "teams" then return _services.Teams, nil end
    if lowerPath == "textchatservice" then return _services.TextChatService, nil end
    if lowerPath == "userinputservice" then return _services.UserInputService, nil end
     -- Path for PlayerGui typically needs player name, e.g. "Players.LocalPlayer.PlayerGui"
    -- However, if just "PlayerGui" is passed for a ScreenGui, some tools might try to resolve LocalPlayer.PlayerGui.
    -- For direct access, a full path is better. This helper won't assume LocalPlayer here.


    local current = _services.Game
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

-- Standard response formatters

function ToolHelpers.SimpleTableToString(data, currentDepth)
    currentDepth = currentDepth or 1
    local maxDepth = 2 -- Max depth for nested serialization

    if type(data) ~= "table" then
        return "nil (not a table)"
    end

    local parts = {}
    local count = 0
    local totalLength = 0
    local maxPairs = 10 -- Max pairs for the current table level
    local maxLength = 200 -- Max total string length for the output of this function call
    local maxNestedValueStrLength = 70 -- Max length for a serialized nested table string

    for key, value in pairs(data) do
        count = count + 1
        if count > maxPairs and key ~= "message" then
            table.insert(parts, "...")
            break
        end

        local keyStr = tostring(key)
        local valueStr

        local valueType = type(value)
        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            valueStr = tostring(value)
        elseif valueType == "table" then
            if currentDepth < maxDepth then
                local nestedParts = {}
                local nestedCount = 0
                for nk, nv in pairs(value) do
                    nestedCount = nestedCount + 1
                    if nestedCount > 3 then -- Show up to 3 key-value pairs in a nested table
                        table.insert(nestedParts, "...")
                        break
                    end
                    local nestedValueStr
                    if type(nv) == "table" then
                        nestedValueStr = "[table@next_depth]"
                    else
                        nestedValueStr = tostring(nv)
                    end
                    table.insert(nestedParts, tostring(nk) .. "=" .. nestedValueStr)
                end
                valueStr = "{" .. table.concat(nestedParts, "; ") .. "}"
                if string.len(valueStr) > maxNestedValueStrLength then
                    valueStr = string.sub(valueStr, 1, maxNestedValueStrLength - 3) .. "...}"
                end
            else
                valueStr = "[table_max_depth]"
            end
        elseif valueType == "nil" then
            valueStr = "nil"
        else
            valueStr = "[" .. valueType .. "]"
        end

        if keyStr == "message" and (valueType == "string" or valueType == "number" or valueType == "boolean") then
            if string.len(valueStr) < maxLength - 5 and string.len(valueStr) > 0 then -- -5 for "..." buffer, prioritize message
                return valueStr -- Prioritize and return message directly if it's suitable
            elseif count > maxPairs then -- If message was the one that exceeded pair limit, but is too long
                 local truncatedMessage = string.sub(valueStr, 1, maxLength - 3) .. "..."
                 return truncatedMessage
            end
        end

        local pairStr = keyStr .. "=" .. valueStr
        -- Check length before adding, ensuring "..." can also fit if this is the last item before truncation
        if totalLength + string.len(pairStr) + 1 > maxLength - (if count >= maxPairs then 0 else string.len("...;")) then
            table.insert(parts, "...")
            break
        end
        table.insert(parts, pairStr)
        totalLength = totalLength + string.len(pairStr) + 1 -- +1 for semicolon
    end

    if #parts == 0 then
        if count > 0 and data.message then -- Handle case where only a long message existed
            local valueStr = tostring(data.message)
            local truncatedMessage = string.sub(valueStr, 1, maxLength - 3) .. "..."
            return truncatedMessage
        end
        return "empty table"
    end

    local simpleValuesCount = 0
    for _, partStr in ipairs(parts) do
        if not string.match(partStr, "%[table%]") and not string.match(partStr, "%[.+%]") and partStr ~= "..." then
            simpleValuesCount = simpleValuesCount + 1
        end
    end

    if simpleValuesCount == 0 and #parts > 0 then
        local firstPart = parts[1]
        if firstPart ~= "empty table" and firstPart ~= "nil (not a table)" and not (data.message and count==1) then
             -- if it's just a "message" field that was too long and got truncated to "...", return that.
            if data.message and count == 1 and parts[1] == "..." and string.len(tostring(data.message)) > maxLength then
                 local truncatedMessage = string.sub(tostring(data.message), 1, maxLength - 3) .. "..."
                 return truncatedMessage
            end
            return nil
        end
    end

    local finalStr = table.concat(parts, ";")
    if finalStr ~= "..." and finalStr ~= "" and not string.match(finalStr, ";$") then -- Add trailing semicolon if not just "..." or empty
        finalStr = finalStr .. ";"
    end
    -- Ensure final string does not exceed maxLength due to joining/semicolons, though previous checks should mostly prevent this.
    if string.len(finalStr) > maxLength then
        finalStr = string.sub(finalStr, 1, maxLength - 3) .. "..."
    end

    return finalStr
end

function ToolHelpers.FormatSuccessResult(data)
    local formattedString = ToolHelpers.SimpleTableToString(data)

    if formattedString and #formattedString > 0 then
        -- Ensure the 'text' field is the potentially simplified string.
        return { content = { { type = "text", text = formattedString } }, isError = false }
    else
        -- If SimpleTableToString returns nil or empty, use a generic success message.
        return { content = { { type = "text", text = "Operation successful." } }, isError = false }
    end
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

function ToolHelpers.TableLength(t)
    if type(t) ~= "table" then
        return 0
    end
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

function ToolHelpers.ConvertTableToRobloxType(inputTable, propertyName, instanceOrClassName)
    if type(inputTable) ~= "table" then
        return inputTable, nil -- Not a table, no conversion needed
    end

    local className = ""
    local instance = nil
    if typeof(instanceOrClassName) == "Instance" then
        instance = instanceOrClassName
        className = instance.ClassName
    elseif type(instanceOrClassName) == "string" then
        className = instanceOrClassName -- Assume it's a class name string for broader use
    end

    local lowerPropName = string.lower(propertyName)

    if lowerPropName == "value" and className ~= "" then
        if className == "Vector3Value" then
            if inputTable.x ~= nil and inputTable.y ~= nil and inputTable.z ~= nil then
                local x, y, z = tonumber(inputTable.x), tonumber(inputTable.y), tonumber(inputTable.z)
                if x and y and z then return Vector3.new(x, y, z), nil
                else return inputTable, "Invalid Vector3 components for Value: x, y, z must be numbers." end
            else return inputTable, "Missing x, y, or z fields for Vector3 Value." end
        elseif className == "Color3Value" then
            if inputTable.r ~= nil and inputTable.g ~= nil and inputTable.b ~= nil then
                local r, g, b = tonumber(inputTable.r), tonumber(inputTable.g), tonumber(inputTable.b)
                if r and g and b then return Color3.new(r, g, b), nil
                else return inputTable, "Invalid Color3 components for Value: r, g, b must be numbers." end
            else return inputTable, "Missing r, g, or b fields for Color3 Value." end
        elseif className == "CFrameValue" then
            -- Simplified: assumes x,y,z for position. CFrameValue can store full CFrame.
            -- Users would need to provide more components for full CFrame representation.
            local x,y,z = tonumber(inputTable.x), tonumber(inputTable.y), tonumber(inputTable.z)
            if x and y and z then
                -- This creates a CFrame at position x,y,z with no rotation.
                -- For full CFrame, more fields like lookAt or rotation matrix components would be needed from inputTable.
                return CFrame.new(x,y,z), nil
            else
                return inputTable, "Missing x,y,z components for CFrame Value. For full CFrame, provide more components."
            end
        elseif className == "BrickColorValue" then
            if type(inputTable.name) == "string" then
                 local success, result = pcall(BrickColor.new, inputTable.name)
                 if success then return result, nil else return inputTable, "Invalid BrickColor name for Value: " .. tostring(result) end
            elseif type(inputTable.number) == "number" then
                local success, result = pcall(BrickColor.new, inputTable.number)
                if success then return result, nil else return inputTable, "Invalid BrickColor number for Value: " .. tostring(result) end
            else return inputTable, "Missing 'name' or 'number' field for BrickColor Value." end
        -- Note: For primitive *Value types like StringValue, IntValue, BoolValue, NumberValue,
        -- if the 'Value' property is already a Lua primitive (string, number, boolean),
        -- the type(inputTable) ~= "table" check at the function start would mean this function
        -- isn't called or returns early. This block is for when 'Value' is given as a table.
        -- If a StringValue's 'Value' is given as {Text="Hi"}, it wouldn't match here.
        -- This primarily targets Roblox datatypes that are represented as tables by users.
        end
    end

    -- Infer type from property name (case-insensitive) - existing logic
    if string.find(lowerPropName, "color") then -- Matches "Color", "BackgroundColor3", "TextColor3", etc.
        if inputTable.r ~= nil and inputTable.g ~= nil and inputTable.b ~= nil then
            local r, g, b = tonumber(inputTable.r), tonumber(inputTable.g), tonumber(inputTable.b)
            if r and g and b then
                return Color3.new(r, g, b), nil
            else
                return inputTable, "Invalid Color3 components: r, g, b must be numbers."
            end
        else
            return inputTable, "Missing r, g, or b fields for Color3."
        end
    elseif lowerPropName == "position" or lowerPropName == "size" or string.find(lowerPropName, "vector3") then
        -- Check if it's for a GUI object's Position/Size (UDim2) vs a Part's Position/Size (Vector3)
        local isGui = false
        if instance then -- instance is defined if instanceOrClassName was an Instance
            pcall(function() if instance:IsA("GuiObject") or instance:IsA("GuiBase2d") then isGui = true end end)
        end

        if (isGui and (lowerPropName == "position" or lowerPropName == "size")) then -- UDim2 for GuiObject (Position or Size)
            -- Try to get components with primary names (x_scale), fallback to alternative (scale_x), default to 0
            local xs = tonumber(inputTable.x_scale) or tonumber(inputTable.scale_x) or 0
            local xo = tonumber(inputTable.x_offset) or tonumber(inputTable.offset_x) or 0
            local ys = tonumber(inputTable.y_scale) or tonumber(inputTable.scale_y) or 0
            local yo = tonumber(inputTable.y_offset) or tonumber(inputTable.offset_y) or 0

            -- UDim2.new will error if any are nil. The 'or 0' ensures they are numbers.
            return UDim2.new(xs, xo, ys, yo), nil

        elseif not isGui and (lowerPropName == "position" or lowerPropName == "size" or string.find(lowerPropName, "vector3")) then -- Vector3
            if inputTable.x ~= nil and inputTable.y ~= nil and inputTable.z ~= nil then
                local x, y, z = tonumber(inputTable.x), tonumber(inputTable.y), tonumber(inputTable.z)
                if x and y and z then
                    return Vector3.new(x, y, z), nil
                else
                    return inputTable, "Invalid Vector3 components: x, y, z must be numbers."
                end
            else
                return inputTable, "Missing x, y, or z fields for Vector3."
            end
        end
    elseif string.find(lowerPropName, "vector2") then
        if inputTable.x ~= nil and inputTable.y ~= nil then
            local x, y = tonumber(inputTable.x), tonumber(inputTable.y)
            if x and y then
                return Vector2.new(x, y), nil
            else
                return inputTable, "Invalid Vector2 components: x, y must be numbers."
            end
        else
            return inputTable, "Missing x or y fields for Vector2."
        end
    elseif string.find(lowerPropName, "udim2") then -- Explicit UDim2 (e.g. property name is "MyUDim2Property")
        -- Try to get components with primary names (x_scale), fallback to alternative (scale_x), default to 0
        local xs = tonumber(inputTable.x_scale) or tonumber(inputTable.scale_x) or 0
        local xo = tonumber(inputTable.x_offset) or tonumber(inputTable.offset_x) or 0
        local ys = tonumber(inputTable.y_scale) or tonumber(inputTable.scale_y) or 0
        local yo = tonumber(inputTable.y_offset) or tonumber(inputTable.offset_y) or 0

        return UDim2.new(xs, xo, ys, yo), nil

    elseif string.find(lowerPropName, "udim") then -- Catch UDim (single scale/offset)
        if inputTable.scale ~= nil and inputTable.offset ~= nil then
            local s, o = tonumber(inputTable.scale), tonumber(inputTable.offset)
            if s and o then
                return UDim.new(s, o), nil
            else
                return inputTable, "Invalid UDim components: scale, offset must be numbers."
            end
        else
            return inputTable, "Missing scale or offset fields for UDim."
        end
    elseif string.find(lowerPropName, "rect") then
         if inputTable.min_x ~= nil and inputTable.min_y ~= nil and inputTable.max_x ~= nil and inputTable.max_y ~= nil then
            local minx, miny, maxx, maxy = tonumber(inputTable.min_x), tonumber(inputTable.min_y), tonumber(inputTable.max_x), tonumber(inputTable.max_y)
            if minx and miny and maxx and maxy then
                return Rect.new(minx, miny, maxx, maxy), nil
            else
                return inputTable, "Invalid Rect components: min_x, min_y, max_x, max_y must be numbers."
            end
        else
            return inputTable, "Missing min_x, min_y, max_x, or max_y for Rect."
        end
    elseif string.find(lowerPropName, "numberrange") then
        if inputTable.min_value ~= nil and inputTable.max_value ~= nil then
            local minVal, maxVal = tonumber(inputTable.min_value), tonumber(inputTable.max_value)
            if minVal and maxVal then
                return NumberRange.new(minVal, maxVal), nil
            else
                return inputTable, "Invalid NumberRange components: min_value, max_value must be numbers."
            end
        else
            return inputTable, "Missing min_value or max_value for NumberRange."
        end

    elseif string.find(lowerPropName, "brickcolor") or string.find(lowerPropName, "teamcolor") then
        if inputTable.name and type(inputTable.name) == "string" then
            local success, result = pcall(BrickColor.new, inputTable.name)
            if success then return result, nil else return inputTable, "Invalid BrickColor name: " .. tostring(result) end
        elseif inputTable.number and type(inputTable.number) == "number" then
            local success, result = pcall(BrickColor.new, inputTable.number)
            if success then return result, nil else return inputTable, "Invalid BrickColor number: " .. tostring(result) end
        elseif inputTable.r ~= nil and inputTable.g ~= nil and inputTable.b ~= nil then
            local r, g, b = tonumber(inputTable.r), tonumber(inputTable.g), tonumber(inputTable.b)
            if r and g and b then
                -- Assuming r,g,b are 0-1 for palette usage
                local col3 = Color3.new(r,g,b)
                return BrickColor.palette(col3.r, col3.g, col3.b), nil
            else
                return inputTable, "Invalid BrickColor components: r, g, b must be numbers (0-1 range for palette)."
            end
        else
            return inputTable, "Missing 'name', 'number', or {r,g,b} fields for BrickColor."
        end
    elseif string.find(lowerPropName, "cframe") or string.find(lowerPropName, "cf") or string.find(lowerPropName, "transform") or string.find(lowerPropName, "pivot") then
        local x,y,z = tonumber(inputTable.x), tonumber(inputTable.y), tonumber(inputTable.z)
        local lx,ly,lz = tonumber(inputTable.lookAt_x), tonumber(inputTable.lookAt_y), tonumber(inputTable.lookAt_z)
        local r00,r01,r02 = tonumber(inputTable.r00), tonumber(inputTable.r01), tonumber(inputTable.r02)
        local r10,r11,r12 = tonumber(inputTable.r10), tonumber(inputTable.r11), tonumber(inputTable.r12)
        local r20,r21,r22 = tonumber(inputTable.r20), tonumber(inputTable.r21), tonumber(inputTable.r22)

        if x and y and z then
            if lx and ly and lz and not (r00 or r01 or r02 or r10 or r11 or r12 or r20 or r21 or r22) then -- Position and LookAt
                return CFrame.new(Vector3.new(x,y,z), Vector3.new(lx,ly,lz)), nil
            elseif r00 and r01 and r02 and r10 and r11 and r12 and r20 and r21 and r22 and not (lx or ly or lz) then -- Position and Matrix
                return CFrame.new(x,y,z, r00,r01,r02, r10,r11,r12, r20,r21,r22), nil
            elseif not (lx or ly or lz or r00 or r01 or r02 or r10 or r11 or r12 or r20 or r21 or r22) then -- Position only
                return CFrame.new(x,y,z), nil
            else
                return inputTable, "Invalid combination of CFrame components. Provide (x,y,z) OR (x,y,z + lookAt_x,y,z) OR (x,y,z + all 9 rXX matrix components)."
            end
        else
            return inputTable, "Missing x,y,z components for CFrame."
        end
    elseif string.find(lowerPropName, "numbersequence") then
        if type(inputTable) == "table" and #inputTable > 0 then -- Check if it's an array
            local keypoints = {}
            for i, kpTable in ipairs(inputTable) do
                if type(kpTable) == "table" and kpTable.time ~= nil and kpTable.value ~= nil then
                    local t, v = tonumber(kpTable.time), tonumber(kpTable.value)
                    local e = tonumber(kpTable.envelope) -- Envelope is optional, defaults to 0 if nil for NumberSequenceKeypoint.new
                    if t and v then
                        if e == nil then e = 0 end -- Default envelope for NumberSequenceKeypoint
                        table.insert(keypoints, NumberSequenceKeypoint.new(t, v, e))
                    else
                        return inputTable, ("Invalid NumberSequence keypoint at index %d: time, value must be numbers."):format(i)
                    end
                else
                    return inputTable, ("Malformed NumberSequence keypoint at index %d: must be a table with time, value fields."):format(i)
                end
            end
            if #keypoints > 0 then
                local success, result = pcall(NumberSequence.new, keypoints)
                if success then return result, nil else return inputTable, "Error creating NumberSequence: " .. tostring(result) end
            else
                return inputTable, "No valid keypoints found for NumberSequence."
            end
        else
            return inputTable, "NumberSequence input must be an array of keypoint tables {{time=t, value=v, envelope=e}, ...}."
        end
    elseif string.find(lowerPropName, "colorsequence") then
        if type(inputTable) == "table" and #inputTable > 0 then -- Check if it's an array
            local keypoints = {}
            for i, kpTable in ipairs(inputTable) do
                if type(kpTable) == "table" and kpTable.time ~= nil and type(kpTable.value) == "table" then
                    local t = tonumber(kpTable.time)
                    local valTable = kpTable.value
                    if t ~= nil and valTable.r ~= nil and valTable.g ~= nil and valTable.b ~= nil then
                        local r, g, b = tonumber(valTable.r), tonumber(valTable.g), tonumber(valTable.b)
                        if r and g and b then
                            table.insert(keypoints, ColorSequenceKeypoint.new(t, Color3.new(r,g,b)))
                        else
                            return inputTable, ("Invalid Color3 components in ColorSequence keypoint at index %d: r,g,b must be numbers."):format(i)
                        end
                    else
                        return inputTable, ("Invalid ColorSequence keypoint at index %d: time must be a number, value must be a Color3-like table {r,g,b}."):format(i)
                    end
                else
                    return inputTable, ("Malformed ColorSequence keypoint at index %d: must be a table with time (number) and value (Color3 table) fields."):format(i)
                end
            end
            if #keypoints > 0 then
                local success, result = pcall(ColorSequence.new, keypoints)
                if success then return result, nil else return inputTable, "Error creating ColorSequence: " .. tostring(result) end
            else
                return inputTable, "No valid keypoints found for ColorSequence."
            end
        else
            return inputTable, "ColorSequence input must be an array of keypoint tables {{time=t, value={r,g,b}}, ...}."
        end
    elseif string.find(lowerPropName, "physicalproperties") or string.find(lowerPropName, "customphysicalproperties") then
        if inputTable.material_enum_name and type(inputTable.material_enum_name) == "string" then
            local matEnum, err = ToolHelpers.StringToEnum(inputTable.material_enum_name)
            if matEnum and typeof(matEnum) == "EnumItem" and matEnum.EnumType == Enum.Material then
                return PhysicalProperties.new(matEnum), nil
            else
                return inputTable, "Invalid 'material_enum_name': " .. (err or "must be a valid Enum.Material string (e.g., 'Enum.Material.Plastic').")
            end
        elseif inputTable.density ~= nil or inputTable.friction ~= nil or inputTable.elasticity ~= nil or inputTable.friction_weight ~= nil or inputTable.elasticity_weight ~= nil then -- Allow partial for custom
            local d = tonumber(inputTable.density)
            local f = tonumber(inputTable.friction)
            local e = tonumber(inputTable.elasticity)
            local fw = tonumber(inputTable.friction_weight)
            local ew = tonumber(inputTable.elasticity_weight)
            -- PhysicalProperties constructor can take (density, friction, elasticity, frictionWeight, elasticityWeight)
            -- Or (materialEnum). If custom, it seems to prefer all values.
            -- For flexibility, let's try to call it with what's provided, but this might error if not all are there.
            -- A safer approach for custom if not all are provided is to not convert.
            -- However, the prompt implies if any custom is given, all are needed (or use defaults).
            -- Let's assume if one custom is given, the user intends custom props.
            -- Roblox default constructor for PhysicalProperties.new() uses (0.7, 0.3, 0.5, 1, 1) if no args.
            -- If some are provided, we should probably provide all five, using defaults for missing ones.
            if d == nil and f == nil and e == nil and fw == nil and ew == nil then
                 return inputTable, "No valid numeric components for PhysicalProperties provided (density, friction, elasticity, friction_weight, elasticity_weight)."
            end

            -- Using default values for any nil custom properties
            local density = d or 0.7
            local friction = f or 0.3
            local elasticity = e or 0.5
            local frictionWeight = fw or 1
            local elasticityWeight = ew or 1

            return PhysicalProperties.new(density, friction, elasticity, frictionWeight, elasticityWeight), nil
        else
            return inputTable, "For PhysicalProperties, provide 'material_enum_name' OR custom properties (density, friction, elasticity, friction_weight, elasticity_weight)."
        end

    end

    -- If no specific conversion rule matched, return the original table
    return inputTable, nil
end


-- Forward declaration for the recursive helper
local _serializeValueForLuauString

function ToolHelpers.TableToLuauString(input)
    local success, result = pcall(function()
        return "return " .. _serializeValueForLuauString(input, {})
    end)
    if success then
        if type(result) == "string" then
            return result, nil
        else
            -- This case should ideally not be hit if _serializeValueForLuauString always returns string or errors.
            return nil, "Serialization resulted in a non-string value unexpectedly: " .. tostring(result)
        end
    else
        return nil, "Error during TableToLuauString serialization: " .. tostring(result)
    end
end

_serializeValueForLuauString = function(value, visitedTables)
    local valueType = typeof(value) -- Use typeof for Roblox types

    if value == nil then
        return "nil"
    elseif valueType == "boolean" then
        return tostring(value)
    elseif valueType == "number" then
        -- Handle NaN and Infinity cases for numbers, as they don't have direct Luau literals
        if value ~= value then return "0/0" -- NaN
        elseif value == math.huge then return "1/0" -- Infinity
        elseif value == -math.huge then return "-1/0" -- -Infinity
        end
        return tostring(value) -- Standard number
    elseif valueType == "string" then
        return string.format("%q", value)
    elseif valueType == "Color3" then
        return string.format("Color3.new(%f, %f, %f)", value.r, value.g, value.b)
    elseif valueType == "Vector3" then
        return string.format("Vector3.new(%f, %f, %f)", value.x, value.y, value.z)
    elseif valueType == "Vector2" then
        return string.format("Vector2.new(%f, %f)", value.x, value.y)
    elseif valueType == "UDim" then
        return string.format("UDim.new(%f, %d)", value.Scale, value.Offset)
    elseif valueType == "UDim2" then
        return string.format("UDim2.new(%f, %d, %f, %d)", value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
    elseif valueType == "BrickColor" then
        return string.format("BrickColor.new(%q)", value.Name)
    elseif valueType == "CFrame" then
        -- CFrame:GetComponents() returns 12 numbers: x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22
        local comps = {value:GetComponents()}
        return string.format("CFrame.new(%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f)", unpack(comps))
    elseif valueType == "NumberRange" then
        return string.format("NumberRange.new(%f, %f)", value.Min, value.Max)
    elseif valueType == "NumberSequence" then
        local keypointStrings = {}
        for _, kp in ipairs(value.Keypoints) do
            table.insert(keypointStrings, string.format("NumberSequenceKeypoint.new(%f, %f, %f)", kp.Time, kp.Value, kp.Envelope))
        end
        return string.format("NumberSequence.new({%s})", table.concat(keypointStrings, ", "))
    elseif valueType == "ColorSequence" then
        local keypointStrings = {}
        for _, kp in ipairs(value.Keypoints) do
            -- kp.Value is a Color3, so we serialize it directly.
            table.insert(keypointStrings, string.format("ColorSequenceKeypoint.new(%f, Color3.new(%f,%f,%f))", kp.Time, kp.Value.r, kp.Value.g, kp.Value.b))
        end
        return string.format("ColorSequence.new({%s})", table.concat(keypointStrings, ", "))
    elseif valueType == "PhysicalProperties" then
         return string.format("PhysicalProperties.new(%f,%f,%f,%f,%f)", value.Density, value.Friction, value.Elasticity, value.FrictionWeight, value.ElasticityWeight)
    elseif typeof(value) == "EnumItem" then
        return value.EnumType.Name .. "." .. value.Name
    elseif value:IsA("Instance") then -- Must come after specific Roblox types like BrickColor, Color3 etc.
        return string.format("%q", value:GetFullName()) -- Represent instances by their path
    elseif valueType == "table" then
        if visitedTables[value] then
            return "nil --[[circular_reference]]"
        end
        visitedTables[value] = true

        local parts = {}
        local isArray = true
        local n = 0
        for _ in pairs(value) do n = n + 1 end

        if n == #value then -- Heuristic: if pairs count matches ipairs count, treat as array
            for i = 1, #value do
                table.insert(parts, _serializeValueForLuauString(value[i], visitedTables))
            end
            visitedTables[value] = nil
            return "{ " .. table.concat(parts, ", ") .. " }"
        else -- Dictionary
            for k, v_item in pairs(value) do -- Renamed v to v_item to avoid conflict with outer scope if any
                local keyStr
                if type(k) == "string" and string.match(k, "^[_%a][_%w]*$") then
                    keyStr = k
                else
                    -- Recursive call for complex keys (e.g. tables as keys, though rare for Luau string conversion)
                    keyStr = "[" .. _serializeValueForLuauString(k, visitedTables) .. "]"
                end
                table.insert(parts, keyStr .. " = " .. _serializeValueForLuauString(v_item, visitedTables))
            end
            visitedTables[value] = nil
            return "{ " .. table.concat(parts, ", ") .. " }"
        end
    else
        -- For functions, threads, other userdata that are not specifically handled:
        -- Return a string placeholder indicating the type.
        return string.format("%q", "<" .. valueType .. " (" .. tostring(value) .. ")>")
    end
end


return ToolHelpers
