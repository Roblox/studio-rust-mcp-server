local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local StarterGui = game:GetService("StarterGui")

type CreateResponsiveLayoutArgs = {
	name: string,
	containers: {string},
}

-- Container configurations: AnchorPoint, Position, default name suffix
local CONTAINER_CONFIGS = {
	TopLeft = {
		anchor = Vector2.new(0, 0),
		position = UDim2.new(0, 8, 0, 8),
		suffix = "TopLeft"
	},
	TopRight = {
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -8, 0, 8),
		suffix = "TopRight"
	},
	TopCenter = {
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 8),
		suffix = "TopCenter"
	},
	BottomLeft = {
		anchor = Vector2.new(0, 1),
		position = UDim2.new(0, 8, 1, -8),
		suffix = "BottomLeft"
	},
	BottomRight = {
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -8, 1, -8),
		suffix = "BottomRight"
	},
	BottomCenter = {
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -8),
		suffix = "BottomCenter"
	},
	CenterLeft = {
		anchor = Vector2.new(0, 0.5),
		position = UDim2.new(0, 8, 0.5, 0),
		suffix = "CenterLeft"
	},
	CenterRight = {
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, 0),
		suffix = "CenterRight"
	},
	Center = {
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.new(0.5, 0, 0.5, 0),
		suffix = "Center"
	},
}

local function createContainer(parent: ScreenGui, containerType: string): Frame?
	local config = CONTAINER_CONFIGS[containerType]
	if not config then
		return nil
	end

	local container = Instance.new("Frame")
	container.Name = config.suffix .. "Container"
	container.AnchorPoint = config.anchor
	container.Position = config.position
	container.Size = UDim2.new(0.3, 0, 0.3, 0) -- Default 30% of screen
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0

	-- Add UISizeConstraint for bounded sizing
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(100, 50)
	sizeConstraint.MaxSize = Vector2.new(400, 600)
	sizeConstraint.Parent = container

	-- Add UIListLayout for automatic child arrangement
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = container

	-- Add UIPadding for internal spacing
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = container

	container.Parent = parent
	return container
end

local function handleCreateResponsiveLayout(args: Types.ToolArgs): string?
	if not args["CreateResponsiveLayout"] then
		return nil
	end

	local layoutArgs: CreateResponsiveLayoutArgs = args["CreateResponsiveLayout"]

	if not layoutArgs.name or layoutArgs.name == "" then
		return "[ERROR] Missing 'name' parameter for ScreenGui"
	end

	if not layoutArgs.containers or #layoutArgs.containers == 0 then
		return "[ERROR] Missing or empty 'containers' array. Specify positions like ['TopLeft', 'BottomCenter']"
	end

	-- Check if ScreenGui already exists
	local existing = StarterGui:FindFirstChild(layoutArgs.name)
	if existing then
		return "[ERROR] ScreenGui '" .. layoutArgs.name .. "' already exists in StarterGui"
	end

	-- Validate container types
	local invalidContainers = {}
	for _, containerType in layoutArgs.containers do
		if not CONTAINER_CONFIGS[containerType] then
			table.insert(invalidContainers, containerType)
		end
	end
	if #invalidContainers > 0 then
		local validTypes = {}
		for key in CONTAINER_CONFIGS do
			table.insert(validTypes, key)
		end
		return "[ERROR] Invalid container type(s): " .. table.concat(invalidContainers, ", ") ..
			"\nValid types: " .. table.concat(validTypes, ", ")
	end

	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = layoutArgs.name
	screenGui.IgnoreGuiInset = true -- Full screen coverage
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Create requested containers
	local createdContainers = {}
	for _, containerType in layoutArgs.containers do
		local container = createContainer(screenGui, containerType)
		if container then
			table.insert(createdContainers, container.Name)
		end
	end

	screenGui.Parent = StarterGui

	local structure = layoutArgs.name .. " (ScreenGui, IgnoreGuiInset=true)\n"
	for _, containerName in createdContainers do
		structure = structure .. "├── " .. containerName .. "\n"
		structure = structure .. "│   ├── UISizeConstraint (Min 100x50, Max 400x600)\n"
		structure = structure .. "│   ├── UIListLayout (Vertical)\n"
		structure = structure .. "│   └── UIPadding (8px)\n"
	end

	return "[SUCCESS] Created responsive layout in StarterGui:\n\n" .. structure
end

return handleCreateResponsiveLayout :: Types.ToolFunction
