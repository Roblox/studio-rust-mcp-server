local DataModelType = require(script.Parent.DataModelType)

type DataModelType = DataModelType.DataModelType

type EventHubData = {
	source: DataModelType,
	target: DataModelType?,
	event: string,
	data: any,
}

type EventHubFunctionRequest = {
	invokeId: number,
	functionName: string,
	args: { any },
}

type EventHubFunctionResponse = {
	invokeId: number,
	functionName: string,
	success: boolean,
	result: any,
}

export type PubSub = {
	OnInvoke: (self: PubSub, event: string, callback: (...any) -> ()) -> (),
	Invoke: (self: PubSub, event: string, ...any) -> (),
}

type EventBridge = {
	pubsub: PubSub?,
	datamodel: DataModelType,
	isHub: boolean,
	replicatedEventBridge: RemoteEvent,
	globalEvent: BindableEvent,
	targetedEvent: BindableEvent,
	_initBindableEvent: (createIfNotExists: boolean) -> (),
	isTargetedReceiver: (target: DataModelType?) -> boolean,
	init: (pubsub: PubSub?, datamodel: DataModelType, hasReplicatedEventBridge: boolean, isHub: boolean) -> (),
	callSubscribers: (source: DataModelType, target: DataModelType, event: string, ...any) -> (),
	fire: (target: DataModelType?, event: string, ...any) -> (),
	registerEventHandler: (
		callback: (source: DataModelType, target: DataModelType?, event: string, ...any) -> ()
	) -> RBXScriptConnection,
	registerFunction: (functionName: string, callback: (...any) -> ()) -> RBXScriptConnection,
	_routeFromPluginToUser: (source: DataModelType, target: DataModelType, event: string, ...any) -> (),
	_routeFromUserToPlugin: (source: DataModelType, target: DataModelType, event: string, ...any) -> (),

	_routeFromReplicatedEventToPubSub: (source: DataModelType, target: DataModelType, event: string, ...any) -> (),
	_routeFromPubSubToReplicatedEvent: (source: DataModelType, target: DataModelType, event: string, ...any) -> (),
	_onPubSubEvent: (source: DataModelType, target: DataModelType, event: string, ...any) -> (),
	_fireReplicatedEvent: (
		isFromHubToClient: boolean,
		source: DataModelType,
		target: DataModelType?,
		event: string,
		...any
	) -> (),
	-- _fireFromReplicatedEvent: (target: DataModelType?, event: string, ...any) -> (),
	-- _fireFromPubSub: (target: DataModelType?, event: string, ...any) -> (),

	_fireFromUser: (target: DataModelType?, event: string, ...any) -> (),
	callFunction: (target: DataModelType?, functionName: string, ...any) -> any,
	close: () -> (),
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventHubKey = `AssistantEventBridge`
local EventHubRemoteEventName = `AssistantEventHubBridge`
local EventBridge: EventBridge = {} :: EventBridge
local functionCallRegistry = {} :: { [number]: { bindableEvent: BindableEvent, request: EventHubFunctionRequest } }
local pendingFunctionHandlers = {} :: { [string]: { source: DataModelType, target: DataModelType?, data: any } }
local functionInvokeId = 0

local function getNextFunctionInvokeId()
	functionInvokeId += 1
	return functionInvokeId
end

function EventBridge._initBindableEvent(createIfNotExists: boolean)
	if createIfNotExists then
		if not ReplicatedStorage:FindFirstChild(EventHubRemoteEventName) then
			local instance = Instance.new("RemoteEvent")
			instance.Name = EventHubRemoteEventName
			instance.Parent = ReplicatedStorage
		end
		EventBridge.replicatedEventBridge = ReplicatedStorage[EventHubRemoteEventName]
	else
		EventBridge.replicatedEventBridge = ReplicatedStorage:WaitForChild(EventHubRemoteEventName)
	end
end

function EventBridge.isTargetedReceiver(target: DataModelType?)
	if target == nil then
		return true
	end
	return target == EventBridge.datamodel
end

function EventBridge.init(pubsub: PubSub?, datamodel: DataModelType, hasReplicatedEventBridge: boolean, isHub: boolean)
	if EventBridge.datamodel ~= nil then
		warn("EventBridge already initialized, skipping initialization")
		return
	end

	if isHub then
		assert(hasReplicatedEventBridge and pubsub, "Hub must have replicated event bridge and pubsub")
	end

	EventBridge.isHub = isHub
	EventBridge.pubsub = pubsub
	EventBridge.datamodel = datamodel
	EventBridge.globalEvent = Instance.new("BindableEvent")
	EventBridge.targetedEvent = Instance.new("BindableEvent")

	if pubsub then
		pubsub:OnInvoke(EventHubKey, function(source: DataModelType, target: DataModelType, event: string, ...: any)
			EventBridge._onPubSubEvent(source, target, event, ...)
		end)
	end

	if hasReplicatedEventBridge then
		EventBridge._initBindableEvent(isHub)
	end

	if EventBridge.replicatedEventBridge then
		local replicatedEventBridgeHandler = function(
			isFromHubToClient: boolean,
			source: DataModelType,
			target: DataModelType,
			event: string,
			...: any
		)
			if EventBridge.isHub then
				if not isFromHubToClient then
					EventBridge._routeFromReplicatedEventToPubSub(source, target, event, ...)
				end
			else
				if isFromHubToClient then
					EventBridge._routeFromPubSubToReplicatedEvent(source, target, event, ...)
				end
			end
		end

		if isHub then
			EventBridge.replicatedEventBridge.OnServerEvent:Connect(
				function(_player: Player, isFromHubToClient, source, target, event, ...)
					replicatedEventBridgeHandler(isFromHubToClient, source, target, event, ...)
				end
			)
		else
			EventBridge.replicatedEventBridge.OnClientEvent:Connect(replicatedEventBridgeHandler)
		end
	end
end

EventBridge._routeFromReplicatedEventToPubSub = function(
	source: DataModelType,
	target: DataModelType,
	event: string,
	...: any
)
	if EventBridge.pubsub then
		EventBridge.pubsub:Invoke(EventHubKey, source, target, event, ...)
	end
end

EventBridge._routeFromPubSubToReplicatedEvent = function(
	source: DataModelType,
	target: DataModelType,
	event: string,
	...: any
)
	EventBridge.callSubscribers(source, target, event, ...)
end

function EventBridge._fireReplicatedEvent(
	isFromHubToClient: boolean,
	source: DataModelType,
	target: DataModelType?,
	event: string,
	...: any
)
	if EventBridge.isHub then
		EventBridge.replicatedEventBridge:FireAllClients(isFromHubToClient, source, target, event, ...)
	else
		EventBridge.replicatedEventBridge:FireServer(isFromHubToClient, source, target, event, ...)
	end
end

function EventBridge._onPubSubEvent(source: DataModelType, target: DataModelType, event: string, ...: any)
	EventBridge.callSubscribers(source, target, event, ...)
	if EventBridge.isHub then
		EventBridge._fireReplicatedEvent(true, source, target, event, ...)
	end
end

function EventBridge.fire(target: DataModelType?, event: string, ...: any)
	if EventBridge.pubsub then
		EventBridge.pubsub:Invoke(EventHubKey, EventBridge.datamodel, target, event, ...)
	end
	if EventBridge.replicatedEventBridge then
		EventBridge._fireReplicatedEvent(EventBridge.isHub, EventBridge.datamodel, target, event, ...)
	end
end

function EventBridge.callSubscribers(source: DataModelType, target: DataModelType, event: string, ...: any)
	EventBridge.globalEvent:Fire(source, target, event, ...)
	if EventBridge.isTargetedReceiver(target) then
		EventBridge.targetedEvent:Fire(source, target, event, ...)
	end
end

EventBridge.registerEventHandler = function(callback: (
	source: DataModelType,
	target: DataModelType?,
	event: string,
	...any
) -> ())
	local connection = EventBridge.targetedEvent.Event:Connect(
		function(source: DataModelType, target: DataModelType?, event: string, ...: any)
			callback(source, target, event, ...)
		end
	)
	return connection
end

function EventBridge.registerFunction(functionName: string, callback: (...any) -> ()): RBXScriptConnection
	return EventBridge.registerEventHandler(
		function(source: DataModelType, target: DataModelType?, event: string, data: any)
			if event == "FunctionRequest" then
				local name = data.functionName
				local args = data.args
				local invokeId = data.invokeId
				if name == functionName then
					local invokeKey = `FunctionRequest_{functionName}_{invokeId}`
					pendingFunctionHandlers[invokeKey] = {
						source = source,
						target = target,
						data = data,
					}
					task.spawn(function()
						local success, result: any = pcall(function()
							return callback(table.unpack(args))
						end)
						local response = {
							invokeId = invokeId,
							functionName = functionName,
							success = success,
							result = result,
						}
						if pendingFunctionHandlers[invokeKey] then
							pendingFunctionHandlers[invokeKey] = nil
							EventBridge.fire(source, `FunctionResponse`, response)
						end
					end)
				end
			end
		end
	)
end

function EventBridge.callFunction(target: DataModelType?, functionName: string, ...: any)
	local invokeId = getNextFunctionInvokeId()
	local request = {
		invokeId = invokeId,
		functionName = functionName,
		args = { ... },
	}

	local bindableEvent = Instance.new("BindableEvent")
	bindableEvent.Name = `Response_{functionName}_{invokeId}`
	functionCallRegistry[invokeId] = {
		bindableEvent = bindableEvent,
		request = request,
	}

	local connection = EventBridge.registerEventHandler(
		function(responseSource: DataModelType, responseTarget: DataModelType?, event: string, data: any)
			if
				responseSource == target
				and responseTarget == EventBridge.datamodel
				and event == `FunctionResponse`
				and data.functionName == functionName
				and data.invokeId == invokeId
			then
				functionCallRegistry[invokeId].bindableEvent:Fire(data)
				functionCallRegistry[invokeId] = nil
			end
		end
	)

	EventBridge.fire(target, `FunctionRequest`, request)
	local result = bindableEvent.Event:Wait()
	bindableEvent:Destroy()
	connection:Disconnect()
	if not result.success then
		error(result.result or "Unknown error")
	end
	return result.result
end

local function closeRemoteFunctionCalls()
	for _, handler in pendingFunctionHandlers do
		local response = {
			invokeId = handler.data.invokeId,
			functionName = handler.data.functionName,
			success = false,
			result = "Remote Connection closed while waiting for function call response",
		}
		EventBridge.fire(handler.source, `FunctionResponse`, response)
	end
	pendingFunctionHandlers = {}
end

local function closeLocalFunctionCalls()
	for _, call in functionCallRegistry do
		local response = {
			invokeId = call.request.invokeId,
			functionName = call.request.functionName,
			success = false,
			result = "Local Connection closed while waiting for function call response",
		}
		call.bindableEvent:Fire(response)
	end
	functionCallRegistry = {}
end

function EventBridge.close()
	closeRemoteFunctionCalls()
	closeLocalFunctionCalls()
	EventBridge.globalEvent:Destroy()
	EventBridge.targetedEvent:Destroy()
	EventBridge.datamodel = nil :: any
end

return EventBridge
