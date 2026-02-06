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
	return tools
end

local tools = fetchBuiltinTools()

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
local toggleButton = toolbar:CreateButton("MCP Server", "Show or hide the MCP Server panel", getButtonImage())
toggleButton.ClickableWhenViewportHidden = true
toggleButton:SetActive(currentClient ~= nil)

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	true,
	false,
	240,
	80,
	200,
	60
)
local statusWidget = plugin:CreateDockWidgetPluginGui("MCPStatus", widgetInfo)
statusWidget.Title = "MCP Status"
statusWidget.Enabled = true

local statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Size = UDim2.fromScale(1, 0.55)
statusLabel.Font = Enum.Font.SourceSansSemibold
statusLabel.TextSize = 18
statusLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
statusLabel.Parent = statusWidget

local segmentedContainer = Instance.new("Frame")
segmentedContainer.AnchorPoint = Vector2.new(0.5, 0.5)
segmentedContainer.BackgroundTransparency = 1
segmentedContainer.Position = UDim2.fromScale(0.5, 0.72)
segmentedContainer.Size = UDim2.fromOffset(180, 28)
segmentedContainer.Parent = statusWidget

local segmentedLayout = Instance.new("UIListLayout")
segmentedLayout.FillDirection = Enum.FillDirection.Horizontal
segmentedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
segmentedLayout.VerticalAlignment = Enum.VerticalAlignment.Center
segmentedLayout.Padding = UDim.new(0, 6)
segmentedLayout.Parent = segmentedContainer

local offButton = Instance.new("TextButton")
offButton.Size = UDim2.fromOffset(84, 26)
offButton.Font = Enum.Font.SourceSansSemibold
offButton.TextSize = 14
offButton.Text = "OFF"
offButton.AutoButtonColor = false
offButton.Parent = segmentedContainer

local offCorner = Instance.new("UICorner")
offCorner.CornerRadius = UDim.new(0, 7)
offCorner.Parent = offButton

local onButton = Instance.new("TextButton")
onButton.Size = UDim2.fromOffset(84, 26)
onButton.Font = Enum.Font.SourceSansSemibold
onButton.TextSize = 14
onButton.Text = "ON"
onButton.AutoButtonColor = false
onButton.Parent = segmentedContainer

local onCorner = Instance.new("UICorner")
onCorner.CornerRadius = UDim.new(0, 7)
onCorner.Parent = onButton

local function renderUIFromState(isServerOn: boolean)
	if isServerOn then
		onButton.BackgroundTransparency = 0
		onButton.BackgroundColor3 = Color3.fromRGB(46, 160, 67)
		onButton.TextColor3 = Color3.fromRGB(240, 240, 240)
		onButton.Active = false

		offButton.BackgroundTransparency = 0.6
		offButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		offButton.TextColor3 = Color3.fromRGB(200, 200, 200)
		offButton.Active = true
	else
		offButton.BackgroundTransparency = 0
		offButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		offButton.TextColor3 = Color3.fromRGB(240, 240, 240)
		offButton.Active = false

		onButton.BackgroundTransparency = 0.6
		onButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		onButton.TextColor3 = Color3.fromRGB(200, 200, 200)
		onButton.Active = true
	end
end

local function updateStatus(isConnected: boolean)
	toggleButton:SetActive(statusWidget.Enabled)
	statusLabel.Text = if isConnected then "MCP Server: ON" else "MCP Server: OFF"
	renderUIFromState(isConnected)
end

updateStatus(currentClient ~= nil)

local function setConnection(isConnected: boolean)
	if isConnected then
		currentClient = connectWebSocket()
		print("The MCP Studio plugin is ready for prompts.")
		updateStatus(true)
	else
		if currentClient then
			currentClient:Close()
			currentClient = nil
		end
		print("The MCP Studio plugin is stopped.")
		updateStatus(false)
	end
end

toggleButton.Click:Connect(function()
	statusWidget.Enabled = not statusWidget.Enabled
	toggleButton:SetActive(statusWidget.Enabled)
end)

offButton.MouseButton1Click:Connect(function()
	setConnection(false)
end)

onButton.MouseButton1Click:Connect(function()
	setConnection(true)
end)
