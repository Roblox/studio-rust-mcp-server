local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local InsertService = game:GetService("InsertService")
local HttpService = game:GetService("HttpService")

type SearchAssetsArgs = {
	query: string,
	max_results: number?,
}

type AssetResult = {
	assetId: number,
	name: string,
	creator: string,
}

local function handleSearchAssets(args: Types.ToolArgs): string?
	if not args["SearchAssets"] then
		return nil
	end

	local searchArgs: SearchAssetsArgs = args["SearchAssets"]

	if type(searchArgs.query) ~= "string" or searchArgs.query == "" then
		return HttpService:JSONEncode({
			success = false,
			error = "Missing or empty query parameter",
			assets = {},
			query = "",
		})
	end

	local maxResults = math.min(searchArgs.max_results or 10, 20)

	-- Search for assets using InsertService
	local success, searchResults = pcall(function()
		return InsertService:GetFreeModels(searchArgs.query, 0)
	end)

	if not success then
		return HttpService:JSONEncode({
			success = false,
			error = "Failed to search assets: " .. tostring(searchResults),
			assets = {},
			query = searchArgs.query,
		})
	end

	-- Parse results - just return asset IDs for Rust to enrich
	local assets: {AssetResult} = {}

	if searchResults and searchResults[1] and searchResults[1].Results then
		for i, result in searchResults[1].Results do
			if i > maxResults then
				break
			end
			table.insert(assets, {
				assetId = result.AssetId,
				name = result.Name,
				creator = result.CreatorName or "Unknown",
			})
		end
	end

	-- Return structured JSON for Rust to parse and enrich
	return HttpService:JSONEncode({
		success = true,
		error = nil,
		assets = assets,
		query = searchArgs.query,
	})
end

return handleSearchAssets :: Types.ToolFunction
