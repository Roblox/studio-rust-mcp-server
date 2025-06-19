-- SetInstanceProperties.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added

local function execute(args: Types.SetInstancePropertiesArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local path = args.path
        local propertiesToSet = args.properties

        if not path or type(path) ~= "string" then
            return "'path' is required and must be a string."
        end
        if not propertiesToSet or type(propertiesToSet) ~= "table" then
            return "'properties' is required and must be a table."
        end
        if next(propertiesToSet) == nil then
            return "'properties' table cannot be empty."
        end

        local instance, err = ToolHelpers.FindInstanceByPath(path)
        if not instance then
            return ("Failed to find instance at path: %s. %s"):format(path, err or "Unknown error")
        end

        local succeededProps = {}
        local failedProps = {}
        local overallSuccess = true -- Tracks if all properties were set successfully

        for propName, propValueInput in pairs(propertiesToSet) do
            local finalValueToSet = propValueInput
            local conversionErrorMsg = nil
            -- propertySetSuccessfully is implicitly handled by whether conversionErrorMsg is set or pcall succeeds

            if propName:lower() == "parent" then
                if type(propValueInput) == "string" then
                    -- Attempt to find the new parent instance by path
                    local newParentInstance, findError = ToolHelpers.FindInstanceByPath(propValueInput)
                    if newParentInstance then
                        finalValueToSet = newParentInstance
                    else
                        conversionErrorMsg = ("Invalid Parent path: %s - %s"):format(propValueInput, findError or "not found")
                    end
                elseif propValueInput == nil then
                    finalValueToSet = nil -- Explicitly allow setting Parent to nil (detach)
                else
                    -- If Parent value is not a string and not nil, it's an invalid type for a path
                    conversionErrorMsg = ("Invalid type for Parent property: expected string path or nil, got %s."):format(type(propValueInput))
                end
            elseif type(propValueInput) == "table" then
                -- For other properties, or if Parent was passed as a table (though schema implies path string for Parent)
                local converted_value, err_msg = ToolHelpers.ConvertTableToRobloxType(propValueInput, propName, instance)
                if err_msg then
                    conversionErrorMsg = err_msg
                else
                    finalValueToSet = converted_value
                end
            end

            if conversionErrorMsg then
                -- This handles errors from Parent path resolution/type check, or from ConvertTableToRobloxType
                failedProps[propName] = "Conversion/Resolution error: " .. conversionErrorMsg
                overallSuccess = false
            else
                -- Attempt to set the property
                local setSuccess, setError = pcall(function()
                    instance[propName] = finalValueToSet
                end)

                if setSuccess then
                    table.insert(succeededProps, propName)
                else
                    failedProps[propName] = "Error setting property: " .. tostring(setError)
                    overallSuccess = false
                end
            end
        end

        local responseData = {
            succeeded_properties = succeededProps,
            failed_properties = failedProps,
            instance_path = path, -- Include for context
        }

        local HttpService = game:GetService("HttpService")
        local jsonResponse = HttpService:JSONEncode(responseData)

        if not overallSuccess then
            -- Return a special table that the outer logic can use to call FormatErrorResult
            -- while still providing the JSON data.
            return { is_partial_error = true, data = jsonResponse }
        end

        return jsonResponse -- This will be the jsonResponse string for full success
    end)

    if success then
        if type(resultOrError) == "string" then
            -- This covers initial errors like instance not found or invalid args
            return ToolHelpers.FormatErrorResult(resultOrError, {error_type = "PreconditionFailed"})
        elseif resultOrError and resultOrError.is_partial_error then
            -- Some properties failed to set, instance was found, args were ok.
            -- The 'data' field contains the JSON string.
            return ToolHelpers.FormatErrorResult(resultOrError.data, {partial_failure = true})
        else
            -- Full success, all properties set. resultOrError is the JSON string.
            -- Manually construct the success response.
            return { content = { { type = "text", text = resultOrError } }, isError = false }
        end
    else
        -- pcall for the main execution failed
        local err_msg = "Internal error in SetInstanceProperties: " .. tostring(resultOrError)
        return ToolHelpers.FormatErrorResult(err_msg, {internal_error_details = tostring(resultOrError), is_luau_error = true})
    end
end

return execute
