local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

type PreviewLayoutArgs = {
	width: number,
	height: number,
	path: string?,
}

type ElementPreview = {
	path: string,
	className: string,
	visible: boolean,
	position: {
		udim2: string,
		absoluteX: number,
		absoluteY: number,
	},
	size: {
		udim2: string,
		absoluteWidth: number,
		absoluteHeight: number,
	},
	offscreen: boolean,
	offscreenEdges: {string}?,
	clipped: boolean,
}

local function getFullPath(instance: Instance): string
	local parts = {}
	local current = instance
	while current and current ~= game do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, ".")
end

local function getCurrentViewport(): Vector2
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

-- Calculate what AbsolutePosition/AbsoluteSize would be at target viewport
local function calculateAbsoluteAtViewport(
	element: GuiObject,
	targetWidth: number,
	targetHeight: number,
	currentViewport: Vector2
): (Vector2, Vector2)
	-- Get current absolute values
	local currentAbsPos = element.AbsolutePosition
	local currentAbsSize = element.AbsoluteSize

	-- Get the UDim2 values
	local pos = element.Position
	local size = element.Size

	-- Calculate parent's absolute position/size at target viewport
	-- For simplicity, we assume the element is directly under ScreenGui
	-- A more complete implementation would walk up the parent chain

	-- Calculate position at target viewport
	local targetPosX = pos.X.Scale * targetWidth + pos.X.Offset
	local targetPosY = pos.Y.Scale * targetHeight + pos.Y.Offset

	-- Adjust for AnchorPoint
	local anchor = element.AnchorPoint
	local targetSizeX = size.X.Scale * targetWidth + size.X.Offset
	local targetSizeY = size.Y.Scale * targetHeight + size.Y.Offset

	targetPosX = targetPosX - (anchor.X * targetSizeX)
	targetPosY = targetPosY - (anchor.Y * targetSizeY)

	return Vector2.new(targetPosX, targetPosY), Vector2.new(targetSizeX, targetSizeY)
end

local function previewElement(
	element: GuiObject,
	targetWidth: number,
	targetHeight: number,
	currentViewport: Vector2
): ElementPreview
	local targetPos, targetSize = calculateAbsoluteAtViewport(element, targetWidth, targetHeight, currentViewport)

	-- Check if offscreen
	local offscreenEdges = {}
	local right = targetPos.X + targetSize.X
	local bottom = targetPos.Y + targetSize.Y

	if targetPos.X < 0 then table.insert(offscreenEdges, "left") end
	if targetPos.Y < 0 then table.insert(offscreenEdges, "top") end
	if right > targetWidth then table.insert(offscreenEdges, "right") end
	if bottom > targetHeight then table.insert(offscreenEdges, "bottom") end

	local isOffscreen = #offscreenEdges > 0

	-- Check if clipped (partially offscreen)
	local isClipped = isOffscreen and (
		(targetPos.X >= 0 or right > 0) and
		(targetPos.Y >= 0 or bottom > 0) and
		(targetPos.X < targetWidth or right <= targetWidth) and
		(targetPos.Y < targetHeight or bottom <= targetHeight)
	)

	return {
		path = getFullPath(element),
		className = element.ClassName,
		visible = element.Visible,
		position = {
			udim2 = tostring(element.Position),
			absoluteX = math.floor(targetPos.X),
			absoluteY = math.floor(targetPos.Y),
		},
		size = {
			udim2 = tostring(element.Size),
			absoluteWidth = math.floor(targetSize.X),
			absoluteHeight = math.floor(targetSize.Y),
		},
		offscreen = isOffscreen,
		offscreenEdges = if isOffscreen then offscreenEdges else nil,
		clipped = isClipped,
	}
end

local function previewScreenGui(
	screenGui: ScreenGui,
	targetWidth: number,
	targetHeight: number,
	currentViewport: Vector2,
	elements: {ElementPreview}
)
	local function processElement(element: Instance)
		if not element:IsA("GuiObject") then return end
		local guiObj = element :: GuiObject

		if guiObj.Visible then
			table.insert(elements, previewElement(guiObj, targetWidth, targetHeight, currentViewport))
		end

		for _, child in element:GetChildren() do
			processElement(child)
		end
	end

	for _, child in screenGui:GetChildren() do
		processElement(child)
	end
end

local function handlePreviewLayout(args: Types.ToolArgs): string?
	if not args["PreviewLayout"] then
		return nil
	end

	local previewArgs: PreviewLayoutArgs = args["PreviewLayout"]

	if not previewArgs.width or previewArgs.width <= 0 then
		return "[ERROR] Missing or invalid 'width' parameter"
	end
	if not previewArgs.height or previewArgs.height <= 0 then
		return "[ERROR] Missing or invalid 'height' parameter"
	end

	local targetWidth = previewArgs.width
	local targetHeight = previewArgs.height
	local currentViewport = getCurrentViewport()
	local elements: {ElementPreview} = {}

	if previewArgs.path then
		-- Preview specific ScreenGui
		local parts = string.split(previewArgs.path, ".")
		local current: Instance = game
		for _, part in parts do
			local child = current:FindFirstChild(part)
			if not child then
				return "[ERROR] Path not found: " .. previewArgs.path .. " (failed at: " .. part .. ")"
			end
			current = child
		end

		if not current:IsA("ScreenGui") then
			return "[ERROR] Path does not point to a ScreenGui: " .. current.ClassName
		end

		previewScreenGui(current :: ScreenGui, targetWidth, targetHeight, currentViewport, elements)
	else
		-- Preview all ScreenGuis
		for _, child in StarterGui:GetChildren() do
			if child:IsA("ScreenGui") then
				previewScreenGui(child, targetWidth, targetHeight, currentViewport, elements)
			end
		end
	end

	-- Count issues
	local offscreenCount = 0
	local clippedCount = 0
	for _, elem in elements do
		if elem.offscreen and not elem.clipped then
			offscreenCount = offscreenCount + 1
		elseif elem.clipped then
			clippedCount = clippedCount + 1
		end
	end

	local result = {
		targetViewport = {
			width = targetWidth,
			height = targetHeight,
		},
		currentViewport = {
			width = currentViewport.X,
			height = currentViewport.Y,
		},
		summary = {
			totalElements = #elements,
			offscreen = offscreenCount,
			clipped = clippedCount,
		},
		elements = elements,
	}

	local statusMsg
	if offscreenCount > 0 or clippedCount > 0 then
		statusMsg = string.format(
			"[WARNING] At %dx%d: %d element(s) fully offscreen, %d clipped",
			targetWidth, targetHeight, offscreenCount, clippedCount
		)
	else
		statusMsg = string.format(
			"[SUCCESS] At %dx%d: All %d elements fit within viewport",
			targetWidth, targetHeight, #elements
		)
	end

	return statusMsg .. "\n\n" .. HttpService:JSONEncode(result)
end

return handlePreviewLayout :: Types.ToolFunction
