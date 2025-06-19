-- CreateGuiElement.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local PlayersService = ToolHelpers.GetPlayersService()
local StarterGuiService = ToolHelpers.GetStarterGuiService()
local HttpService = game:GetService("HttpService") -- Added

local function execute(args: Types.CreateGuiElementArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local elementType = args.element_type
        local parentPathArg = args.parent_path
        local propertiesJson = args.properties or {} -- Default to empty table

        if not elementType or type(elementType) ~= "string" then
            return "'element_type' is required (e.g., 'Frame', 'TextButton')."
        end
        if parentPathArg ~= nil and type(parentPathArg) ~= "string" then
            return "'parent_path' must be a string if provided."
        end
        if type(propertiesJson) ~= "table" then
            return "'properties' must be a table if provided."
        end

        local createSuccess, newElement = pcall(Instance.new, elementType)
        if not createSuccess then
            return ("Failed to create element of type '%s': %s"):format(elementType, tostring(newElement)) -- newElement is error
        end

        local actualParent: Instance? = nil
        local parentDeterminationError: string? = nil
        local effectiveParentPathForOutput: string? = nil

        local parentFromProperties = propertiesJson.Parent
        if parentFromProperties then
             if typeof(parentFromProperties) == "Instance" then -- Should not happen if propertiesJson is pure JSON
                actualParent = parentFromProperties
            elseif type(parentFromProperties) == "string" then
                parentPathArg = parentFromProperties -- Override arg with property if string
            else
                parentDeterminationError = "'Parent' property must be a string path."
            end
        end

        if not parentDeterminationError and parentPathArg then
            effectiveParentPathForOutput = parentPathArg
            if string.lower(parentPathArg) == "startergui" then
                actualParent = StarterGuiService
            else
                local found, err = ToolHelpers.FindInstanceByPath(parentPathArg)
                if not found then
                    parentDeterminationError = ("Parent not found at path: %s. %s"):format(parentPathArg, err or "")
                elseif elementType == "ScreenGui" and found:IsA("Player") then
                    actualParent = found:FindFirstChildOfClass("PlayerGui") or Instance.new("PlayerGui", found)
                elseif not (found:IsA("GuiBase") or found:IsA("GuiObject") or found:IsA("BasePlayerGui") or found:IsA("StarterGui") or found:IsA("Folder") or found:IsA("Model") or found == workspace) then
                    parentDeterminationError = ("Parent '%s' (type: %s) is not a valid GUI container."):format(parentPathArg, found:GetClass().Name)
                else
                    actualParent = found
                end
            end
        elseif not parentDeterminationError and elementType == "ScreenGui" and not actualParent then
            local localPlayer = PlayersService.LocalPlayer
            if localPlayer then
                actualParent = localPlayer:FindFirstChildOfClass("PlayerGui") or Instance.new("PlayerGui", localPlayer)
                effectiveParentPathForOutput = actualParent:GetFullName()
            else
                 parentDeterminationError = "ScreenGui needs a parent. LocalPlayer not found for default PlayerGui."
            end
        end

        if parentDeterminationError then
            (newElement :: Instance):Destroy()
            return parentDeterminationError
        end

        local propertyErrors = {}
        for propName, propValueInput in pairs(propertiesJson) do
            if string.lower(propName) ~= "parent" then -- Parent is handled by other logic

                local finalValueToSet = propValueInput
                local conversionErrorMsg = nil

                if type(propValueInput) == "table" then
                    -- Pass newElement for context (e.g. UDim2 for Size/Position)
                    local converted_value, err_msg = ToolHelpers.ConvertTableToRobloxType(propValueInput, propName, newElement)
                    if err_msg then
                        conversionErrorMsg = err_msg
                    else
                        finalValueToSet = converted_value
                    end
                end

                if conversionErrorMsg then
                    table.insert(propertyErrors, ("Property '%s': Conversion error: %s. Original: %s"):format(
                        propName,
                        conversionErrorMsg,
                        HttpService:JSONEncode(propValueInput)
                    ))
                else
                    local setSuccess, setError = pcall(function()
                        (newElement :: Instance)[propName] = finalValueToSet
                    end)
                    if not setSuccess then
                        table.insert(propertyErrors, ("Property '%s': Error setting value: %s. Original: %s, Attempted: %s"):format(
                            propName,
                            tostring(setError),
                            HttpService:JSONEncode(propValueInput),
                            HttpService:JSONEncode(finalValueToSet)
                        ))
                    end
                end
            end
        end

        if #propertyErrors > 0 then
            (newElement :: Instance):Destroy()
            return ("Error(s) applying properties to new %s: %s"):format(elementType, table.concat(propertyErrors, "; "))
        end

        if actualParent then
            (newElement :: Instance).Parent = actualParent
        elseif elementType == "ScreenGui" and not (newElement :: Instance).Parent then -- Should have been parented to PlayerGui or error
            (newElement :: Instance):Destroy()
            return "ScreenGui element failed to be parented correctly."
        elseif not (newElement :: Instance).Parent and not (elementType == "PlayerGui" or elementType == "StarterGui") then -- Most other GUI elements require a parent
            -- This case might indicate a logic flaw or an element type that doesn't need explicit parenting (rare for GUI)
             (newElement :: Instance):Destroy()
            return ("GUI Element '%s' of type %s requires a parent but none was resolved or set."):format((newElement :: Instance).Name, elementType)
        end

        local finalParentPath = (newElement :: Instance).Parent and (newElement :: Instance).Parent:GetFullName() or effectiveParentPathForOutput

        local resultData: Types.CreateGuiElementResultData = {
            message = ("Successfully created GUI element '%s' of type %s."):format((newElement :: Instance).Name, elementType),
            element_path = (newElement :: Instance):GetFullName(),
            element_type = elementType,
            parent_path_used = finalParentPath,
        }
        return resultData
    end)

    if success then
        if type(resultOrError) == "string" then
            return ToolHelpers.FormatErrorResult(resultOrError)
        else
            return ToolHelpers.FormatSuccessResult(resultOrError)
        end
    else
        return ToolHelpers.FormatErrorResult("Internal error in CreateGuiElement: " .. tostring(resultOrError))
    end
end

return execute
