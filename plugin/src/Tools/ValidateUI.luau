local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

type ValidateUIArgs = {
	path: string?,
}

type Issue = {
	type: string,
	path: string,
	message: string,
	details: any?,
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

local function isGuiObject(instance: Instance): boolean
	return instance:IsA("GuiObject")
end

local function getViewportSize(): Vector2
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080) -- fallback
end

local function checkPixelPositioning(element: GuiObject, issues: {Issue})
	local pos = element.Position
	local size = element.Size

	-- Check if using only Offset for positioning (no Scale)
	if pos.X.Scale == 0 and pos.X.Offset ~= 0 then
		table.insert(issues, {
			type = "pixel_positioning",
			path = getFullPath(element),
			message = "X position uses only Offset without Scale - may not be responsive",
			details = { position = tostring(pos) }
		})
	end
	if pos.Y.Scale == 0 and pos.Y.Offset ~= 0 then
		table.insert(issues, {
			type = "pixel_positioning",
			path = getFullPath(element),
			message = "Y position uses only Offset without Scale - may not be responsive",
			details = { position = tostring(pos) }
		})
	end

	-- Check if using only Offset for sizing (common issue)
	if size.X.Scale == 0 and size.X.Offset > 100 then
		table.insert(issues, {
			type = "pixel_sizing",
			path = getFullPath(element),
			message = "Width uses only Offset - may not scale on different screens",
			details = { size = tostring(size) }
		})
	end
	if size.Y.Scale == 0 and size.Y.Offset > 100 then
		table.insert(issues, {
			type = "pixel_sizing",
			path = getFullPath(element),
			message = "Height uses only Offset - may not scale on different screens",
			details = { size = tostring(size) }
		})
	end
end

