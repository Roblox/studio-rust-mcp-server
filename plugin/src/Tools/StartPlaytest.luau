local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Try to get StudioTestService (may not exist in older Studio versions)
local StudioTestService = nil
pcall(function()
	StudioTestService = game:GetService("StudioTestService")
end)

-- Configuration
local VERIFICATION_TIMEOUT = 10 -- seconds to wait for state change
local POLL_INTERVAL = 0.1 -- seconds between state checks
local MAX_RETRIES = 10 -- number of retries for pending operation error
local RETRY_DELAY = 0.5 -- seconds between retries
local ERROR_CHECK_DELAY = 0.3 -- seconds to wait for immediate errors

-- Wait for RunService state to change with timeout
local function waitForState(targetRunning: boolean, timeout: number): (boolean, string?)
	local startTime = os.clock()

	while os.clock() - startTime < timeout do
		local isRunning = RunService:IsRunning()
		if isRunning == targetRunning then
			return true, nil
		end
		task.wait(POLL_INTERVAL)
	end

	return false, string.format(
		"Timeout after %.1fs waiting for state change (expected IsRunning=%s, got %s)",
		timeout, tostring(targetRunning), tostring(RunService:IsRunning())
	)
end

local function startPlaytest(): string
	-- Note: We cannot reliably check if already running because RunService:IsRunning()
	-- returns false from plugin context during playtest due to DataModel isolation.
	-- StudioTestService will return an error if playtest is already running.

	-- Try StudioTestService first (starts with player character)
	if StudioTestService then
		local lastError = nil

		for attempt = 1, MAX_RETRIES do
			-- Use task.spawn because ExecutePlayModeAsync blocks until playtest starts.
			-- We need to return the HTTP response reasonably quickly.
			local startError = nil
			local completed = false

			task.spawn(function()
				local success, err = pcall(function()
					StudioTestService:ExecutePlayModeAsync({})
				end)
				completed = true
				if not success then
					startError = tostring(err)
				end
			end)

			-- Wait a short time for immediate errors (like "pending" or "already running")
			task.wait(ERROR_CHECK_DELAY)

			if completed and startError then
				-- Got an immediate error
				lastError = startError

				-- Check if it's the "pending operation" error - if so, retry after delay
				if string.find(startError, "Previous call to start play session has not been completed") then
					if attempt < MAX_RETRIES then
						warn(string.format("[MCP] Playtest pending, retry %d/%d in %.1fs...", attempt, MAX_RETRIES, RETRY_DELAY))
						task.wait(RETRY_DELAY)
						continue
					end
				else
					-- Different error, don't retry
					break
				end
			elseif not completed then
				-- No immediate error and still running = playtest is starting successfully
				return HttpService:JSONEncode({
					success = true,
					mode = "playtest",
					hasPlayer = true,
					note = "Started playtest mode (F5) via StudioTestService.",
					attempts = attempt,
				})
			else
				-- Completed with no error = success
				return HttpService:JSONEncode({
					success = true,
					mode = "playtest",
					hasPlayer = true,
					note = "Started playtest mode (F5) via StudioTestService.",
					attempts = attempt,
				})
			end
		end

		return HttpService:JSONEncode({
			success = false,
			error = "ExecutePlayModeAsync failed: " .. (lastError or "unknown error"),
			suggestion = "Press F6 to manually stop any pending playtest, then try again.",
		})
	end

	-- Fallback: StudioTestService not available, use RunService:Run() (simulation mode)
	local success, err = pcall(function()
		RunService:Run()
	end)

	if not success then
		return HttpService:JSONEncode({
			success = false,
			error = "RunService:Run() failed: " .. tostring(err),
		})
	end

	-- For simulation mode, RunService:IsRunning() DOES work from plugin context
	-- because simulation runs in the same DataModel
	local verified, verifyErr = waitForState(true, VERIFICATION_TIMEOUT)

	if verified then
		return HttpService:JSONEncode({
			success = true,
			verified = true,
			mode = "simulation",
			note = "Started simulation mode (F8) - StudioTestService not available.",
			hasPlayer = false,
		})
	else
		return HttpService:JSONEncode({
			success = false,
			error = "Simulation started but verification failed: " .. tostring(verifyErr),
		})
	end
end

local function handleStartPlaytest(args: Types.ToolArgs): string?
	if not args["StartPlaytest"] then
		return nil
	end

	return startPlaytest()
end

return handleStartPlaytest :: Types.ToolFunction
