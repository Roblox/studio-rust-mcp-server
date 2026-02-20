local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ConnectionManager = require(Main.Utils.ConnectionManager)
local ConsoleOutput = require(Main.Utils.ConsoleOutput)
local DataModelType = require(Main.Utils.DataModelType)
local GameStopUtil = require(Main.Utils.GameStopUtil)
local PluginUtils = require(Main.Utils.PluginUtils)
local Types = require(Main.Types)

local EventBridge = require(Main.Utils.EventBridge)
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local StudioService = game:GetService("StudioService")

PluginUtils.plugin = plugin

local datamodelType = DataModelType.getDataModelType()

if datamodelType == "Server" then
	task.spawn(GameStopUtil.monitorForStopPlay)
	require(Main.ServerDMEntry)
end

if RunService:IsRunning() then
	return
end

local connMessageOut = ConsoleOutput.startListener()
plugin.Unloading:Connect(function()
	connMessageOut:Disconnect()
end)

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

local function getButtonImage()
	local ok, response = pcall(function()
		return StudioService:GetClassIcon("PackageLink").Image
	end)
	return ok and response or "rbxasset://textures/ui/GuiImagePlaceholder.png"
end

local active = false

local function toolCallHandler(args: Types.ToolArgs): string
	local recording = ChangeHistoryService:TryBeginRecording("StudioMCP")

	for _, tool in tools do
		local success, response = pcall(tool, args)

		if success and response then
			return response
		elseif not success then
			return "Error handling request: " .. tostring(response)
		end
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	return "No tool found to handle request"
end

local function start()
	active = true
	ConnectionManager.setToolCallHandler(toolCallHandler)
	ConnectionManager.initEventBridge("Edit")
	ConnectionManager.startWebSocket()
	print("The MCP Studio plugin is ready for prompts.")
end

local function stop()
	active = false
	ConnectionManager.stopWebSocket()
end

start()

-- local function testEventBridge()
-- 	if not currentClient then
-- 		return
-- 	end

-- 	robloxBridgeBindable.Event:Connect(function(body)
-- 		print("Received event:", body)
-- 	end)

-- 	while true do
-- 		print("Sending Roblox Bridge event...")
-- 		currentClient:Send({
-- 			type = "roblox_event_bridge",
-- 			event = "test event 1234567890",
-- 			client_id = currentClientId,
-- 		})
-- 		task.wait(5)
-- 	end
-- end

-- testEventBridge()

local function testEventBridge()
	-- EventBridge.registerEventHandler(function(source, target, event, data)
	-- 	print("Received event:", source, target, event, data)
	-- 	return "Returning Value:" .. source .. " " .. target .. " " .. event .. " " .. data
	-- end)

	EventBridge.registerFunction("test function", function(data)
		print("Received data:", data)
		return "Returning_Value"
	end)

	print("Calling function...")
	local result = EventBridge.callFunction("Edit", "test function", "test data")
	print("Result:", result)
end

testEventBridge()

local toolbar = plugin:CreateToolbar("MCP")
local toggleButton = toolbar:CreateButton("Toggle MCP", "Toggle connection to the server", getButtonImage())
toggleButton.ClickableWhenViewportHidden = true
toggleButton:SetActive(active)

toggleButton.Click:Connect(function()
	if active then
		stop()
	else
		start()
	end
end)
