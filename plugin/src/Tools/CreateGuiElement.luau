-- CreateGuiElement.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local PlayersService = game:GetService("Players") -- Needed for PlayerGui
local StarterGuiService = game:GetService("StarterGui")

local function execute(args)
    local success, pcall_result = pcall(function()
        local elementType = args.element_type
        local parentPathArg = args.parent_path -- Optional
        local propertiesJson = args.properties -- Optional

        if not elementType or type(elementType) ~= "string" then
            return ToolHelpers.FormatErrorResult("'element_type' is required and must be a string (e.g., 'Frame', 'TextButton').")
        end
        if parentPathArg ~= nil and type(parentPathArg) ~= "string" then
            return ToolHelpers.FormatErrorResult("'parent_path' argument must be a string if provided.")
        end
        if propertiesJson ~= nil and type(propertiesJson) ~= "table" then
            return ToolHelpers.FormatErrorResult("'properties' must be a table if provided.")
        end

        local newElement = Instance.new(elementType)
        local actualParent = nil
        local parentDeterminationError = nil

        -- Determine effective parent path (from properties or argument)
        local effectiveParentPath = parentPathArg
        if propertiesJson and propertiesJson.Parent and type(propertiesJson.Parent) == "string" then
            effectiveParentPath = propertiesJson.Parent
        end

        if effectiveParentPath then
            if string.lower(effectiveParentPath) == "startergui" then
                actualParent = StarterGuiService
            else
                local foundParent, err = ToolHelpers.FindInstanceByPath(effectiveParentPath)
                if not foundParent then
                    parentDeterminationError = ("Failed to find specified parent at path: %s. %s"):format(effectiveParentPath, err or "")
                elseif elementType == "ScreenGui" and foundParent:IsA("Player") then
                    actualParent = foundParent:FindFirstChildOfClass("PlayerGui")
                    if not actualParent then
                        -- Attempt to create PlayerGui if it doesn't exist (should normally exist for valid players)
                        if foundParent == PlayersService.LocalPlayer then -- Only for LocalPlayer context
                            actualParent = Instance.new("PlayerGui")
                            actualParent.Parent = foundParent
                        else
                             parentDeterminationError = ("PlayerGui not found for player: %s. Cannot parent ScreenGui there."):format(foundParent.Name)
                        end
                    end
                elseif not (foundParent:IsA("GuiElement") or foundParent:IsA("Frame") or foundParent:IsA("ScreenGui") or foundParent:IsA("GuiObject") or foundParent:IsA("PlayerGui") or foundParent:IsA("StarterGui") or foundParent:IsA("Folder") or foundParent:IsA("Model") or typeof(foundParent) == "Instance") then
                     parentDeterminationError = ("Parent '%s' is not a valid GUI container or standard parent type, it is a %s."):format(effectiveParentPath, foundParent:GetClass())
                else
                    actualParent = foundParent
                end
            end
        elseif elementType == "ScreenGui" then
            -- Default for ScreenGui if no parent is specified
            local localPlayer = PlayersService.LocalPlayer
            if localPlayer then
                actualParent = localPlayer:FindFirstChildOfClass("PlayerGui")
                if not actualParent then -- Should be rare for a valid LocalPlayer context
                    actualParent = Instance.new("PlayerGui")
                    actualParent.Parent = localPlayer
                end
            else
                -- As per Python description: "this will error if LocalPlayer is not available"
                parentDeterminationError = "ScreenGui needs a parent (Player path for PlayerGui, or 'StarterGui'). LocalPlayer not available for default PlayerGui, and no parent_path provided."
            end
        end

        -- Apply other properties
        if propertiesJson then
            for propName, propValueJson in pairs(propertiesJson) do
                if string.lower(propName) ~= "parent" then -- Parent handled above
                    local convertedValue = ToolHelpers.JsonToRobloxValue(propValueJson, newElement:GetClass().."."..propName) -- Provide type hint
                    local setSuccess, setError = pcall(function()
                        newElement[propName] = convertedValue
                    end)
                    if not setSuccess then
                        -- Accumulate property errors? For now, just print.
                        print(("CreateGuiElement: Error setting property '%s' on new %s: %s"):format(propName, elementType, setError))
                    end
                end
            end
        end

        if parentDeterminationError then
            -- If there was an error determining parent, and no parent was resolved, return error.
            -- If actualParent was resolved despite some warning, we can proceed to parent.
            if not actualParent then
                 newElement:Destroy() -- Clean up unparented element
                 return ToolHelpers.FormatErrorResult(parentDeterminationError)
            end
        end

        if actualParent then
            newElement.Parent = actualParent
        elseif not actualParent and elementType ~= "ScreenGui" and not (propertiesJson and propertiesJson.Parent) then
            -- Most non-ScreenGuis should have a parent specified either via arg or properties.
            -- If not, they are created unparented. This might be intended by user.
            print(("CreateGuiElement: Warning - Element '%s' of type %s created without a specified parent."):format(newElement.Name, elementType))
        elseif not actualParent and elementType == "ScreenGui" then
            -- This case should have been caught by parentDeterminationError if LocalPlayer was nil.
            -- If somehow it reaches here, it means no valid parent for ScreenGui.
            newElement:Destroy()
            return ToolHelpers.FormatErrorResult("ScreenGui element could not be parented. Ensure LocalPlayer is available or specify a parent like 'StarterGui'.")
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully created GUI element '%s' of type %s."):format(newElement.Name, elementType),
            element_path = newElement:GetFullName(),
            element_type = elementType,
            parent_path_used = actualParent and actualParent:GetFullName() or "None (created unparented or error)"
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in CreateGuiElement: " .. tostring(pcall_result))
    end
end

return execute
