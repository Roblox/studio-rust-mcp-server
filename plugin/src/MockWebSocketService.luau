local HttpService = game:GetService("HttpService")

local MockWebSocketClient = {}
MockWebSocketClient.__index = MockWebSocketClient

local EnumWebSocketState = {
	Connecting = "Connecting",
	Open = "Open",
	Closing = "Closing",
	Closed = "Closed",
}

local CloseableStates = {
	[EnumWebSocketState.Connecting] = true,
	[EnumWebSocketState.Open] = true,
}

local POLL_WAIT_TIME = 1

export type MockWebSocketClient = {
	Send: (self: MockWebSocketClient, data: any) -> (),
	Close: (self: MockWebSocketClient) -> (),
	SetReceiveEndpoint: (self: MockWebSocketClient, endpoint: string) -> (),
	SetSendEndpoint: (self: MockWebSocketClient, endpoint: string) -> (),
	Opened: RBXScriptSignal,
	Closed: RBXScriptSignal,
	MessageReceived: RBXScriptSignal,
	ConnectionState: typeof(EnumWebSocketState.Connecting),
}

type MockWebSocketClientPrivate = MockWebSocketClient & {
	new: (uri: string) -> MockWebSocketClient,
	_OpenImpl: (self: MockWebSocketClient) -> (),
	_uri: string,
	_receiveEndpoint: string,
	_sendEndpoint: string,
	_pollTask: thread?,
	_OpenedEvent: BindableEvent,
	_ClosedEvent: BindableEvent,
	_MessageReceivedEvent: BindableEvent,
}

function MockWebSocketClient.new(uri: string): MockWebSocketClient
	local self: MockWebSocketClientPrivate = setmetatable({}, MockWebSocketClient) :: any

	self._uri = uri
	self._receiveEndpoint = ""
	self._sendEndpoint = ""
	self._pollTask = nil :: thread?

	self._OpenedEvent = Instance.new("BindableEvent")
	self.Opened = self._OpenedEvent.Event

	self._ClosedEvent = Instance.new("BindableEvent")
	self.Closed = self._ClosedEvent.Event

	self._MessageReceivedEvent = Instance.new("BindableEvent")
	self.MessageReceived = self._MessageReceivedEvent.Event

	self.ConnectionState = EnumWebSocketState.Connecting

	task.defer(self._OpenImpl, self)

	return self
end

local function doRequest(url: string, method: "GET" | "POST", body: any)
	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = method,
			Headers = {
				["Content-Type"] = "application/json",
			},
			Body = if body then HttpService:JSONEncode(body) else nil,
			Compress = Enum.HttpCompression.None,
		})
	end)

	return if ok then response else nil
end

function MockWebSocketClient._OpenImpl(self: MockWebSocketClientPrivate)
	assert(self.ConnectionState == EnumWebSocketState.Connecting, "WebSocket is not in the Connecting state")

	self.ConnectionState = EnumWebSocketState.Open
	self._OpenedEvent:Fire()

	self._pollTask = task.spawn(function()
		while self.ConnectionState == EnumWebSocketState.Open do
			local response = doRequest(self._uri .. self._receiveEndpoint, "GET")

			if response then
				if response.StatusCode == 200 and response.Success then
					self._MessageReceivedEvent:Fire(response.Body)
					continue
				elseif response.StatusCode == 423 then
					continue
				end
			end

			task.wait(POLL_WAIT_TIME)
		end
	end)
end

function MockWebSocketClient.Send(self: MockWebSocketClientPrivate, data: any)
	doRequest(self._uri .. self._sendEndpoint, "POST", data)
end

function MockWebSocketClient.Close(self: MockWebSocketClientPrivate)
	if CloseableStates[self.ConnectionState] then
		self.ConnectionState = EnumWebSocketState.Closing

		if self._pollTask and coroutine.status(self._pollTask) == "running" then
			task.cancel(self._pollTask)
			self._pollTask = nil :: any
		end

		self.ConnectionState = EnumWebSocketState.Closed
		self._ClosedEvent:Fire()
	end
end

-- START DEVIATION: These methods are not present in the real WebSocketClient instance
function MockWebSocketClient.SetReceiveEndpoint(self: MockWebSocketClientPrivate, endpoint: string)
	self._receiveEndpoint = endpoint
end

function MockWebSocketClient.SetSendEndpoint(self: MockWebSocketClientPrivate, endpoint: string)
	self._sendEndpoint = endpoint
end
-- END DEVIATION

local MockWebSocketService = {}
MockWebSocketService.__index = MockWebSocketService

type MockWebSocketService = {
	CreateClient: (self: MockWebSocketService, uri: string) -> MockWebSocketClient,
}

function MockWebSocketService.CreateClient(_: MockWebSocketService, uri: string)
	return MockWebSocketClient.new(uri)
end

return MockWebSocketService
