local RunService = game:GetService("RunService")

export type DataModelType = "Edit" | "Client" | "Server" | "Unknown"

local function getDataModelType(): DataModelType
	if RunService:IsEdit() then
		return "Edit"
	else
		if RunService:IsServer() then
			return "Server"
		end
		if RunService:IsClient() then
			return "Client"
		end
	end
	return "Unknown"
end

return { getDataModelType = getDataModelType }
