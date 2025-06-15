-- SetProperties.luau
local HttpService = game:GetService("HttpService")

local function reconstructValue(value)
	if type(value) == "table" then
		if value.r ~= nil and value.g ~= nil and value.b ~= nil and value.a == nil then -- Color3
			return Color3.new(value.r, value.g, value.b)
		elseif value.x ~= nil and value.y ~= nil and value.z ~= nil then -- Vector3
			return Vector3.new(value.x, value.y, value.z)
		elseif value.x ~= nil and value.y ~= nil and value.z == nil then -- Vector2
			return Vector2.new(value.x, value.y)
		-- Add more reconstructions as needed (e.g., CFrame from components)
		end
	end
	return value -- Return original value if no reconstruction rule matched
end

return function(args)
	if not args["SetProperties"] then
		return nil
	end

	local data = args["SetProperties"]
	local path = data.path
	local propertiesToSet = data.properties

	if not path or not propertiesToSet then
		return HttpService:JSONEncode({
			error = "Missing 'path' or 'properties' in arguments for SetProperties"
		})
	end

	local instance = workspace:FindFirstChild(path, true) -- Recursive search

	if not instance then
		return HttpService:JSONEncode({
			error = "Instance not found at path: " .. path
		})
	end

	local results = {}
	for propName, newValue in pairs(propertiesToSet) do
		local reconstructedNewValue = reconstructValue(newValue)
		local success, err = pcall(function()
			instance[propName] = reconstructedNewValue
		end)

		if success then
			results[propName] = "Property set successfully."
		else
			results[propName] = { error = "Failed to set property '" .. propName .. "': " .. tostring(err) }
		end
	end

	return HttpService:JSONEncode(results)
end
