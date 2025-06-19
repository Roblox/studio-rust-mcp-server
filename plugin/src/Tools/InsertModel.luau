-- InsertModel.luau
-- This module handles inserting assets from the Creator Marketplace into the workspace.
-- It can insert an asset by its ID or by a search query.

local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)
local ToolHelpers = require(Main.ToolHelpers)

local InsertService = ToolHelpers.GetInsertService()
-- local CollectionService = game:GetService("CollectionService") -- For tagging if needed later

local INSERT_MAX_SEARCH_DEPTH = 2048
local INSERT_MAX_DISTANCE_AWAY = 20

-- Determines the 3D position in the world where the model should be inserted.
-- It raycasts from the center of the camera's viewport.
local function getInsertPosition(): Vector3
	local camera = ToolHelpers.GetWorkspaceService().CurrentCamera
	if not camera then return Vector3.new(0, 5, 0) end

	local viewportPoint = camera.ViewportSize / 2
	local unitRay = camera:ViewportPointToRay(viewportPoint.X, viewportPoint.Y, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- Exclude currently selected objects from the raycast target
	params.FilterDescendantsInstances = ToolHelpers.GetSelectionService():Get()

	local result = ToolHelpers.GetWorkspaceService():Raycast(unitRay.Origin, unitRay.Direction * INSERT_MAX_SEARCH_DEPTH, params)

	if result then
		-- Place the model on the surface that was hit
		return result.Position
	else
		-- Place the model a set distance in front of the camera if nothing was hit
		return camera.CFrame.Position + unitRay.Direction * INSERT_MAX_DISTANCE_AWAY
	end
end

-- Converts a string to TitleCase and removes spaces. e.g., "my awesome model" -> "MyAwesomeModel"
local function toTitleCase(str: string): string
	local function titleCase(first: string, rest: string)
		return first:upper() .. rest:lower()
	end
	local intermediate = string.gsub(str, "(%a)([%w_']*)", titleCase)
	return intermediate:gsub("%s+", "")
end

-- Safely loads an asset from its ID using InsertService.
-- Returns a success boolean, the loaded Model instance, and an error message if it fails.
local function actualLoadAsset(assetId: number): (boolean, Model?, string?)
	local success, assetModel = pcall(InsertService.LoadAsset, InsertService, assetId)
	if not success then
		-- The 'assetModel' variable contains the error message from pcall
		return false, nil, ("InsertService:LoadAsset() failed for asset ID %d. Error: %s"):format(assetId, tostring(assetModel))
	end

	-- Validate that LoadAsset returned a Model instance as expected.
	if not (assetModel and assetModel:IsA("Model")) then
		if assetModel then assetModel:Destroy() end -- Clean up invalid asset
		return false, nil, "InsertService:LoadAsset() did not return a valid Model for asset ID: " .. tostring(assetId)
	end

	return true, assetModel :: Model, nil
end

-- Gets a valid asset ID from a user query, which can be an ID or a search string.
local function getAssetIdFromString(query: string): (boolean, number?, string?)
	local assetId = tonumber(query)
	if assetId then
		return true, assetId, nil
	end

	-- If not a number, search the Creator Marketplace for a free model.
	local success, resultsPages = pcall(InsertService.GetFreeModels, InsertService, query, 0)
	if not success then
		-- 'resultsPages' contains the error message
		return false, nil, ("InsertService:GetFreeModels() failed for query '%s'. Error: %s"):format(query, tostring(resultsPages))
	end

	-- Check if the search returned any valid results.
	if resultsPages and resultsPages[1] and resultsPages[1].Results and #resultsPages[1].Results > 0 then
		return true, resultsPages[1].Results[1].AssetId, nil
	else
		return false, nil, "No assets found for query: '" .. query .. "'"
	end
end

-- Main logic for inserting an asset.
local function performInsert(query: string, parentPath: string?): (Types.InsertModelResultData?, string?)
	local assetIdOk, assetId, errorMsg = getAssetIdFromString(query)
	if not assetIdOk then
		return nil, errorMsg
	end

	local loadOk, loadedModel, loadErrorMsg = actualLoadAsset(assetId :: number)
	if not loadOk then
		return nil, loadErrorMsg
	end

	-- At this point, loadedModel is guaranteed to be a non-nil Model instance.
	loadedModel = loadedModel :: Model

	local parent = ToolHelpers.GetWorkspaceService() -- Default parent is workspace
	if parentPath then
		local foundParent, findError = ToolHelpers.FindInstanceByPath(parentPath)
		if not foundParent then
			loadedModel:Destroy() -- Cleanup the loaded model if the parent is invalid
			return nil, "Failed to find specified parent at path '" .. parentPath .. "'. " .. (findError or "")
		end
		parent = foundParent
	end

	-- Generate a unique name for the new model to avoid conflicts.
	local baseName = toTitleCase(loadedModel.Name or query)
	if string.len(baseName) == 0 then baseName = "Model" end

	local name = baseName
	local i = 1
	while parent:FindFirstChild(name) do
		i += 1
		name = baseName .. i
	end
	loadedModel.Name = name

	-- Position and parent the model in the world.
	loadedModel:PivotTo(CFrame.new(getInsertPosition()))
	loadedModel.Parent = parent

	-- Construct the success result data.
	local resultData: Types.InsertModelResultData = {
		message = ("Successfully inserted asset ID %d as '%s' into '%s'."):format(assetId, loadedModel.Name, loadedModel.Parent:GetFullName()),
		instance_path = loadedModel:GetFullName(),
		asset_id = assetId,
	}
	return resultData, nil
end

-- Public handler function for the tool.
-- It validates arguments and wraps the core logic in a pcall for safety.
local function handleInsertModel(args: Types.InsertModelArgs)
	local pcall_ok, result_or_err = pcall(function()
		-- Argument validation
		if not (type(args.query) == "string" and args.query ~= "") then
			error("InsertModel: 'query' argument (asset ID or search term) is missing, empty, or not a string.")
		end
		if args.parent_path and type(args.parent_path) ~= "string" then
			error("InsertModel: 'parent_path', if provided, must be a string.")
		end

		-- Perform the main insertion logic
		local data, err_string = performInsert(args.query, args.parent_path)

		-- If performInsert returned an error string, throw it to be caught by the pcall
		if err_string then
			error(err_string)
		end

		-- If successful, return the result data
		return data
	end)

	if pcall_ok then
		-- The pcall was successful, and result_or_err is the data table
		return ToolHelpers.FormatSuccessResult(result_or_err)
	else
		-- The pcall failed, and result_or_err is the error message string
		return ToolHelpers.FormatErrorResult(tostring(result_or_err))
	end
end

return handleInsertModel