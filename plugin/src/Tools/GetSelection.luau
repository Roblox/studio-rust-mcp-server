-- GetSelection.luau
local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")

return function(args)
	if not args["GetSelection"] then
		return nil
	end

	local selectedObjects = Selection:Get()
	local results = {}

	for _, instance in ipairs(selectedObjects) do
		local objectData = {
			name = instance.Name,
			path = instance:GetFullName(),
			className = instance.ClassName
		}
		table.insert(results, objectData)
	end

	return HttpService:JSONEncode(results)
end
