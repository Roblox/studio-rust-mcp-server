local Main = script:FindFirstAncestor("MCPStudioPlugin")
local MockWebSocketService = require(Main.MockWebSocketService)
local Types = require(Main.Types)

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local StudioService = game:GetService("StudioService")

local URI = "http://localhost:44755"
local RECEIVE_ENDPOINT = "/request"
local SEND_ENDPOINT = "/response"

if RunService:IsRunning() then
	return
end

local old_warn = warn
local function log(...)
	if false then
		old_warn(...)
	end
end

local function fetchBuiltinTools()
	local tools = {}
	for _, tool in Main.Tools:GetChildren() do
		if tool:IsA("ModuleScript") then
			table.insert(tools, require(tool) :: Types.ToolFunction)
		end
	end
	return tools -- This function is no longer used directly for dispatch
end

-- New: Load tools into a dictionary for named dispatch
local function loadToolFunctions()
    local toolModules = {}
    local toolsFolder = Main.Tools or script.Tools -- Prefer Main.Tools if defined, else script.Tools

    if toolsFolder then
        for _, toolModuleScript in ipairs(toolsFolder:GetChildren()) do
            if toolModuleScript:IsA("ModuleScript") then
                local success, toolFunction = pcall(require, toolModuleScript)
                if success and type(toolFunction) == "function" then
                    log("[MCP] Loaded tool: " .. toolModuleScript.Name)
                    toolModules[toolModuleScript.Name] = toolFunction
                else
                    log("[MCP] Error loading tool " .. toolModuleScript.Name .. ": " .. tostring(toolFunction))
                end
            end
        end
    else
        log("[MCP] Error: Tools folder not found.")
    end
    return toolModules
end

local toolFunctions = loadToolFunctions()
-- For debugging, print loaded tools
for name, _ in pairs(toolFunctions) do
    log("[MCP] Registered tool function: " .. name)
end

