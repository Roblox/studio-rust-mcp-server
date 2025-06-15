-- CreateProximityPrompt.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)

local function execute(args)
    local success, pcall_result = pcall(function()
        local parentPartPath = args.parent_part_path
        local propertiesJson = args.properties -- Optional

        if not parentPartPath or type(parentPartPath) ~= "string" then
            return ToolHelpers.FormatErrorResult("'parent_part_path' is required and must be a string.")
        end
        if propertiesJson ~= nil and type(propertiesJson) ~= "table" then
            return ToolHelpers.FormatErrorResult("'properties' must be a table if provided.")
        end

        local parentPart, err = ToolHelpers.FindInstanceByPath(parentPartPath)
        if not parentPart then
            return ToolHelpers.FormatErrorResult("Failed to find parent part at path: " .. parentPartPath .. ". " .. (err or ""))
        end
        if not parentPart:IsA("BasePart") and not parentPart:IsA("Attachment") and not parentPart:IsA("Model") then
             return ToolHelpers.FormatErrorResult("Parent for ProximityPrompt must be a BasePart, Attachment, or Model. Found: " .. parentPart:GetClass())
        end

        local prompt = Instance.new("ProximityPrompt")

        if propertiesJson then
            for propName, propValueJson in pairs(propertiesJson) do
                local convertedValue = ToolHelpers.JsonToRobloxValue(propValueJson)
                local setSuccess, setError = pcall(function()
                    prompt[propName] = convertedValue
                end)
                if not setSuccess then
                    print(("CreateProximityPrompt: Error setting property '%s': %s"):format(propName, setError))
                    -- Potentially accumulate errors or fail early
                end
            end
        end

        prompt.Parent = parentPart

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully created ProximityPrompt under %s."):format(parentPartPath),
            prompt_path = prompt:GetFullName(),
            -- Include key properties in response for confirmation
            action_text = prompt.ActionText,
            object_text = prompt.ObjectText,
            max_activation_distance = prompt.MaxActivationDistance
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in CreateProximityPrompt: " .. tostring(pcall_result))
    end
end

return execute
