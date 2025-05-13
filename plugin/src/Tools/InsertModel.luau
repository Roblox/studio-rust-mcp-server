local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local INSERT_MAX_SEARCH_DEPTH = 2048
local INSERT_MAX_DISTANCE_AWAY = 20

local function getInsertPosition()
	local camera = workspace.CurrentCamera
	local viewportPoint = camera.ViewportSize / 2
	local unitRay = camera:ViewportPointToRay(viewportPoint.X, viewportPoint.Y, 0)

	local ray = Ray.new(unitRay.Origin, unitRay.Direction * INSERT_MAX_SEARCH_DEPTH)
	local params = RaycastParams.new()
	params.BruteForceAllSlow = true

	local result = workspace:Raycast(ray.Origin, ray.Direction, params)

	if result then
		return result.Position
	else
		return camera.CFrame.Position + unitRay.Direction * INSERT_MAX_DISTANCE_AWAY
	end
end

local InsertService = game:GetService("InsertService")

type GetFreeModelsResponse = {
	[number]: {
		CurrentStartIndex: number,
		TotalCount: number,
		Results: {
			[number]: {
				Name: string,
				AssetId: number,
				AssetVersionId: number,
				CreatorName: string,
			},
		},
	},
}

local function toTitleCase(str: string): string
	local function titleCase(first: string, rest: string)
		return first:upper() .. rest:lower()
	end

	local intermediate = string.gsub(str, "(%a)([%w_']*)", titleCase :: (string) -> string)
	return intermediate:gsub("%s+", "")
end

local function collapseObjectsIntoContainer(objects: { Instance }): Instance?
	local isPhysical = false
	for _, object in objects do
		if object:IsA("PVInstance") then
			isPhysical = true
			break
		end
	end

	if isPhysical then
		local model = Instance.new("Model")
		for _, object in objects do
			object.Parent = model
		end
		return model
	end

	if #objects > 1 then
		local folder = Instance.new("Folder")
		for _, object in objects do
			object.Parent = folder
		end
		return folder
	end

	return objects[1]
end

local function loadAsset(assetId: number): Instance?
	local objects = game:GetObjects("rbxassetid://" .. assetId)
	return collapseObjectsIntoContainer(objects)
end

local function getAssets(query: string): number?
	local results: GetFreeModelsResponse = InsertService:GetFreeModels(query, 0)
	local assets = {}
	for i, result in results[1].Results do
		if i > 6 then
			break
		end
		table.insert(assets, result.AssetId)
	end

	return table.remove(assets, 1)
end

local function insertFromMarketplace(query: string): string
	local primaryResult = getAssets(query)
	if not primaryResult then
		error("Failed to find asset")
	end

	local instance = loadAsset(primaryResult)
	if not instance then
		error("Failed to load asset")
	end

	local name = toTitleCase(query)
	local i = 1
	while workspace:FindFirstChild(name) do
		name = query .. i
		i += 1
	end

	instance.Name = name
	instance.Parent = workspace

	if instance:IsA("Model") then
		instance:PivotTo(CFrame.new(getInsertPosition()))
	end

	return name
end

local function handleInsertModel(args: Types.ToolArgs): string?
	if not args["InsertModel"] then
		return nil
	end

	local insertModelArgs: Types.InsertModelArgs = args["InsertModel"]
	if type(insertModelArgs.query) ~= "string" then
		error("Missing query in InsertModel")
	end

	return insertFromMarketplace(insertModelArgs.query)
end

return handleInsertModel :: Types.ToolFunction
