local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ConsoleOutput = require(Main.Utils.ConsoleOutput)
local DataModelType = require(Main.Utils.DataModelType)
local GameStopUtil = require(Main.Utils.GameStopUtil)
local MockWebSocketService = require(Main.MockWebSocketService)
local PluginUtils = require(Main.Utils.PluginUtils)
local Types = require(Main.Types)

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local StudioService = game:GetService("StudioService")

local URI = "http://localhost:44755"

PluginUtils.plugin = plugin

local datamodelType = DataModelType.getDataModelType()

if datamodelType == "Server" then
	task.spawn(GameStopUtil.monitorForStopPlay)
end

if RunService:IsRunning() then
	return
end

local connMessageOut = ConsoleOutput.startListener()
plugin.Unloading:Connect(function()
	connMessageOut:Disconnect()
end)

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

local enableRetry = false

local function doRequest(path: string, method: "GET" | "POST", body: any): (boolean, any)
	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = URI .. path,
			Method = method,
			Headers = { ["Content-Type"] = "application/json" },
			Body = if body then HttpService:JSONEncode(body) else nil,
			Compress = Enum.HttpCompression.None,
		})
	end)
	-- print("Client Register/Unregistration Response:", path, response)
	if not ok or not response or not response.Success then
		return false, nil
	end
	local decodeSuccess, decoded = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)
	return decodeSuccess, decoded
end

local currentClientId: string? = nil
local robloxBridgeBindable: BindableEvent = Instance.new("BindableEvent")

local function connectWebSocket(): (MockWebSocketService.MockWebSocketClient?, string?)
	local ok, registerResult = doRequest("/register", "POST", { datamodel_type = "Edit" })
	-- print("Client Register/Unregistration Response Decoded:", registerResult)
	if not ok or not registerResult or not registerResult.client_id then
		warn("[MCP] Failed to register with server")
		return nil, nil
	end
	local clientId: string = registerResult.client_id
	currentClientId = clientId

	local client = MockWebSocketService:CreateClient(URI)
	client:SetReceiveEndpoint("/request?client_id=" .. clientId)
	client:SetSendEndpoint("/response?client_id=" .. clientId)

	client.Opened:Once(function()
		log("[MCP] Connection opened")
	end)

	client.Closed:Once(function()
		currentClientId = nil
		doRequest("/unregister", "POST", { client_id = clientId })
		log("[MCP] Connection closed")
	end)

	client.MessageReceived:Connect(function(message)
		log("[MCP] Message received")

		local body = HttpService:JSONDecode(message)
		if not body then
			return
		end
		if body.type == "roblox_event_bridge" then
			-- Broadcast event; optionally handle body.event
			robloxBridgeBindable:Fire(body)
			return
		end
		assert(body.id and body.args, "Invalid message received")

		local id: string = body.id
		local responseSent = false
		local function sendResponseOnce(response: string)
			if not responseSent then
				log("[MCP] Sending response:" .. response)
				responseSent = true
				client:Send({
					type = "tool_call_response",
					id = id,
					response = response,
					client_id = clientId,
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

local currentClient: MockWebSocketService.MockWebSocketClient? = nil
local active = false

local function startWebSocket()
	enableRetry = true
	while enableRetry do
		print("Connecting to server...")
		local client = connectWebSocket()
		if client then
			currentClient = client
			client.Closed:Once(function()
				if enableRetry then
					task.spawn(function()
						print("Connection closed, retrying in 5 seconds...")
						task.wait(5)
						startWebSocket()
					end)
				end
			end)
			break
		end
		task.wait(5)
	end
end

local function stopWebSocket()
	enableRetry = false
	currentClientId = nil
	if currentClient then
		currentClient:Close()
		currentClient = nil
	end
end

startWebSocket()
print("The MCP Studio plugin is ready for prompts.")

local function testEventBridge()
	if not currentClient then
		return
	end

	robloxBridgeBindable.Event:Connect(function(body)
		print("Received event:", body)
	end)

	while true do
		print("Sending Roblox Bridge event...")
		currentClient:Send({
			type = "roblox_event_bridge",
			event = "test event 1234567890",
			client_id = currentClientId,
		})
		task.wait(5)
	end
end

testEventBridge()

local toolbar = plugin:CreateToolbar("MCP")
local toggleButton = toolbar:CreateButton("Toggle MCP", "Toggle connection to the server", getButtonImage())
toggleButton.ClickableWhenViewportHidden = true
toggleButton:SetActive(active)

toggleButton.Click:Connect(function()
	if active then
		stopWebSocket()
	else
		startWebSocket()
	end
end)
