local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

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

local function startSimulation(): string
	-- Check if already in playtest/simulation mode
	if RunService:IsRunning() then
		return HttpService:JSONEncode({
			success = false,
			error = "Studio is already running. Call stop_simulation first.",
			currentMode = RunService:IsRunMode() and "simulation" or "playtest",
		})
	end

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
			note = "Started simulation mode (F8). Physics running without player.",
		})
	else
		return HttpService:JSONEncode({
			success = false,
			error = "Simulation call succeeded but verification failed: " .. tostring(verifyErr),
		})
	end
end

local function stopSimulation(): string
	-- Note: We cannot reliably check IsRunning() because it returns false from plugin
	-- context during playtest due to DataModel isolation. We'll try to stop anyway.

	local wasRunning = RunService:IsRunning()
	local previousMode = RunService:IsRunMode() and "simulation" or "playtest"

	local success, err = pcall(function()
		RunService:Stop()
	end)

	if not success then
		return HttpService:JSONEncode({
			success = false,
			error = "RunService:Stop() failed: " .. tostring(err),
		})
	end

	-- For simulation mode, verification works. For playtest, IsRunning() was already false.
	if wasRunning then
		-- We were in simulation mode - verify it stopped
		local verified, verifyErr = waitForState(false, VERIFICATION_TIMEOUT)
		if verified then
			return HttpService:JSONEncode({
				success = true,
				verified = true,
				previousMode = previousMode,
				mode = "edit",
				note = "Stopped " .. previousMode .. ". Returned to edit mode.",
			})
		else
			return HttpService:JSONEncode({
				success = false,
				error = "Stop call succeeded but verification failed: " .. tostring(verifyErr),
				previousMode = previousMode,
			})
		end
	else
		-- IsRunning() was false - we're either in edit mode OR playtest mode
		-- (can't tell from plugin context due to DataModel isolation)
		-- RunService:Stop() only works for simulation mode, NOT playtest mode.
		-- For playtest, user must manually stop OR use run_server_code with EndTest()
		return HttpService:JSONEncode({
			success = true,
			mode = "edit",
			note = "RunService:Stop() called. Note: This only stops SIMULATION mode. For PLAYTEST mode, use run_server_code to call StudioTestService:EndTest(), or manually press Stop (F6).",
		})
	end
end

local function handleSimulation(args: Types.ToolArgs): string?
	if args["StartSimulation"] then
		return startSimulation()
	elseif args["StopSimulation"] or args["StopPlaytest"] then
		return stopSimulation()
	end
	return nil
end

return handleSimulation :: Types.ToolFunction
