local Main = script:FindFirstAncestor("MCPStudioPlugin")
local MockWebSocketService = require(Main.MockWebSocketService)
local Types = require(Main.Types)
local OutputCapture = require(Main.OutputCapture)

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
	return tools
end

local tools = fetchBuiltinTools()

-- Initialize output capture (persistent connection to LogService)
-- This captures all output messages from this point forward
OutputCapture.initialize()

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

		local body = HttpService:JSONDecode(message)
		assert(body and body.id and body.args, "Invalid message received")

		local id: string = body.id
		local responseSent = false
		local function sendResponseOnce(response: string)
			if not responseSent then
				log("[MCP] Sending response:" .. response)
				responseSent = true
				client:Send({
					id = id,
					response = response,
				})
			end
		end

		local args: Types.ToolArgs = body.args
		local recording = ChangeHistoryService:TryBeginRecording("StudioMCP")

		for _, tool in tools do
			local success, response = pcall(tool, args)

			if success and response then
				sendResponseOnce(response)
			elseif not success then
				sendResponseOnce("Error handling request: " .. tostring(response))
			end
		end

		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end

		sendResponseOnce("No tool found to handle request")
		log("[MCP] Successfully handled request")
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

-- Clean up resources when plugin unloads to prevent memory leaks
plugin.Unloading:Connect(function()
	if currentClient then
		currentClient:Close()
		currentClient = nil
	end
	OutputCapture.shutdown()
end)