local function connectWebSocket()
	local client = MockWebSocketService:CreateClient(URI)
	client:SetReceiveEndpoint(RECEIVE_ENDPOINT)
	client:SetSendEndpoint(SEND_ENDPOINT)

	client.Opened:Once(function()
		log("[MCP] Connection opened")
	end)

	client.Closed:Once(function()
		log("[MCP] Connection closed")
	end)

	client.MessageReceived:Connect(function(message)
		log("[MCP] Message received")

		local decodedSuccess, body = pcall(HttpService.JSONDecode, HttpService, message)
		if not decodedSuccess or not body or type(body) ~= "table" then
			log("[MCP] Error: Failed to decode JSON message or invalid format: " .. (body or message))
			return
		end

		local id = body.id
		if not id or type(id) ~= "string" then
			log("[MCP] Error: Message ID is missing or not a string in body: ", body)
			return
		end

		local responseSent = false
		local function sendResponseOnce(responseContent, isError, originalToolNameForResponse)
			if not responseSent then
				responseSent = true
				local responseTable = {
					id = id, -- This is the MCP Transaction ID
					result = {
                        name = originalToolNameForResponse, -- This should be what Gemini called
                        response = responseContent
                    }
				}
                if isError then
                    -- Ensure the error response content is also a JSON string if it's not already
                    if type(responseContent) ~= "string" then
                         responseContent = HttpService:JSONEncode({error = {message = tostring(responseContent)}})
                    end
                    -- If ToolHelpers.FormatErrorResult already JSON encodes, this might double-encode.
                    -- For now, assume responseContent for error is a string (potentially JSON string from ToolHelpers).
                    responseTable.result.response = responseContent
                end

				local finalResponseJson, encodeErr = pcall(HttpService.JSONEncode, HttpService, responseTable)
				if not encodeErr then
					log("[MCP] Sending response: " .. finalResponseJson)
					client:Send(finalResponseJson)
				else
					log("[MCP] CRITICAL: Failed to encode final response: " .. tostring(encodeErr) .. " for original body: " .. message)
                    -- Fallback for critical encoding failure
                    local errorResponse = {
                        id = id,
                        result = {
                            name = originalToolNameForResponse or "unknown_tool",
                            response = HttpService:JSONEncode({error = {message = "Server failed to encode response."}})
                        }
                    }
                    client:Send(HttpService:JSONEncode(errorResponse))
				end
			end
		end

		local taskArgs = body.args
		if not taskArgs or type(taskArgs) ~= "table" then
			sendResponseOnce("Task arguments (body.args) are missing or not a table.", true, "unknown_task")
			return
		end

		local toolNameForExecution -- This is the name of the Luau script, e.g., "CreateInstance", "RunCode"
		local toolInputArgs = {} -- Arguments to pass to the Luau tool function
        local originalToolNameToRespondWith -- This is the name Gemini called, e.g. "CreateInstance"

		if taskArgs.ExecuteLuauByName and type(taskArgs.ExecuteLuauByName) == "table" then
			toolNameForExecution = taskArgs.ExecuteLuauByName.tool_name
            originalToolNameToRespondWith = toolNameForExecution -- For Luau tools, this is the same.
			local argumentsJson = taskArgs.ExecuteLuauByName.arguments_json

			if type(toolNameForExecution) ~= "string" or string.len(toolNameForExecution) == 0 then
				sendResponseOnce("ExecuteLuauByName: 'tool_name' is missing or invalid.", true, toolNameForExecution or "ExecuteLuauByName")
				return
			end
			if type(argumentsJson) ~= "string" then
				sendResponseOnce("ExecuteLuauByName: 'arguments_json' is missing or not a string.", true, toolNameForExecution)
				return
			end

			local decodeSuccess, decodedJsonArgs = pcall(HttpService.JSONDecode, HttpService, argumentsJson)
			if decodeSuccess then
				if type(decodedJsonArgs) == "table" then
					toolInputArgs = decodedJsonArgs
				else
					-- If JSON decoded to a non-table (e.g. just a string or number), wrap it if necessary or handle error
					log("[MCP] Warning: arguments_json for " .. toolNameForExecution .. " decoded to a non-table type: " .. type(decodedJsonArgs) .. ". Using as is or wrapping might be needed.")
					toolInputArgs = decodedJsonArgs -- Assuming tool can handle it or it's a simple value call
				end
			else
				log("[MCP] Error: Failed to JSONDecode arguments_json for tool " .. toolNameForExecution .. ": " .. tostring(decodedJsonArgs)) -- decodedJsonArgs is error msg here
				sendResponseOnce("ExecuteLuauByName: Failed to decode 'arguments_json': " .. tostring(decodedJsonArgs), true, toolNameForExecution)
				return
			end
			log("[MCP] Task Type: ExecuteLuauByName for tool: " .. toolNameForExecution)

		elseif taskArgs.RunCommand and type(taskArgs.RunCommand) == "table" then
			-- This case is for the Rust `run_command` tool, which we map to `RunCode.luau`
			toolNameForExecution = "RunCode"
            originalToolNameToRespondWith = "run_command" -- Gemini called "run_command" (or the Python agent mapped it)
			toolInputArgs = { command = taskArgs.RunCommand.command }
			if type(toolInputArgs.command) ~= "string" then
				sendResponseOnce("RunCommand: 'command' is missing or not a string.", true, originalToolNameToRespondWith)
				return
			end
			log("[MCP] Task Type: RunCommand, mapped to Luau tool: " .. toolNameForExecution)

		elseif taskArgs.InsertModel and type(taskArgs.InsertModel) == "table" then
			-- This case is for the Rust `insert_model` tool, which we map to `InsertModel.luau`
			toolNameForExecution = "InsertModel"
            originalToolNameToRespondWith = "insert_model" -- Gemini called "insert_model"
			toolInputArgs = { query = taskArgs.InsertModel.query }
			if type(toolInputArgs.query) ~= "string" then
				sendResponseOnce("InsertModel: 'query' is missing or not a string.", true, originalToolNameToRespondWith)
				return
			end
			log("[MCP] Task Type: InsertModel, mapped to Luau tool: " .. toolNameForExecution)
		else
			log("[MCP] Error: Unrecognized task structure in body.args: ", taskArgs)
			sendResponseOnce("Unrecognized task structure in body.args.", true, "unknown_task")
			return
		end

		if not toolNameForExecution then
			sendResponseOnce("Could not determine tool name for execution from task arguments.", true, originalToolNameToRespondWith or "unknown_tool")
			return
		end

        local toolFunc = toolFunctions[toolNameForExecution]
		if not toolFunc then
			sendResponseOnce("Tool function not found in toolFunctions map: " .. toolNameForExecution, true, originalToolNameToRespondWith)
			return
		end

		local recording = ChangeHistoryService:TryBeginRecording("StudioMCP - " .. toolNameForExecution)
		local success, result = pcall(toolFunc, toolInputArgs or {})

		if success then
			if type(result) == "table" and result.content then
				sendResponseOnce(result.content, result.isError, originalToolNameToRespondWith)
			else
				log("[MCP] Error: Tool " .. toolNameForExecution .. " returned unexpected result format: " .. tostring(result))
				sendResponseOnce("Tool " .. toolNameForExecution .. " returned an unexpected result format.", true, originalToolNameToRespondWith)
			end
		else
			log("[MCP] Error executing tool " .. toolNameForExecution .. ": " .. tostring(result))
			sendResponseOnce("Internal error executing tool " .. toolNameForExecution .. ": " .. tostring(result), true, originalToolNameToRespondWith)
		end

		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end
		log("[MCP] Handled request for original tool: " .. (originalToolNameToRespondWith or "unknown") .. ", executed as Luau: " .. toolNameForExecution)
	end)

	return client
end

local function getButtonImage()
	local ok, response = pcall(function()
		return StudioService:GetClassIcon("PackageLink").Image
	end)
	return ok and response or "rbxasset://textures/ui/GuiImagePlaceholder.png"
end

local currentClient: MockWebSocketService.MockWebSocketClient? = connectWebSocket() -- nil for default off
print("The MCP Studio plugin is ready for prompts.")

local toolbar = plugin:CreateToolbar("MCP")
local toggleButton = toolbar:CreateButton("Toggle MCP", "Toggle connection to the server", getButtonImage())
toggleButton.ClickableWhenViewportHidden = true
toggleButton:SetActive(currentClient ~= nil)

toggleButton.Click:Connect(function()
	if not currentClient then
		currentClient = connectWebSocket()
		print("The MCP Studio plugin is ready for prompts.")
	else
		currentClient:Close()
		currentClient = nil
		print("The MCP Studio plugin is stopped.")
	end
end)
