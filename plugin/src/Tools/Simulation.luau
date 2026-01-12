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
	-- Check if already stopped
	if not RunService:IsRunning() then
		return HttpService:JSONEncode({
			success = true,
			verified = true,
			note = "Already in edit mode.",
			mode = "edit",
		})
	end

	local previousMode = RunService:IsRunMode() and "simulation" or "playtest"

	local success, err = pcall(function()
		RunService:Stop()
	end)

	if not success then
		return HttpService:JSONEncode({
			success = false,
			error = "RunService:Stop() failed: " .. tostring(err),
			previousMode = previousMode,
		})
	end

	-- Verify simulation/playtest stopped
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
