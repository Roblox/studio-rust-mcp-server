-- SetProperties.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local HttpService = game:GetService("HttpService") -- Added

-- This tool will now be a direct alias or very similar to SetInstanceProperties
local function execute(args: Types.SetPropertiesArgs) -- Type annotation added
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

        local propertyResults: {Types.PropertyWriteResult} = {} -- Ensure Types.PropertyWriteResult can hold new fields
        local overallSuccess = true
        local setPropsCount = 0
        local failedPropsCount = 0

        for propName, propValueInput in pairs(propertiesToSet) do
            local finalValueToSet = propValueInput
            local conversionErrorMsg = nil

            if type(propValueInput) == "table" then
                local converted_value, err_msg = ToolHelpers.ConvertTableToRobloxType(propValueInput, propName, instance)
                if err_msg then
                    conversionErrorMsg = err_msg
                else
                    finalValueToSet = converted_value
                end
            end

            if conversionErrorMsg then
                table.insert(propertyResults, {
                    name = propName,
                    status = "conversion_error",
                    error_message = conversionErrorMsg,
                    original_value = HttpService:JSONEncode(propValueInput)
                })
                failedPropsCount += 1
                overallSuccess = false
            else
                local setSuccess, setError = pcall(function()
                    instance[propName] = finalValueToSet
                end)

                if setSuccess then
                    table.insert(propertyResults, {
                        name = propName,
                        status = "success"
                        -- Consider adding value_set = finalValueToSet if not too verbose or problematic for SimpleTableToString
                    })
                    setPropsCount += 1
                else
                    table.insert(propertyResults, {
                        name = propName,
                        status = "set_error",
                        error_message = tostring(setError),
                        original_value = HttpService:JSONEncode(propValueInput),
                        attempted_value = HttpService:JSONEncode(finalValueToSet)
                    })
                    failedPropsCount += 1
                    overallSuccess = false
                end
            end
        end

        local message: string
        if failedPropsCount > 0 then
            message = ("Attempted to set %d properties for %s. %d succeeded, %d failed."):format(setPropsCount + failedPropsCount, path, setPropsCount, failedPropsCount)
        else
            message = ("Successfully set %d properties for instance %s."):format(setPropsCount, path)
        end

        local resultData: Types.SetPropertiesResultData = {
            instance_path = path,
            results = propertyResults,
            message = message,
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
        return ToolHelpers.FormatErrorResult("Internal error in SetProperties: " .. tostring(resultOrError))
    end
end

return execute
