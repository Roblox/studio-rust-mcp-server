--!strict
-- MoveCharacter tool: Move or teleport a character in the workspace
-- Works in simulation mode where the plugin has direct access to the game

local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Find a character model in workspace
-- If characterName is provided, looks for that specific character
-- Otherwise returns the first Model with a Humanoid
local function findCharacter(characterName: string?): Model?
	if characterName then
		local character = workspace:FindFirstChild(characterName, true)
		if character and character:IsA("Model") and character:FindFirstChildOfClass("Humanoid") then
			return character
		end
		return nil
	end

	-- Find first character (Model with Humanoid)
	for _, child in workspace:GetDescendants() do
		if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
			return child
		end
	end
	return nil
end

local function moveCharacter(args: Types.MoveCharacterArgs): string
	-- Note: During playtest, RunService:IsRunning() returns false from plugin context
	-- but we can still manipulate workspace objects. We'll try and let it fail naturally.

	local targetPosition = Vector3.new(args.x, args.y, args.z)
	local instant = args.instant or false
	local character = findCharacter(args.character_name)

	if not character then
		if args.character_name then
			error(`Character '{args.character_name}' not found in workspace`)
		else
			error("No character found in workspace. Ensure there is a Model with a Humanoid.")
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart

	if not humanoid then
		error(`Character '{character.Name}' does not have a Humanoid`)
	end

	if not rootPart then
		error(`Character '{character.Name}' does not have a HumanoidRootPart or PrimaryPart`)
	end

	local startPosition = rootPart.Position

	if instant then
		-- Teleport instantly
		rootPart.CFrame = CFrame.new(targetPosition)
		return HttpService:JSONEncode({
			success = true,
			action = "teleport",
			character = character.Name,
			from = { x = startPosition.X, y = startPosition.Y, z = startPosition.Z },
			to = { x = targetPosition.X, y = targetPosition.Y, z = targetPosition.Z },
		})
	else
		-- Walk to position using MoveTo
		humanoid:MoveTo(targetPosition)
		return HttpService:JSONEncode({
			success = true,
			action = "walk",
			character = character.Name,
			from = { x = startPosition.X, y = startPosition.Y, z = startPosition.Z },
			to = { x = targetPosition.X, y = targetPosition.Y, z = targetPosition.Z },
			note = "Character is walking to target. Use get_studio_state and screenshots to verify arrival.",
		})
	end
end

local function handleMoveCharacter(args: Types.ToolArgs): string?
	local moveArgs = args["MoveCharacter"]
	if not moveArgs then
		return nil
	end

	return moveCharacter(moveArgs)
end

return handleMoveCharacter :: Types.ToolFunction
