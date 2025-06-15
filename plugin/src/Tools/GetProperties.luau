-- GetProperties.luau
local HttpService = game:GetService("HttpService")

return function(args)
	if not args["GetProperties"] then
		return nil
	end

	local data = args["GetProperties"]
	local path = data.path
	local propertiesToGet = data.properties

	if not path or not propertiesToGet then
		return HttpService:JSONEncode({
			error = "Missing 'path' or 'properties' in arguments for GetProperties"
		})
	end

	-- Attempt to find the instance.
	-- We'll assume the path is relative to Workspace for now.
	-- More robust path resolution might be needed for a real plugin (e.g., handling services like Lighting, ReplicatedStorage, etc.)
	local instance = workspace:FindFirstChild(path, true) -- Recursive search

	if not instance then
		return HttpService:JSONEncode({
			error = "Instance not found at path: " .. path
		})
	end

	local results = {}
	for _, propName in ipairs(propertiesToGet) do
		local success, valueOrError = pcall(function()
			return instance[propName]
		end)

		if success then
			-- To handle complex types like Vector3, Color3, etc., we might need to convert them
			-- to a serializable format (e.g., a table with x, y, z components).
			-- For now, we'll attempt to store them directly, but JSONEncode might error
			-- or convert them to strings in a non-ideal way for some types.
			-- A more robust solution would check the type of 'valueOrError' and format accordingly.
			if typeof(valueOrError) == "Instance" then
				results[propName] = valueOrError:GetFullName() -- Or some other identifier
			elseif typeof(valueOrError) == "Color3" then
				results[propName] = {r = valueOrError.R, g = valueOrError.G, b = valueOrError.B}
			elseif typeof(valueOrError) == "Vector3" then
				results[propName] = {x = valueOrError.X, y = valueOrError.Y, z = valueOrError.Z}
			elseif typeof(valueOrError) == "Vector2" then
				results[propName] = {x = valueOrError.X, y = valueOrError.Y}
			-- Add more type handlers as needed (e.g., CFrame, EnumItem, etc.)
			else
				results[propName] = valueOrError
			end
		else
			results[propName] = { error = "Property '" .. propName .. "' not found or not readable: " .. tostring(valueOrError) }
		end
	end

	return HttpService:JSONEncode(results)
end
