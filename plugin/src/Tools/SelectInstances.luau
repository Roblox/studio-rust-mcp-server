-- SelectInstances.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local Selection = game:GetService("Selection")

local function execute(args)
    local success, result = pcall(function()
        local paths = args.paths

        if not paths or type(paths) ~= "table" then
            return ToolHelpers.FormatErrorResult("'paths' is required and must be an array of strings.")
        end

        local instancesToSelect = {}
        local findErrors = {}

        if #paths == 0 then
            -- Clear selection if an empty list is provided
            Selection:Set({})
            return ToolHelpers.FormatSuccessResult({
                message = "Selection cleared.",
                selected_paths = {}
            })
        end

        for _, pathString in ipairs(paths) do
            if type(pathString) == "string" then
                local instance, err = ToolHelpers.FindInstanceByPath(pathString)
                if instance then
                    table.insert(instancesToSelect, instance)
                else
                    table.insert(findErrors, {path = pathString, error = err or "Not found"})
                    print(("SelectInstances: Could not find instance at path: %s. Error: %s"):format(pathString, err or "Not found"))
                end
            else
                table.insert(findErrors, {path = tostring(pathString), error = "Path is not a string."})
            end
        end

        if #instancesToSelect > 0 then
            local setSuccess, setError = pcall(function()
                Selection:Set(instancesToSelect)
            end)
            if not setSuccess then
                 return ToolHelpers.FormatErrorResult("Failed to set selection: " .. tostring(setError))
            end
        end

        local currentSelection = Selection:Get()
        local currentSelectionPaths = {}
        for _, selectedInstance in ipairs(currentSelection) do
            table.insert(currentSelectionPaths, selectedInstance:GetFullName())
        end

        if #findErrors > 0 then
            return ToolHelpers.FormatSuccessResult({
                message = "Partially set selection. Some instances were not found.",
                selected_paths = currentSelectionPaths,
                errors = findErrors
            })
        else
            return ToolHelpers.FormatSuccessResult({
                message = ("Successfully selected %d instance(s)."):format(#instancesToSelect),
                selected_paths = currentSelectionPaths
            })
        end
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in SelectInstances: " .. tostring(result))
    end
end

return execute