local function checkMissingConstraints(element: GuiObject, issues: {Issue})
	-- Check if it's a container (has children that are GuiObjects)
	local hasGuiChildren = false
	for _, child in element:GetChildren() do
		if isGuiObject(child) then
			hasGuiChildren = true
			break
		end
	end

	if hasGuiChildren then
		local hasConstraint = element:FindFirstChildOfClass("UISizeConstraint")
		local hasLayout = element:FindFirstChildOfClass("UIListLayout") or element:FindFirstChildOfClass("UIGridLayout")

		if not hasConstraint and element.Size.X.Scale > 0 and element.Size.Y.Scale > 0 then
			table.insert(issues, {
				type = "missing_constraint",
				path = getFullPath(element),
				message = "Container with Scale sizing has no UISizeConstraint - size may be unbounded",
				details = { childCount = #element:GetChildren() }
			})
		end
	end
end

local function checkAnchorMismatch(element: GuiObject, issues: {Issue})
	local anchor = element.AnchorPoint
	local pos = element.Position

	-- Check for common mismatches
	-- Right-aligned (Scale X = 1) should have AnchorPoint.X = 1
	if pos.X.Scale >= 0.9 and anchor.X < 0.5 then
		table.insert(issues, {
			type = "anchor_mismatch",
			path = getFullPath(element),
			message = "Position near right edge but AnchorPoint.X is left-aligned",
			details = { anchorPoint = tostring(anchor), position = tostring(pos) }
		})
	end
	-- Bottom-aligned (Scale Y = 1) should have AnchorPoint.Y = 1
	if pos.Y.Scale >= 0.9 and anchor.Y < 0.5 then
		table.insert(issues, {
			type = "anchor_mismatch",
			path = getFullPath(element),
			message = "Position near bottom edge but AnchorPoint.Y is top-aligned",
			details = { anchorPoint = tostring(anchor), position = tostring(pos) }
		})
	end
	-- Center-aligned should have AnchorPoint = 0.5
	if pos.X.Scale > 0.4 and pos.X.Scale < 0.6 and math.abs(anchor.X - 0.5) > 0.1 then
		table.insert(issues, {
			type = "anchor_mismatch",
			path = getFullPath(element),
			message = "Position is centered but AnchorPoint.X is not 0.5",
			details = { anchorPoint = tostring(anchor), position = tostring(pos) }
		})
	end
end

local function checkOffscreen(element: GuiObject, viewport: Vector2, issues: {Issue})
	local absPos = element.AbsolutePosition
	local absSize = element.AbsoluteSize

	-- Check if element is partially or fully offscreen
	local right = absPos.X + absSize.X
	local bottom = absPos.Y + absSize.Y

	if absPos.X < 0 or absPos.Y < 0 or right > viewport.X or bottom > viewport.Y then
		local offscreenDir = {}
		if absPos.X < 0 then table.insert(offscreenDir, "left") end
		if absPos.Y < 0 then table.insert(offscreenDir, "top") end
		if right > viewport.X then table.insert(offscreenDir, "right") end
		if bottom > viewport.Y then table.insert(offscreenDir, "bottom") end

		table.insert(issues, {
			type = "offscreen",
			path = getFullPath(element),
			message = "Element extends offscreen: " .. table.concat(offscreenDir, ", "),
			details = {
				absolutePosition = { x = absPos.X, y = absPos.Y },
				absoluteSize = { x = absSize.X, y = absSize.Y },
				viewport = { x = viewport.X, y = viewport.Y }
			}
		})
	end
end

local function checkOverlaps(elements: {{element: GuiObject, absPos: Vector2, absSize: Vector2}}, issues: {Issue})
	for i = 1, #elements do
		for j = i + 1, #elements do
			local a = elements[i]
			local b = elements[j]

			-- Skip if same parent (siblings in a layout are expected to not overlap)
			if a.element.Parent == b.element.Parent then
				local layout = a.element.Parent:FindFirstChildOfClass("UIListLayout") or a.element.Parent:FindFirstChildOfClass("UIGridLayout")
				if layout then continue end
			end

			-- Check AABB overlap
			local aRight = a.absPos.X + a.absSize.X
			local aBottom = a.absPos.Y + a.absSize.Y
			local bRight = b.absPos.X + b.absSize.X
			local bBottom = b.absPos.Y + b.absSize.Y

			local overlaps = not (aRight < b.absPos.X or bRight < a.absPos.X or aBottom < b.absPos.Y or bBottom < a.absPos.Y)

			if overlaps and a.absSize.X > 10 and a.absSize.Y > 10 and b.absSize.X > 10 and b.absSize.Y > 10 then
				table.insert(issues, {
					type = "overlap",
					path = getFullPath(a.element),
					message = "Overlaps with " .. getFullPath(b.element),
					details = {
						elementA = { path = getFullPath(a.element), pos = { x = a.absPos.X, y = a.absPos.Y }, size = { x = a.absSize.X, y = a.absSize.Y } },
						elementB = { path = getFullPath(b.element), pos = { x = b.absPos.X, y = b.absPos.Y }, size = { x = b.absSize.X, y = b.absSize.Y } }
					}
				})
			end
		end
	end
end

local function validateScreenGui(screenGui: ScreenGui, issues: {Issue})
	local viewport = getViewportSize()
	local visibleElements: {{element: GuiObject, absPos: Vector2, absSize: Vector2}} = {}

	local function processElement(element: Instance)
		if not isGuiObject(element) then return end
		local guiObj = element :: GuiObject

		if guiObj.Visible then
			checkPixelPositioning(guiObj, issues)
			checkMissingConstraints(guiObj, issues)
			checkAnchorMismatch(guiObj, issues)
			checkOffscreen(guiObj, viewport, issues)

			table.insert(visibleElements, {
				element = guiObj,
				absPos = guiObj.AbsolutePosition,
				absSize = guiObj.AbsoluteSize
			})
		end

		for _, child in element:GetChildren() do
			processElement(child)
		end
	end

	for _, child in screenGui:GetChildren() do
		processElement(child)
	end

	-- Check for overlaps among visible elements
	checkOverlaps(visibleElements, issues)
end

local function handleValidateUI(args: Types.ToolArgs): string?
	if not args["ValidateUI"] then
		return nil
	end

	local validateArgs: ValidateUIArgs = args["ValidateUI"]
	local issues: {Issue} = {}

	if validateArgs.path then
		-- Validate specific ScreenGui
		local parts = string.split(validateArgs.path, ".")
		local current: Instance = game
		for _, part in parts do
			local child = current:FindFirstChild(part)
			if not child then
				return "[ERROR] Path not found: " .. validateArgs.path .. " (failed at: " .. part .. ")"
			end
			current = child
		end

		if not current:IsA("ScreenGui") then
			return "[ERROR] Path does not point to a ScreenGui: " .. current.ClassName
		end

		validateScreenGui(current :: ScreenGui, issues)
	else
		-- Validate all ScreenGuis in StarterGui
		for _, child in StarterGui:GetChildren() do
			if child:IsA("ScreenGui") then
				validateScreenGui(child, issues)
			end
		end
	end

	local result = {
		issueCount = #issues,
		viewport = {
			x = getViewportSize().X,
			y = getViewportSize().Y
		},
		issues = issues
	}

	if #issues == 0 then
		return "[SUCCESS] No UI issues found.\n\n" .. HttpService:JSONEncode(result)
	else
		return "[WARNING] Found " .. #issues .. " UI issue(s).\n\n" .. HttpService:JSONEncode(result)
	end
end

return handleValidateUI :: Types.ToolFunction
