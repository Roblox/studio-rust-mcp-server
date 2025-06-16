-- SetProperties.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added

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

        local propertyResults: {Types.PropertyWriteResult} = {}
        local overallSuccess = true
        local setPropsCount = 0
        local failedPropsCount = 0

        for propName, propValueInput in pairs(propertiesToSet) do
            local convertedValue, convertError = ToolHelpers.JsonToRobloxValue(propValueInput, instance:GetClass().Name.."."..propName)

            if convertError then
                table.insert(propertyResults, {
                    name = propName,
                    status = "conversion_error",
                    error_message = "Value conversion failed: " .. convertError,
                    original_value = propValueInput
                })
                failedPropsCount += 1
                overallSuccess = false
            else
                local setSuccess, setError = pcall(function()
                    instance[propName] = convertedValue
                end)

                if setSuccess then
                    table.insert(propertyResults, {
                        name = propName,
                        status = "success"
                    })
                    setPropsCount += 1
                else
                    table.insert(propertyResults, {
                        name = propName,
                        status = "set_error",
                        error_message = tostring(setError),
                        value_tried = convertedValue
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
