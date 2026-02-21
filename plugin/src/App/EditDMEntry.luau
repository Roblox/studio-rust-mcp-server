local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ConnectionManager = require(Main.Utils.ConnectionManager)
local ConsoleOutput = require(Main.Utils.ConsoleOutput)
local DataModelStatusMonitor = require(Main.Utils.DataModelStatusMonitor)
local PluginUtils = require(Main.Utils.PluginUtils)
local ToolDispatcher = require(Main.Utils.ToolDispatcher)
local Types = require(Main.Types)

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local StudioService = game:GetService("StudioService")

return function(plugin: Plugin)
	PluginUtils.plugin = plugin

	local connMessageOut = ConsoleOutput.startListener()
	plugin.Unloading:Connect(function()
		connMessageOut:Disconnect()
	end)

	local function getButtonImage()
		local ok, response = pcall(function()
			return StudioService:GetClassIcon("PackageLink").Image
		end)
		return ok and response or "rbxasset://textures/ui/GuiImagePlaceholder.png"
	end

	local active = false

	local function toolCallHandler(args: Types.ToolArgs): string
		local toolName = next(args)
		if not toolName then
			return "No tool name found in request"
		end

		local toolArgs = args[toolName]
		if not toolArgs or type(toolArgs) ~= "table" then
			return "Invalid tool args found for tool name: " .. toolName
		end

		local recording = ChangeHistoryService:TryBeginRecording("StudioMCP")
		local success, response = pcall(ToolDispatcher.dispatchTool, toolName, toolArgs)
		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end

		if success then
			return response or ""
		end
		return "Error handling request: " .. tostring(response)
	end

	local function start()
		active = true
		ConnectionManager.setToolCallHandler(toolCallHandler)
		ConnectionManager.initEventBridge("Edit")
		ConnectionManager.startWebSocket()
		DataModelStatusMonitor.start()
		print("The MCP Studio plugin is ready for prompts.")
	end

	local function stop()
		active = false
		ConnectionManager.stopWebSocket()
	end

	start()

	-- local function testEventBridge()
	-- 	-- EventBridge.registerEventHandler(function(source, target, event, data)
	-- 	-- 	print("Received event:", source, target, event, data)
	-- 	-- 	return "Returning Value:" .. source .. " " .. target .. " " .. event .. " " .. data
	-- 	-- end)

	-- 	EventBridge.registerFunction("test function", function(data)
	-- 		print("Received data:", data)
	-- 		return "Returning_Value"
	-- 	end)

	-- 	print("Calling function...")
	-- 	local result = EventBridge.callFunction("Edit", "test function", "test data")
	-- 	print("Result:", result)
	-- end

	-- testEventBridge()

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
end
