local Main = script:FindFirstAncestor("MCPStudioPlugin")
local DataModelType = require(Main.Utils.DataModelType)
local datamodelType = DataModelType.getDataModelType()

if datamodelType == "Server" then
	require(Main.App.ServerDMEntry)(plugin)
elseif datamodelType == "Edit" then
	require(Main.App.EditDMEntry)(plugin)
elseif datamodelType == "Client" then
	require(Main.App.ClientDMEntry)(plugin)
else
	error("Invalid datamodel type: " .. datamodelType)
end
