--[[
	OutputCapture Module

	Captures output from Roblox Studio's Output window using LogService.MessageOut.
	Provides silent buffering to avoid feedback loops and supports filtering by message level.

	THREAD SAFETY NOTE:
	Luau in Roblox runs in a single-threaded environment. The LogService.MessageOut
	callback and all read/clear operations execute on the same thread, so concurrent
	access to the buffer is not possible. No explicit synchronization is needed.

	CRITICAL: Never call print(), warn(), or error() inside the MessageOut handler
	to prevent infinite recursion!

	TIMESTAMP FORMAT:
	Timestamps use os.clock() which returns high-precision elapsed time in seconds
	since an arbitrary point (typically script start). Use for relative timing only,
	not absolute wall-clock time.
]]

-- Configuration constants
local MAX_BUFFER_SIZE = 10000 -- Maximum entries before FIFO eviction (memory bounded ~10MB)
local DEFAULT_MAX_LINES = 1000 -- Default number of lines returned to caller

-- Valid filter options
local VALID_FILTERS = {
	all = true,
	print = true,
	warn = true,
	error = true,
}

-- Types
type LogLevel = "print" | "warn" | "error"

type LogEntry = {
	timestamp: number, -- os.clock() value (seconds since script start)
	messageType: Enum.MessageType,
	message: string,
	level: LogLevel,
}

type BufferStats = {
	currentSize: number,
	maxSize: number,
	droppedCount: number,
	oldestTimestamp: number?,
	newestTimestamp: number?,
}

-- Buffer state
local OutputBuffer = {
	entries = {} :: { LogEntry },
	maxSize = MAX_BUFFER_SIZE,
	droppedCount = 0, -- Track messages lost to FIFO eviction
	connection = nil :: RBXScriptConnection?,
}

--[[
	Adds a message to the buffer silently (NO print/warn/error calls!)

	@param messageType The Roblox MessageType enum value
	@param message The message string
]]
local function addToBuffer(message: string, messageType: Enum.MessageType)
	-- CRITICAL: NO print/warn/error calls here to avoid feedback loop!

	-- Determine log level from messageType
	local level: LogLevel
	if messageType == Enum.MessageType.MessageWarning then
		level = "warn"
	elseif messageType == Enum.MessageType.MessageError then
		level = "error"
	else
		level = "print"
	end

	-- Create log entry
	local entry: LogEntry = {
		timestamp = os.clock(),
		messageType = messageType,
		message = message,
		level = level,
	}

	-- Add to buffer
	table.insert(OutputBuffer.entries, entry)

	-- FIFO eviction if buffer exceeds maxSize
	if #OutputBuffer.entries > OutputBuffer.maxSize then
		table.remove(OutputBuffer.entries, 1)
		OutputBuffer.droppedCount += 1
	end
end

--[[
	Initializes the persistent LogService.MessageOut connection.
	Should be called once at plugin startup.

	This connection survives Play mode transitions and MCP connection toggles.
]]
local function initializeCapture()
	if OutputBuffer.connection then
		return -- Already initialized
	end

	local LogService = game:GetService("LogService")

	-- Connect to MessageOut - captures ALL output messages system-wide
	OutputBuffer.connection = LogService.MessageOut:Connect(function(message, messageType)
		addToBuffer(message, messageType)
	end)
end

--[[
	Reads buffered output with optional filtering and limiting.

	@param filter Filter by level: "all", "print", "warn", or "error"
	@param maxLines Maximum number of lines to return (most recent)
	@param clearAfterRead If true, clears the buffer after reading
	@return Array of log entries matching the filter criteria
]]
local function readOutput(
	filter: string?,
	maxLines: number?,
	clearAfterRead: boolean?
): { LogEntry }
	-- Apply defaults
	filter = filter or "all"
	maxLines = maxLines or DEFAULT_MAX_LINES
	clearAfterRead = if clearAfterRead == nil then true else clearAfterRead

	-- Filter entries by level
	local filtered = {}

	for _, entry in OutputBuffer.entries do
		if filter == "all" or entry.level == filter then
			table.insert(filtered, entry)
		end
	end

	-- Limit to maxLines (return most recent)
	local startIndex = math.max(1, #filtered - maxLines + 1)
	local result = {}

	for i = startIndex, #filtered do
		table.insert(result, filtered[i])
	end

	-- Clear buffer if requested
	if clearAfterRead then
		OutputBuffer.entries = {}
	end

	return result
end

--[[
	Formats log entries into a readable string for MCP response.

	@param entries Array of log entries to format
	@return Formatted string with [OUTPUT]/[WARNING]/[ERROR] prefixes
]]
local function formatEntries(entries: { LogEntry }): string
	local lines = {}

	for _, entry in entries do
		-- Add appropriate prefix based on level
		local prefix = if entry.level == "warn"
			then "[WARNING]"
			elseif entry.level == "error" then "[ERROR]"
			else "[OUTPUT]"

		table.insert(lines, prefix .. " " .. entry.message)
	end

	return table.concat(lines, "\n")
end

--[[
	Clears all buffered output and resets the dropped counter.
]]
local function clearBuffer()
	OutputBuffer.entries = {}
	OutputBuffer.droppedCount = 0
end

--[[
	Returns statistics about the current buffer state.
	Useful for debugging and monitoring buffer health.

	@return BufferStats table with current size, max size, dropped count, and timestamps
]]
local function getStats(): BufferStats
	local entries = OutputBuffer.entries
	local oldest = entries[1]
	local newest = entries[#entries]

	return {
		currentSize = #entries,
		maxSize = OutputBuffer.maxSize,
		droppedCount = OutputBuffer.droppedCount,
		oldestTimestamp = if oldest then oldest.timestamp else nil,
		newestTimestamp = if newest then newest.timestamp else nil,
	}
end

--[[
	Disconnects the LogService connection and clears the buffer.
	Useful for cleanup, though typically not needed during normal operation.
]]
local function shutdown()
	if OutputBuffer.connection then
		OutputBuffer.connection:Disconnect()
		OutputBuffer.connection = nil
	end
	clearBuffer()
end

-- Public API
return {
	initialize = initializeCapture,
	read = readOutput,
	format = formatEntries,
	clear = clearBuffer,
	getStats = getStats,
	shutdown = shutdown,

	-- Constants exposed for validation
	VALID_FILTERS = VALID_FILTERS,
	DEFAULT_MAX_LINES = DEFAULT_MAX_LINES,
	MAX_BUFFER_SIZE = MAX_BUFFER_SIZE,
}
