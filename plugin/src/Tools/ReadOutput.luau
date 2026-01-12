local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)
local OutputCapture = require(Main.OutputCapture)

--[[
	Handles the read_output MCP tool request.

	Reads buffered output from the Output window with optional filtering and limiting.

	@param args Tool arguments from MCP
	@return Formatted output string, or nil if this handler doesn't match
]]
local function handleReadOutput(args: Types.ToolArgs): string?
	-- Check if this is a ReadOutput request
	if not args["ReadOutput"] then
		return nil
	end

	local readOutputArgs: Types.ReadOutputArgs = args["ReadOutput"]

	-- Extract parameters with defaults
	local filter = readOutputArgs.filter or "all"
	local maxLines = readOutputArgs.max_lines or OutputCapture.DEFAULT_MAX_LINES
	local clearAfterRead = readOutputArgs.clear_after_read
	if clearAfterRead == nil then
		clearAfterRead = true
	end

	-- Validate filter parameter using exposed constants
	if not OutputCapture.VALID_FILTERS[filter] then
		local validOptions = {}
		for key in OutputCapture.VALID_FILTERS do
			table.insert(validOptions, '"' .. key .. '"')
		end
		table.sort(validOptions)
		error(string.format("Invalid filter '%s'. Must be one of: %s", filter, table.concat(validOptions, ", ")))
	end

	-- Validate maxLines
	if type(maxLines) ~= "number" or maxLines < 1 then
		error("max_lines must be a positive number")
	end

	-- Get stats before reading (for dropped count)
	local stats = OutputCapture.getStats()

	-- Read buffered output
	local entries = OutputCapture.read(filter, maxLines, clearAfterRead)

	-- Handle empty buffer
	if #entries == 0 then
		local emptyMsg = "[No output captured]"
		if stats.droppedCount > 0 then
			emptyMsg = emptyMsg
				.. string.format(" (Note: %d messages were dropped due to buffer overflow)", stats.droppedCount)
		end
		return emptyMsg
	end

	-- Format response with summary header
	local formatted = OutputCapture.format(entries)
	local summary = string.format(
		"[Captured %d message%s (filter: %s, cleared: %s)]",
		#entries,
		if #entries == 1 then "" else "s",
		filter,
		tostring(clearAfterRead)
	)

	-- Add warning if messages were dropped
	if stats.droppedCount > 0 then
		summary = summary
			.. string.format("\n[WARNING: %d messages were dropped due to buffer overflow]", stats.droppedCount)
	end

	return summary .. "\n\n" .. formatted
end

return handleReadOutput :: Types.ToolFunction
