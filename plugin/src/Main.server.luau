-- Main.luau - FINAL, ROBUST VERSION

local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)

-- Initialize ToolHelpers with Roblox services
local robloxServices = {
    Game = game,
    Workspace = game:GetService("Workspace"),
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    ServerStorage = game:GetService("ServerStorage"),
    Lighting = game:GetService("Lighting"),
    StarterGui = game:GetService("StarterGui"),
    StarterPlayer = game:GetService("StarterPlayer"),
    Teams = game:GetService("Teams"),
    TextChatService = game:GetService("TextChatService"),
    ServerScriptService = game:GetService("ServerScriptService"),
    SoundService = game:GetService("SoundService"),
    StarterPack = game:GetService("StarterPack"),
    UserInputService = game:GetService("UserInputService"),
    DebrisService = game:GetService("Debris"),
    CollectionService = game:GetService("CollectionService"),
    PathfindingService = game:GetService("PathfindingService"),
    TextService = game:GetService("TextService"),
    MarketplaceService = game:GetService("MarketplaceService"),
    DataStoreService = game:GetService("DataStoreService"),
    InsertService = game:GetService("InsertService"),
    Selection = game:GetService("Selection"),
    -- Workspace, Lighting, UserInputService, SoundService are already confirmed to be present
    TeleportService = game:GetService("TeleportService"),
    TweenService = game:GetService("TweenService")
}
ToolHelpers.InitServices(robloxServices)

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local StudioService = game:GetService("StudioService")

local URI = "http://localhost:44755/mcp" -- Single, unified endpoint
local POLL_WAIT_TIME = 1

if RunService:IsRunning() then return end

local function loadToolFunctions()
    local toolModules = {}
    local toolsFolder = Main and Main.Tools or script.Tools
    if toolsFolder then
        for _, toolModuleScript in ipairs(toolsFolder:GetChildren()) do
            if toolModuleScript:IsA("ModuleScript") then
                local s, f = pcall(require, toolModuleScript)
                if s and type(f) == "function" then
                    toolModules[toolModuleScript.Name] = f
                else
                    warn(("[MCP Diagnostics] Failed to load tool %s: %s"):format(toolModuleScript.Name, tostring(f)))
                end
            end
        end
    end
    return toolModules
end

local toolFunctions = loadToolFunctions()
local isConnected = false
local pollCoroutine = nil

local function poll_and_execute()
    local last_result_json = nil
    local last_task_id = nil

    while isConnected do
        local ok, response_body = pcall(function()
            local request_options = {
                Url = URI,
                Method = "POST",
                Headers = {}, -- This MUST be a dictionary
                Body = ""
            }

            if last_result_json and last_task_id then
                -- We have a result to send back. Include the custom header and body.
                request_options.Headers = { ["X-MCP-Task-ID"] = last_task_id }
                request_options.Body = last_result_json
            end
            
            local response = HttpService:RequestAsync(request_options)
            if response.Success then
                return response.Body
            else
                -- Throw an error to be caught by pcall
                error(response.StatusMessage)
            end
        end)
        
        -- Clear the last result after attempting to send it, regardless of success.
        last_result_json = nil
        last_task_id = nil

        if not isConnected then break end

        if not ok then
            -- ===================================================================
            -- THE FINAL FIX IS HERE: Retry on connection failure.
            -- ===================================================================
            warn("[MCP] Request failed: " .. tostring(response_body) .. ". Retrying...")
            task.wait(2) -- Wait 2 seconds on network errors before trying again.
            continue -- Skip the rest of the loop and retry the request.
        end
        
        -- A successful request was made. Process the response from the server.
        if response_body and response_body ~= "" then
            local loadedFunction, loadError = loadstring(response_body)
            if loadedFunction then
                local successCall, body = pcall(loadedFunction)
                if successCall and type(body) == "table" and type(body.id) == "string" then
                    local id = body.id
                    local taskArgs = body.args or {}
                    
                    local toolNameForExecution, toolInputArgs

                    if taskArgs.ExecuteLuauByName then
                        toolNameForExecution = taskArgs.ExecuteLuauByName.tool_name
                        local argFunc, err = loadstring(taskArgs.ExecuteLuauByName.arguments_luau)
                        if argFunc then
                            local s, r = pcall(argFunc); if s then toolInputArgs = r else toolInputArgs = { error = tostring(r) } end
                        else
                            toolInputArgs = { error = tostring(err) }
                        end
                    elseif taskArgs.RunCommand then
                        toolNameForExecution = "RunCode"
                        toolInputArgs = { command = taskArgs.RunCommand.command }
                    elseif taskArgs.InsertModel then
                        toolNameForExecution = "InsertModel"
                        toolInputArgs = { query = taskArgs.InsertModel.query }
                    else
                        toolInputArgs = { error = "Unrecognized task structure" }
                        toolNameForExecution = "error_handler"
                    end
                    
                    local toolFunc = toolFunctions[toolNameForExecution]
                    local result_table
                    if toolFunc then
                        local recording = ChangeHistoryService:TryBeginRecording("StudioMCP - " .. toolNameForExecution)
                        local s, r = pcall(toolFunc, toolInputArgs)
                        if s then result_table = r else result_table = ToolHelpers.FormatErrorResult("Tool execution error: " .. tostring(r)) end
                        if recording then ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
                    else
                        result_table = ToolHelpers.FormatErrorResult("Tool not found: " .. tostring(toolNameForExecution))
                    end
                    
                    last_task_id = id
                    last_result_json = HttpService:JSONEncode(result_table)
                else
                     warn("[MCP] Malformed task from server:", tostring(body))
                end
            else
                warn("[MCP] Invalid Luau from server:", tostring(loadError))
            end
        end
        
        task.wait(POLL_WAIT_TIME)
    end
end

local function connect()
    if isConnected then return end
    isConnected = true
    pollCoroutine = coroutine.create(poll_and_execute)
    coroutine.resume(pollCoroutine)
    print("MCP Connected.")
end

local function disconnect()
    if not isConnected then return end
    isConnected = false
    pollCoroutine = nil
    print("MCP Disconnected.")
end

-- UI Setup
local toolbar = plugin:CreateToolbar("MCP")
local button = toolbar:CreateButton("Toggle MCP", "Toggle MCP Connection", "rbxassetid://448334594")
button.ClickableWhenViewportHidden = true

button.Click:Connect(function()
    if isConnected then disconnect() else connect() end
    button:SetActive(isConnected)
end)

-- Initial state
connect()
button:SetActive(isConnected)