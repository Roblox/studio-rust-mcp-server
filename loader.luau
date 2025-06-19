local MainModule = {
    ToolHelpers = require("plugin.src.ToolHelpers"),
    Types = require("plugin.src.Types"),
}

script = {}
function script:FindFirstAncestor(name)
    if name == "MCPStudioPlugin" then
        return MainModule
    end
    return nil
end

local f, err = loadfile("/tmp/test_load.luau", "bt", getfenv())
if not f then
    print("Failed to load /tmp/test_load.luau:", err)
    -- Do not return here, let it proceed to pcall(f) to see if that gives more info or if f is nil
end

local success, res = pcall(f) -- f will be nil if loadfile failed, pcall will catch this error
if not success then
    print("Error running test_load.luau (pcall(f)):", tostring(res)) -- Ensure res is converted to string
end
