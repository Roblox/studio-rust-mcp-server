-- GetInstanceProperties.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)

local function execute(args: Types.GetInstancePropertiesArgs)
    print(("[GetInstanceProperties] Executing. Path: %s, PropertyNames: %s, FetchAll: %s"):format(
        tostring(args.path),
        args.property_names and table.concat(args.property_names, ", ") or "nil (fetch all)",
        tostring(args.property_names == nil or (type(args.property_names) == "table" and #args.property_names == 0))
    ))
	local success, resultOrError = pcall(function()
		local path = args.path
		local propertyNamesInput = args.property_names -- Renamed to avoid conflict with loop variable

		if not path or type(path) ~= "string" then
			return { error_type = "InvalidArguments", message = "'path' is required and must be a string." }
		end

		local instance, err = ToolHelpers.FindInstanceByPath(path)
		if not instance then
			return { error_type = "InstanceNotFound", message = ("Failed to find instance at path: %s. %s"):format(path, err or "Unknown error") }
		end

		local propertyResults = {}
		local overallSuccess = true -- Track if all properties were fetched successfully

		local propertiesToFetch
		if propertyNamesInput == nil or (type(propertyNamesInput) == "table" and #propertyNamesInput == 0) then
			propertiesToFetch = { "Name", "ClassName", "Parent" }
			print("[GetInstanceProperties] No specific properties requested, using default minimal set: Name, ClassName, Parent")
		elseif type(propertyNamesInput) == "table" then
			propertiesToFetch = propertyNamesInput
			print("[GetInstanceProperties] Fetching specific properties: ", table.concat(propertiesToFetch, ", "))
		else
			return { error_type = "InvalidArguments", message = "'property_names' must be an array of strings if provided." }
		end

		for _, propNameString in ipairs(propertiesToFetch) do
			local propData = {
				name = propNameString,
				value = nil,
				type = nil,
				error = nil,
			}

			if type(propNameString) == "string" then
				print("[GetInstanceProperties] Attempting to get property: " .. propNameString)
				local getSuccess, result = pcall(function()
					return instance[propNameString]
				end)

				if getSuccess then
					propData.value = result
					propData.type = typeof(result)
					print(("[GetInstanceProperties] Successfully got property: %s Type: %s"):format(propNameString, propData.type))

					-- Serialize complex types
					if propData.type == "Instance" and propData.value then
						propData.value = propData.value:GetFullName()
					elseif propData.type == "Vector3" then
						propData.value = ("%s, %s, %s"):format(propData.value.X, propData.value.Y, propData.value.Z)
					elseif propData.type == "Color3" then
						propData.value = ("%s, %s, %s"):format(propData.value.R, propData.value.G, propData.value.B)
					elseif propData.type == "CFrame" then
						local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22 = propData.value:GetComponents()
						propData.value = ("Pos: (%s,%s,%s), RotMatrix: ((%s,%s,%s),(%s,%s,%s),(%s,%s,%s))"):format(x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22)
					elseif type(propData.value) == "function" or type(propData.value) == "thread" or type(propData.value) == "userdata" then
						propData.value = tostring(propData.value) -- Fallback for unhandled complex types
					end
				else
					local errorMessage = "Error getting property: " .. tostring(result)
					print("[GetInstanceProperties] Failed to get property: " .. propNameString .. " Error: " .. errorMessage)
					propData.error = errorMessage
					overallSuccess = false
				end
			else
				local errorMessage = ("All 'property_names' must be strings. Found entry with type: %s"):format(type(propNameString))
				print("[GetInstanceProperties] Invalid property name type in list: " .. type(propNameString) .. " Value: " .. tostring(propNameString))
				propData.error = errorMessage
				overallSuccess = false
			end
			table.insert(propertyResults, propData)
		end

		local HttpService = game:GetService("HttpService")
		local jsonEncodedProperties = HttpService:JSONEncode(propertyResults)

        print(("[GetInstanceProperties] Preparing to return data. Properties count: %d, Errors present: %s"):format(
            #propertyResults,
            tostring(not overallSuccess)
        ))

		-- The message field in FormatSuccessResult/FormatErrorResult is what becomes content[0].text
		-- So we return the JSON string as the primary piece of data.
		-- For FormatErrorResult, the second argument is a table that gets included in the error object.
		if not overallSuccess then
			-- If there were property access errors, we still return the JSON
			-- but ensure the main call is marked as an error if desired by the task.
			-- The task states: "The isError field in the main JSON response should ideally be true if any property fetch failed"
			-- ToolHelpers.FormatErrorResult might be more suitable if we want the top-level "isError" to be true.
			-- However, the request implies the main operation (finding instance) succeeded, but some props failed.
			-- Let's return it as a "success" in terms of the RPC call itself, but the content indicates partial failure.
			-- The prompt also says: "isError": false // Or true, depending on how overall success is determined
			-- Let's make it true if any property error occurs.
			return {isPartialError = true, data = jsonEncodedProperties}

		end
		return jsonEncodedProperties -- This will be wrapped by FormatSuccessResult
	end)

	if success then
		if resultOrError and resultOrError.error_type then -- InstanceNotFound or InvalidArguments
			-- These are critical errors before property fetching even starts.
			-- The message from resultOrError should be directly in the text field.
			return ToolHelpers.FormatErrorResult(resultOrError.message, {error_type = resultOrError.error_type})
		elseif resultOrError and resultOrError.isPartialError then
			-- Instance was found, properties were processed, but some had errors.
			-- The JSON string (in resultOrError.data) contains all details.
			-- This JSON string should be the 'text' field, and top-level 'isError' should be true.
			return ToolHelpers.FormatErrorResult(resultOrError.data, {partial_failure = true})
		else
			-- Full success: instance found, all requested properties fetched without error.
			-- resultOrError is the jsonEncodedProperties string.
			-- Manually construct the success response to ensure the JSON string is used.
			return { content = { { type = "text", text = resultOrError } }, isError = false }
		end
	else
		-- This is a critical error in the pcall wrapping the main logic (e.g. syntax error in this script)
		local err_msg = "Internal script error in GetInstanceProperties: " .. tostring(resultOrError)
		return ToolHelpers.FormatErrorResult(err_msg, { internal_error_details = tostring(resultOrError), is_luau_error = true })
    end
end

return execute
