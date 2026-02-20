local Main = script:FindFirstAncestor("MCPStudioPlugin")
local EventBridge = require(Main.Utils.EventBridge)
local MockWebSocketService = require(Main.MockWebSocketService)
local Types = require(Main.Types)

local HttpService = game:GetService("HttpService")

local URI = "http://localhost:44755"
local RETRY_DELAY = 5

local old_warn = warn
local function log(...)
	if false then
		old_warn(...)
	end
end

local enableRetry = false
local toolCallHandler = nil

local function setToolCallHandler(handler: (args: Types.ToolArgs) -> string | nil)
	toolCallHandler = handler
end

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
local robloxBridgeBindableEvent: BindableEvent = Instance.new("BindableEvent")

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
			robloxBridgeBindableEvent:Fire(body.event)
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

		if toolCallHandler == nil then
			sendResponseOnce("Error, Tool call is not enabled for this client")
			return
		end

		local success, response = pcall(toolCallHandler, args)
		if success and response then
			sendResponseOnce(response)
		elseif not success then
			sendResponseOnce("Error handling request: " .. tostring(response))
		end
		log("[MCP] Successfully handled request")
	end)

	return client
end

local currentClient: MockWebSocketService.MockWebSocketClient? = nil

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
						task.wait(RETRY_DELAY)
						startWebSocket()
					end)
				end
			end)
			break
		end
		task.wait(RETRY_DELAY)
	end
end

local function stopWebSocket()
	EventBridge.close()
	enableRetry = false
	currentClientId = nil
	if currentClient then
		currentClient:Close()
		currentClient = nil
	end
end

local function sendEventBridgeEvent(event: string)
	if currentClient then
		currentClient:Send({
			type = "roblox_event_bridge",
			event = event,
			client_id = currentClientId,
		})
	end
end

local PubSub = {}
PubSub.__index = PubSub

type PubSubData = {
	bindableEvent: BindableEvent,
	new: (bindableEvent: BindableEvent) -> PubSub,
} & EventBridge.PubSub

type PubSub = typeof(setmetatable({} :: PubSubData, PubSub))

function PubSub.new(bindableEvent: BindableEvent): PubSub
	local self = {} :: PubSubData
	setmetatable(self, PubSub)
	self.bindableEvent = bindableEvent
	return self
end

function PubSub.OnInvoke(self: PubSub, event: string, callback: (...any) -> ()): ()
	self.bindableEvent.Event:Connect(function(dataStr)
		local data = HttpService:JSONDecode(dataStr)
		if data.event == event then
			callback(unpack(data.args))
		end
	end)
end

function PubSub.Invoke(_self: PubSub, event: string, ...)
	local args = { ... }
	local data = {
		event = event,
		args = args,
	}
	local json = HttpService:JSONEncode(data)
	sendEventBridgeEvent(json)
end

local function initEventBridge(datamodel: string)
	local pubsub = PubSub.new(robloxBridgeBindableEvent)
	EventBridge.init(pubsub, datamodel)
end

return {
	startWebSocket = startWebSocket,
	stopWebSocket = stopWebSocket,
	setToolCallHandler = setToolCallHandler,
	initEventBridge = initEventBridge,
}
