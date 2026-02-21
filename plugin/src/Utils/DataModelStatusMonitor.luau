local Main = script:FindFirstAncestor("MCPStudioPlugin")
local EventBridge = require(Main.Utils.EventBridge)

local DATAMODEL_EVENT = "datamodel_event"
local DATAMODEL_CREATED = "datamodel_created"
local DATAMODEL_DESTROYED = "datamodel_destroyed"

local dataModelStatus: { [string]: boolean } = {}

local connection: RBXScriptConnection? = nil
local function start()
	connection = EventBridge.registerEventHandler(function(_source, _target, event, datamodelAction, datamodelType)
		if event == DATAMODEL_EVENT then
			if datamodelAction == DATAMODEL_CREATED then
				print("Data model created: " .. datamodelType)
				dataModelStatus[datamodelType] = true
			elseif datamodelAction == DATAMODEL_DESTROYED then
				print("Data model destroyed: " .. datamodelType)
				dataModelStatus[datamodelType] = false
			end
		end
	end)
end

local function stop()
	if connection then
		connection:Disconnect()
	end
	connection = nil
end

local function notifyDataModelCreated(datamodelType: string)
	EventBridge.fire(nil, DATAMODEL_EVENT, DATAMODEL_CREATED, datamodelType)
end

local function notifyDataModelDestroyed(datamodelType: string)
	EventBridge.fire(nil, DATAMODEL_EVENT, DATAMODEL_DESTROYED, datamodelType)
end

local function getDataModelStatus(datamodelType: string)
	return dataModelStatus[datamodelType]
end

return {
	start = start,
	stop = stop,
	notifyDataModelCreated = notifyDataModelCreated,
	notifyDataModelDestroyed = notifyDataModelDestroyed,
	getDataModelStatus = getDataModelStatus,
}
