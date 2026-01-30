local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local HttpService = game:GetService("HttpService")

type PreviewAssetArgs = {
	asset_id: number,
	keep: boolean?,
}

local INSERT_MAX_SEARCH_DEPTH = 2048
local INSERT_MAX_DISTANCE_AWAY = 20

local function getInsertPosition(): Vector3
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
	local success, objects = pcall(function()
		return game:GetObjects("rbxassetid://" .. assetId)
	end)

	if not success or not objects or #objects == 0 then
		return nil
	end

	return collapseObjectsIntoContainer(objects)
end

local function getInstanceInfo(instance: Instance): {[string]: any}
	local info = {
		name = instance.Name,
		className = instance.ClassName,
		childCount = #instance:GetChildren(),
	}

	-- Get descendant count
	info.descendantCount = #instance:GetDescendants()

	-- Get bounding box if it's a model or part
	if instance:IsA("Model") then
		local success, cf, size = pcall(function()
			return instance:GetBoundingBox()
		end)
		if success then
			info.boundingSize = {
				x = math.floor(size.X * 10) / 10,
				y = math.floor(size.Y * 10) / 10,
				z = math.floor(size.Z * 10) / 10,
			}
		end
	elseif instance:IsA("BasePart") then
		info.boundingSize = {
			x = math.floor(instance.Size.X * 10) / 10,
			y = math.floor(instance.Size.Y * 10) / 10,
			z = math.floor(instance.Size.Z * 10) / 10,
		}
	end

	-- List child types
	local childTypes = {}
	for _, child in instance:GetChildren() do
		childTypes[child.ClassName] = (childTypes[child.ClassName] or 0) + 1
	end
	info.childTypes = childTypes

	return info
end

-- Track preview instance for potential removal
local currentPreview: Instance? = nil
local currentPreviewId: number? = nil

local function handlePreviewAsset(args: Types.ToolArgs): string?
	if not args["PreviewAsset"] then
		return nil
	end

	local previewArgs: PreviewAssetArgs = args["PreviewAsset"]

	if type(previewArgs.asset_id) ~= "number" then
		return "[ERROR] Missing or invalid asset_id parameter"
	end

	local keep = previewArgs.keep == true

	-- Remove previous preview if exists and wasn't kept
	if currentPreview and currentPreview.Parent then
		currentPreview:Destroy()
		currentPreview = nil
		currentPreviewId = nil
	end

	-- Load the asset
	local instance = loadAsset(previewArgs.asset_id)
	if not instance then
		return "[ERROR] Failed to load asset with ID: " .. previewArgs.asset_id
	end

	-- Position it in front of camera
	instance.Name = "Preview_" .. previewArgs.asset_id
	instance.Parent = workspace

	if instance:IsA("Model") then
		instance:PivotTo(CFrame.new(getInsertPosition()))
	elseif instance:IsA("BasePart") then
		instance.Position = getInsertPosition()
	end

	-- Get info about the asset
	local info = getInstanceInfo(instance)
	info.assetId = previewArgs.asset_id

	-- Track for potential removal
	if not keep then
		currentPreview = instance
		currentPreviewId = previewArgs.asset_id
	end

	-- Format response
	local lines = {
		string.format("[SUCCESS] %s asset %d: %s", keep and "Inserted" or "Previewing", previewArgs.asset_id, info.name),
		"",
		string.format("**Type:** %s", info.className),
		string.format("**Children:** %d direct, %d total descendants", info.childCount, info.descendantCount),
	}

	if info.boundingSize then
		table.insert(lines, string.format(
			"**Size:** %.1f x %.1f x %.1f studs",
			info.boundingSize.x, info.boundingSize.y, info.boundingSize.z
		))
	end

	if info.childTypes and next(info.childTypes) then
		local typeStrings = {}
		for typeName, count in info.childTypes do
			table.insert(typeStrings, string.format("%s (%d)", typeName, count))
		end
		table.insert(lines, "**Contains:** " .. table.concat(typeStrings, ", "))
	end

	table.insert(lines, "")

	if keep then
		table.insert(lines, "Asset has been kept in workspace.")
	else
		table.insert(lines, "**This is a preview.** Use `capture_screenshot` to see it visually.")
		table.insert(lines, "Call `preview_asset` again with `keep: true` to keep it, or it will be removed on next preview.")
	end

	-- Add JSON for programmatic use
	table.insert(lines, "")
	table.insert(lines, "```json")
	table.insert(lines, HttpService:JSONEncode(info))
	table.insert(lines, "```")

	return table.concat(lines, "\n")
end

return handlePreviewAsset :: Types.ToolFunction
