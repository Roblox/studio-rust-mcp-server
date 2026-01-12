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
	-- Check if already in playtest/simulation mode
	if RunService:IsRunning() then
		return HttpService:JSONEncode({
			success = false,
			error = "Studio is already running. Call stop_playtest first.",
			currentMode = RunService:IsRunMode() and "simulation" or "playtest",
		})
	end

	-- Try StudioTestService first (starts with player character)
	if StudioTestService then
		local success, err = pcall(function()
			-- ExecutePlayModeAsync is a yielding function - it waits until playtest starts
			StudioTestService:ExecutePlayModeAsync({})
		end)

		if not success then
			return HttpService:JSONEncode({
				success = false,
				error = "ExecutePlayModeAsync failed: " .. tostring(err),
				suggestion = "Try stopping any pending playtest operations first.",
			})
		end

		-- Verify playtest actually started
		local verified, verifyErr = waitForState(true, VERIFICATION_TIMEOUT)

		if verified then
			-- Additional check: verify it's playtest mode (not simulation)
			local isPlaytest = RunService:IsRunning() and not RunService:IsRunMode()
			return HttpService:JSONEncode({
				success = true,
				verified = true,
				mode = isPlaytest and "playtest" or "simulation",
				hasPlayer = isPlaytest,
			})
		else
			return HttpService:JSONEncode({
				success = false,
				error = "Playtest started but verification failed: " .. tostring(verifyErr),
				isRunning = RunService:IsRunning(),
			})
		end
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

	-- Verify simulation started
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
