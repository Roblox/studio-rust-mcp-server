-- CreateInstance.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added

local function execute(args: Types.CreateInstanceArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local className = args.class_name
        local properties = args.properties or {} -- Default to empty table
        local parentPath = args.parent_path -- Use parent_path from args

        if not className or type(className) ~= "string" then
            return "'class_name' is required and must be a string." -- Return error string
        end

        if type(properties) ~= "table" then
             return "'properties', if provided, must be a table." -- Return error string
        end

        local createSuccess, newInstanceOrError = pcall(Instance.new, className)
        if not createSuccess then
            return ("Failed to create instance of type '%s': %s"):format(className, tostring(newInstanceOrError)) -- Return error string
        end
        local newInstance = newInstanceOrError

        local propertyErrors = {}
        local parentInstance = nil

        -- Handle Parent explicitly from parent_path argument
        if parentPath then
            if type(parentPath) == "string" then
                local foundParent, err = ToolHelpers.FindInstanceByPath(parentPath)
                if foundParent then
                    parentInstance = foundParent
                else
                    newInstance:Destroy() -- Clean up partially created instance
                    return ("Failed to find specified Parent at path: %s. %s"):format(parentPath, err or "Unknown error") -- Return error string
                end
            else
                -- This case should ideally be caught by type checking if parent_path is strictly string
                newInstance:Destroy()
                return ("'parent_path' property, if provided, must be a string path. Got type: %s"):format(typeof(parentPath)) -- Return error string
            end
        end

        -- Apply other properties (ensure "Parent" is not processed again if it was in properties)
        for propName, propValueInput in pairs(properties) do
            if string.lower(propName) ~= "parent" then -- Avoid processing Parent if it was also in properties
                local convertedValue, convertError = ToolHelpers.JsonToRobloxValue(propValueInput, newInstance.ClassName.."."..propName)
                if convertError then
                    table.insert(propertyErrors, ("Property '%s': Failed to convert input value: %s"):format(propName, convertError))
                else
                    local setPropSuccess, setError = pcall(function()
                        newInstance[propName] = convertedValue
                    end)
                    if not setPropSuccess then
                        table.insert(propertyErrors, ("Property '%s': Error setting value: %s"):format(propName, setError))
                    end
                end
            end
        end

        if #propertyErrors > 0 then
            newInstance:Destroy() -- Clean up
            return ("Error(s) applying properties to new %s: %s"):format(className, table.concat(propertyErrors, "; ")) -- Return error string
        end

        if parentInstance then
            newInstance.Parent = parentInstance
        end

        -- Return CreateInstanceResultData table
        local resultData: Types.CreateInstanceResultData = {
            message = ("Successfully created %s instance named '%s'."):format(className, newInstance.Name),
            instance_path = newInstance:GetFullName(),
            class_name = className,
        }
        return resultData
    end)

    if success then
        -- Pass the XXXResultData to FormatSuccessResult
        return ToolHelpers.FormatSuccessResult(resultOrError)
    else
        -- Pass the error message string to FormatErrorResult
        return ToolHelpers.FormatErrorResult("Internal error in CreateInstance: " .. tostring(resultOrError))
    end
end

return execute
