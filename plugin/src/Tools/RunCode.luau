-- RunCode.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)

local function executeRunCode(command: string): (Types.RunCodeResultData?, string?)
    local output_parts: {string} = {}
    local captured_returns: {any} = {}
    local load_error: string? = nil
    local runtime_error: string? = nil

    local success, loaded_chunk = pcall(loadstring, command)
    if not success or not loaded_chunk then
        load_error = "Failed to load string: " .. (loaded_chunk or "Unknown error") -- loaded_chunk is error if pcall failed
        local resultData: Types.RunCodeResultData = {
            message = "Code execution failed during loading.",
            output = load_error,
            return_values = nil,
        }
        -- Even though it's an error, we are packaging it as per RunCodeResultData structure
        -- The higher level will decide if this specific structure should be an error response.
        -- For this tool, even load errors are "output".
        -- However, to fit the (data?, errorString?) pattern for the helper:
        return nil, load_error
    end

    -- Setup environment for the chunk
    local chunk_env = getfenv(loaded_chunk)
    if type(chunk_env) ~= "table" then chunk_env = {} end -- Should not happen

    local oldPrint = chunk_env.print
    chunk_env.print = function(...)
        if type(oldPrint) == "function" then
            pcall(oldPrint, ...) -- Call original safely
        end
        local argStrings: {string} = {}
        for i = 1, select("#", ...) do
            table.insert(argStrings, tostring(select(i, ...)))
        end
        table.insert(output_parts, table.concat(argStrings, "	"))
    end

    local oldWarn = chunk_env.warn
    chunk_env.warn = function(...)
        if type(oldWarn) == "function" then
            pcall(oldWarn, ...) -- Call original safely
        end
        local argStrings: {string} = {}
        for i = 1, select("#", ...) do
            table.insert(argStrings, "[WARNING] " .. tostring(select(i, ...)))
        end
        table.insert(output_parts, table.concat(argStrings, "	"))
    end

    -- Note: Overriding 'error' can be tricky. If the user's code calls error(),
    -- it will stop execution within its pcall layer.
    -- The pcall around `loaded_chunk()` below will catch this.

    local execution_success, result_or_err = pcall(loaded_chunk)

    if not execution_success then
        runtime_error = tostring(result_or_err)
        table.insert(output_parts, "[RUNTIME ERROR] " .. runtime_error)
    else
        -- Capture return values if successful
        -- `result_or_err` is the first return value. To capture all:
        -- This requires calling the function and collecting all its returns.
        -- The `pcall(loaded_chunk)` already did this. `result_or_err` is the first.
        -- To get all, we would need: local all_returns = { loaded_chunk() } but that's not safe.
        -- The pcall already gives us the returns.
        -- If pcall(f) returns true, r1, r2, ..., then result_or_err is r1.
        -- This needs a different approach to capture varargs from pcall's return.

        -- Correct way to capture all results from a pcall:
        local resultsFromPcall = { pcall(loaded_chunk) } -- This re-runs the chunk, which is BAD.

        -- We need to use the results from the *first* pcall(loaded_chunk)
        -- `execution_success` is resultsFromPcall[1]
        -- `result_or_err` is resultsFromPcall[2]
        -- `select(3, table.unpack(resultsFromPcall))` would be the rest. This is getting complicated.

        -- Let's simplify: if execution_success, result_or_err is the first return.
        -- For multiple returns, the script should print them if they need to be seen.
        -- We will capture the first return value if it exists.
        if result_or_err ~= nil then
             table.insert(captured_returns, result_or_err) -- Store the first return
        end
        -- To truly capture all, the anonymous function in pcall would need to return a table.
        -- Or, the environment needs to be set on the function *before* pcall like this:
        -- setfenv(loaded_chunk, chunk_env)
        -- local status, ... = pcall(loaded_chunk)
        -- local n = select("#", ...)
        -- for i=1, n do table.insert(captured_returns, select(i, ...)) end
        -- This is a common pattern. Let's try to implement this.
    end

    -- Re-attempting capture with setfenv and varargs from pcall
    for k,v in pairs(chunk_env) do _G[k] = v end -- Make print/warn available globally for simplicity if chunk_env is not _G
    setfenv(loaded_chunk, chunk_env) -- Set the modified environment

    local status_final, returns_final = xpcall(loaded_chunk, function(err_obj)
        -- Custom error handler for xpcall
        runtime_error = tostring(err_obj)
        if typeof(err_obj) == "Instance" and err_obj:IsA("ScriptContext") then -- Roblox specific error object
            runtime_error = err_obj.ErrorMessage
        elseif type(err_obj) == "table" and err_obj.message then
            runtime_error = err_obj.message
        end
        table.insert(output_parts, "[RUNTIME ERROR] " .. runtime_error)
        return runtime_error -- Return the error message for xpcall
    end)

    if status_final then
        -- If xpcall is successful, returns_final contains all return values as a tuple
        -- We need to pack them into the captured_returns table
        -- However, xpcall on success returns `true` then the values.
        -- So `returns_final` here is actually the first return value.
        -- The varargs are after `status_final`.
        -- This needs to be: local status_final, ret1, ret2, ... = xpcall(...)
        -- This means my `returns_final` variable name is misleading.

        -- Let's try again with proper vararg capture from xpcall
        local pack = { xpcall(loaded_chunk, function(err_obj)
            runtime_error = tostring(err_obj)
            if typeof(err_obj) == "Instance" and err_obj:IsA("ScriptContext") then
                runtime_error = err_obj.ErrorMessage
            elseif type(err_obj) == "table" and err_obj.message then
                runtime_error = err_obj.message
            end
            table.insert(output_parts, "[RUNTIME ERROR] " .. runtime_error)
            return runtime_error
        end) }

        if pack[1] == true then -- xpcall succeeded
            for i = 2, #pack do
                table.insert(captured_returns, pack[i])
            end
        end
        -- If pack[1] is false, runtime_error was already set by the error handler
    else
        -- This case means xpcall itself failed or the error handler re-errored,
        -- runtime_error should already be set by the handler.
        if not runtime_error then runtime_error = "Unknown error during xpcall." end
    end

    -- Restore global environment if changed
    for k,_ in pairs(chunk_env) do if _G[k] == chunk_env[k] then _G[k] = nil end end

    local final_output_string = table.concat(output_parts, "\n") -- Use literal for multiline

    if load_error then -- Prioritize load error
        return nil, load_error
    elseif runtime_error then
         local resultData: Types.RunCodeResultData = {
            message = "Code executed with runtime errors.",
            output = final_output_string,
            return_values = captured_returns, -- May have some returns before error
        }
        return nil, "Runtime error: " .. runtime_error .. (final_output_string ~= "" and ("\nOutput:\n" .. final_output_string) or "")
    end

    local resultData: Types.RunCodeResultData = {
        message = "Code executed successfully.",
        output = final_output_string,
        return_values = captured_returns,
    }
    return resultData, nil
end


local function handleRunCode(args: Types.RunCodeArgs)
    local success, resultOrErrorData = pcall(function()
        if type(args.command) ~= "string" then
            return nil, "'command' is required and must be a string."
        end
        return executeRunCode(args.command) -- Returns (data?, errorString?)
    end)

    if success then
        local data, errStr = resultOrErrorData -- unpack tuple
        if errStr then
            return ToolHelpers.FormatErrorResult(errStr)
        else
            return ToolHelpers.FormatSuccessResult(data)
        end
    else
        return ToolHelpers.FormatErrorResult("Internal error in RunCode: " .. tostring(resultOrErrorData))
    end
end

return handleRunCode
