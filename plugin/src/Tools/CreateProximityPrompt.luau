-- CreateProximityPrompt.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local HttpService = game:GetService("HttpService") -- Added

local function execute(args: Types.CreateProximityPromptArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local parentPartPath = args.parent_part_path
        local propertiesJson = args.properties or {} -- Default to empty table

        if not parentPartPath or type(parentPartPath) ~= "string" then
            return "'parent_part_path' is required and must be a string."
        end
        if type(propertiesJson) ~= "table" then
            return "'properties', if provided, must be a table."
        end

        local parentPart, err = ToolHelpers.FindInstanceByPath(parentPartPath)
        if not parentPart then
            return ("Failed to find parent part at path: %s. %s"):format(parentPartPath, err or "Unknown error")
        end
        if not (parentPart:IsA("BasePart") or parentPart:IsA("Attachment") or parentPart:IsA("Model") or parentPart:IsA("Accessory")) then
             return ("Parent for ProximityPrompt must be a BasePart, Attachment, Model, or Accessory. Found: %s"):format(parentPart:GetClass().Name)
        end

        local prompt = Instance.new("ProximityPrompt")
        local propertyErrors = {}

        for propName, propValueInput in pairs(propertiesJson) do
            if string.lower(propName) == "parent" then
                -- Parent is parentPartPath, ignore from properties
            else
                local finalValueToSet = propValueInput
                local conversionErrorMsg = nil

                if type(propValueInput) == "table" then
                    -- Pass prompt instance for context if needed by converter
                    local converted_value, err_msg = ToolHelpers.ConvertTableToRobloxType(propValueInput, propName, prompt)
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
                        prompt[propName] = finalValueToSet
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
            prompt:Destroy()
            return ("Error(s) applying properties to new ProximityPrompt: %s"):format(table.concat(propertyErrors, "; "))
        end

        prompt.Parent = parentPart

        local resultData: Types.CreateProximityPromptResultData = {
            message = ("Successfully created ProximityPrompt under %s."):format(parentPartPath),
            prompt_path = prompt:GetFullName(),
            action_text = prompt.ActionText,
            object_text = prompt.ObjectText,
            max_activation_distance = prompt.MaxActivationDistance,
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
        return ToolHelpers.FormatErrorResult("Internal error in CreateProximityPrompt: " .. tostring(resultOrError))
    end
end

return execute
