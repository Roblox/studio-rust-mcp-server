-- SelectInstances.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local Selection = game:GetService("Selection")

local function execute(args: Types.SelectInstancesArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local paths = args.paths

        if not paths or type(paths) ~= "table" then
            return "'paths' is required and must be an array of strings."
        end

        local instancesToSelect: {Instance} = {}
        local findErrors: {Types.PathResolutionError} = {}
        local message: string

        if #paths == 0 then
            local setEmptySuccess, setEmptyError = pcall(Selection.Set, Selection, {})
            if not setEmptySuccess then
                return "Failed to clear selection: " .. tostring(setEmptyError)
            end
            local resultData: Types.SelectInstancesResultData = {
                message = "Selection cleared as an empty 'paths' array was provided.",
                selected_paths = {},
                selection_count = 0,
            }
            return resultData
        end

        for _, pathString in ipairs(paths) do
            if type(pathString) == "string" then
                local instance, err = ToolHelpers.FindInstanceByPath(pathString)
                if instance then
                    table.insert(instancesToSelect, instance)
                else
                    table.insert(findErrors, {path = pathString, error = err or "Not found"})
                end
            else
                table.insert(findErrors, {path = tostring(pathString), error = "Path entry is not a string."})
            end
        end

        if #instancesToSelect > 0 then
            local setSuccess, setError = pcall(Selection.Set, Selection, instancesToSelect)
            if not setSuccess then
                 return "Failed to set selection with found instances: " .. tostring(setError)
            end
        elseif #findErrors > 0 and #instancesToSelect == 0 then
            -- All paths resulted in errors, build a specific error message to return as string
            local errorMessages = {}
            for _, e in ipairs(findErrors) do table.insert(errorMessages, ("Path '%s': %s"):format(e.path, e.error)) end
            return "No valid instances found from provided paths to select. Errors: " .. table.concat(errorMessages, "; ")
        end

        local currentSelection = Selection:Get()
        local currentSelectionPaths: {string} = {}
        for _, selectedInstance in ipairs(currentSelection) do
            table.insert(currentSelectionPaths, selectedInstance:GetFullName())
        end

        if #findErrors > 0 then
            message = ("Partially set selection. %d instance(s) selected. %d path(s) resulted in errors."):format(#currentSelectionPaths, #findErrors)
        elseif #instancesToSelect == 0 and #paths > 0 then
            message = "No instances were selected from the provided paths."
        else
            message = ("Successfully selected %d instance(s)."):format(#currentSelectionPaths)
        end

        local resultData: Types.SelectInstancesResultData = {
            message = message,
            selected_paths = currentSelectionPaths,
            selection_count = #currentSelectionPaths,
        }
        if #findErrors > 0 then
            resultData.errors_finding_paths = findErrors
        end
        return resultData
    end)

    if success then
        if type(resultOrError) == "string" then
            return ToolHelpers.FormatErrorResult(resultOrError)
        else
            return ToolHelpers.FormatSuccessResult(resultOrError)
        end
    else
        return ToolHelpers.FormatErrorResult("Internal error in SelectInstances: " .. tostring(resultOrError))
    end
end

return execute
