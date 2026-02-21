local Main = script:FindFirstAncestor("MCPStudioPlugin")
local DataModelType = require(Main.Utils.DataModelType)
local EventBridge = require(Main.Utils.EventBridge)

local PING = "ping"
local PONG = "pong"

local function ping(datamodel: DataModelType.DataModelType, timeout: number)
	local bindableEvent = Instance.new("BindableEvent")
	local done = false
	local success = false
	local result = nil

	task.spawn(function()
		task.wait(timeout)
		if not done then
			result = "Timeout to reach " .. datamodel .. " Data Model"
			success = false
			done = true
			bindableEvent:Fire()
		end
	end)

	task.spawn(function()
		local remoteSuccess, remoteResult = pcall(function()
			local callResult = EventBridge.callFunction(datamodel, PING)
			if callResult ~= PONG then
				error("Failed to reach " .. datamodel .. "Data Model, Error: " .. tostring(callResult))
			end
			return callResult
		end)
		if not done then
			result = remoteResult
			success = remoteSuccess
			done = true
			bindableEvent:Fire()
		end
	end)

	bindableEvent.Event:Wait()
	bindableEvent:Destroy()
	if not success then
		error(result or "Unknown error")
	end
	return result
end

local function registerResponseHandler()
	return EventBridge.registerFunction(PING, function()
		return PONG
	end)
end

local function callFunctionWithPing(
	datamodel: DataModelType.DataModelType,
	timeout: number,
	functionName: string,
	...: any
)
	ping(datamodel, timeout)
	return EventBridge.callFunction(datamodel, functionName, ...)
end

return {
	ping = ping,
	registerResponseHandler = registerResponseHandler,
	callFunctionWithPing = callFunctionWithPing,
}
