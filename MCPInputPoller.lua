--[[
================================================================================
MCP INPUT SIMULATION - GAME-SIDE SCRIPTS
================================================================================

These scripts must be added to YOUR GAME to receive MCP input commands.
The MCP server provides the tools (simulate_input, click_gui), but your game
needs these scripts to actually respond to the commands.

================================================================================
ARCHITECTURE
================================================================================

    MCP Server (Rust)                    Your Roblox Game
    =================                    ================

    simulate_input() ----HTTP POST---->  /mcp/input endpoint
    click_gui()                                |
                                               | (commands queued)
                                               v
                                        MCPInputPoller (ServerScript)
                                               | polls endpoint
                                               | every 0.1 seconds
                                               v
                                        MCPInputCommand (RemoteEvent)
                                               |
                                               v
                                        MCPInputHandler (LocalScript)
                                               | fires BindableEvent
                                               v
                                        MCPInputReceived (BindableEvent)
                                               |
                         +---------------------+---------------------+
                         |                     |                     |
                         v                     v                     v
                  MCPMovementController   Your Ability Script   Your GUI Handler
                  (handles WASD/Space)    (handles Q,E,R,F)     (handles clicks)

================================================================================
WHAT YOU NEED TO ADD TO YOUR GAME
================================================================================

REQUIRED (without these, MCP input won't work at all):
  1. MCPInputPoller     -> ServerScriptService (Script)
  2. MCPInputHandler    -> StarterPlayerScripts (LocalScript)

OPTIONAL (add these for specific functionality):
  3. MCPMovementController -> StarterPlayerScripts (LocalScript)
     - Enables WASD movement and Space to jump via MCP
     - Without this, simulate_input("W") won't move your character

  4. Ability Integration -> Your existing ability scripts
     - Add ~15 lines to make your abilities respond to MCP input
     - Without this, simulate_input("E") won't trigger abilities

================================================================================
QUICK START
================================================================================

1. In Roblox Studio, go to Game Settings > Security > Enable "Allow HTTP Requests"

2. Create a new Script in ServerScriptService named "MCPInputPoller"
   Copy the code from SCRIPT 1 below (remove the --[[ and ]] comment markers)

3. Create a new LocalScript in StarterPlayerScripts named "MCPInputHandler"
   Copy the code from SCRIPT 2 below (remove the --[[ and ]] comment markers)

4. Test it:
   - Start playtest (F5)
   - Use simulate_input or click_gui from MCP
   - Check Output for "[MCPPoller] Got 1 commands!"

5. (Optional) Add MCPMovementController for WASD movement
6. (Optional) Add ability integration to your game's ability scripts

================================================================================
]]

--============================================================================
-- SCRIPT 1: MCPInputPoller (REQUIRED)
-- Location: ServerScriptService
-- Type: Script (not LocalScript)
--
-- This script polls the MCP server for commands and relays them to clients.
--============================================================================
--[[
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Configuration
local MCP_URL = "http://localhost:44755/mcp/input"
local POLL_INTERVAL = 0.1  -- Poll every 100ms

-- Create RemoteEvent for server->client communication
local inputEvent = ReplicatedStorage:FindFirstChild("MCPInputCommand")
if not inputEvent then
	inputEvent = Instance.new("RemoteEvent")
	inputEvent.Name = "MCPInputCommand"
	inputEvent.Parent = ReplicatedStorage
end

-- Send command to all connected players
local function processCommand(command)
	print("[MCPPoller] Received:", command.command_type)
	for _, player in Players:GetPlayers() do
		inputEvent:FireClient(player, command)
	end
end

-- Main polling loop
local function pollLoop()
	print("[MCPPoller] Started - polling " .. MCP_URL)
	while true do
		local success, result = pcall(function()
			local response = HttpService:GetAsync(MCP_URL)
			return HttpService:JSONDecode(response)
		end)

		if success and result and result.commands then
			if #result.commands > 0 then
				print("[MCPPoller] Got", #result.commands, "commands!")
			end
			for _, command in ipairs(result.commands) do
				processCommand(command)
			end
		end

		task.wait(POLL_INTERVAL)
	end
end

-- Start polling in background
task.spawn(pollLoop)
print("[MCPPoller] Script loaded - waiting for playtest to start polling")
]]


--============================================================================
-- SCRIPT 2: MCPInputHandler (REQUIRED)
-- Location: StarterPlayerScripts
-- Type: LocalScript
--
-- This script receives commands from the server and fires BindableEvents
-- that your game scripts can listen to.
--============================================================================
--[[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- Key name to KeyCode mapping
local KEY_MAP = {
	-- Letters
	A = Enum.KeyCode.A, B = Enum.KeyCode.B, C = Enum.KeyCode.C, D = Enum.KeyCode.D,
	E = Enum.KeyCode.E, F = Enum.KeyCode.F, G = Enum.KeyCode.G, H = Enum.KeyCode.H,
	I = Enum.KeyCode.I, J = Enum.KeyCode.J, K = Enum.KeyCode.K, L = Enum.KeyCode.L,
	M = Enum.KeyCode.M, N = Enum.KeyCode.N, O = Enum.KeyCode.O, P = Enum.KeyCode.P,
	Q = Enum.KeyCode.Q, R = Enum.KeyCode.R, S = Enum.KeyCode.S, T = Enum.KeyCode.T,
	U = Enum.KeyCode.U, V = Enum.KeyCode.V, W = Enum.KeyCode.W, X = Enum.KeyCode.X,
	Y = Enum.KeyCode.Y, Z = Enum.KeyCode.Z,
	-- Special keys
	Space = Enum.KeyCode.Space,
	Return = Enum.KeyCode.Return,
	Tab = Enum.KeyCode.Tab,
	Escape = Enum.KeyCode.Escape,
	Backspace = Enum.KeyCode.Backspace,
	-- Modifiers
	LeftShift = Enum.KeyCode.LeftShift,
	RightShift = Enum.KeyCode.RightShift,
	LeftControl = Enum.KeyCode.LeftControl,
	RightControl = Enum.KeyCode.RightControl,
	LeftAlt = Enum.KeyCode.LeftAlt,
	RightAlt = Enum.KeyCode.RightAlt,
	-- Arrow keys
	Up = Enum.KeyCode.Up,
	Down = Enum.KeyCode.Down,
	Left = Enum.KeyCode.Left,
	Right = Enum.KeyCode.Right,
	-- Numbers
	One = Enum.KeyCode.One, Two = Enum.KeyCode.Two, Three = Enum.KeyCode.Three,
	Four = Enum.KeyCode.Four, Five = Enum.KeyCode.Five, Six = Enum.KeyCode.Six,
	Seven = Enum.KeyCode.Seven, Eight = Enum.KeyCode.Eight, Nine = Enum.KeyCode.Nine,
	Zero = Enum.KeyCode.Zero,
}

-- Mouse button mapping
local MOUSE_MAP = {
	Left = Enum.UserInputType.MouseButton1,
	Right = Enum.UserInputType.MouseButton2,
	Middle = Enum.UserInputType.MouseButton3,
}

-- Helper: Find GUI element by path
local function findGui(path)
	if not player.PlayerGui then return nil end
	local parts = string.split(path, ".")
	local current = player.PlayerGui

	-- Skip PlayerGui/StarterGui prefix if present
	if parts[1] == "PlayerGui" or parts[1] == "StarterGui" then
		table.remove(parts, 1)
	end

	for _, part in ipairs(parts) do
		current = current:FindFirstChild(part)
		if not current then return nil end
	end
	return current
end

-- Helper: Get or create BindableEvent
local function getEvent(name)
	local e = ReplicatedStorage:FindFirstChild(name)
	if not e then
		e = Instance.new("BindableEvent")
		e.Name = name
		e.Parent = ReplicatedStorage
	end
	return e
end

-- Handle keyboard input commands
local function handleKeyboard(data)
	local keyCode = KEY_MAP[data.key]
	if not keyCode then
		warn("[MCPInput] Unknown key:", data.key)
		return
	end

	local event = getEvent("MCPInputReceived")
	local info = {
		KeyCode = keyCode,
		UserInputType = Enum.UserInputType.Keyboard
	}

	if data.action == "tap" then
		-- Tap = quick press and release
		info.UserInputState = Enum.UserInputState.Begin
		event:Fire(info)
		task.wait(0.05)
		info.UserInputState = Enum.UserInputState.End
		event:Fire(info)
	else
		-- Begin or End
		info.UserInputState = data.action == "begin"
			and Enum.UserInputState.Begin
			or Enum.UserInputState.End
		event:Fire(info)
	end

	print("[MCPInput] Key:", data.key, data.action)
end

-- Handle mouse input commands
local function handleMouse(data)
	local button = MOUSE_MAP[data.key]
	if not button then
		warn("[MCPInput] Unknown mouse button:", data.key)
		return
	end

	local event = getEvent("MCPInputReceived")
	local info = {
		UserInputType = button,
		Position = Vector3.new(data.mouseX or 0, data.mouseY or 0, 0)
	}

	if data.action == "tap" then
		info.UserInputState = Enum.UserInputState.Begin
		event:Fire(info)
		task.wait(0.05)
		info.UserInputState = Enum.UserInputState.End
		event:Fire(info)
	else
		info.UserInputState = data.action == "begin"
			and Enum.UserInputState.Begin
			or Enum.UserInputState.End
		event:Fire(info)
	end

	print("[MCPInput] Mouse:", data.key, data.action)
end

-- Handle GUI click commands
local function handleGuiClick(data)
	local element = findGui(data.path)
	if not element then
		warn("[MCPInput] GUI not found:", data.path)
		return
	end

	local event = getEvent("MCPGuiClicked")
	event:Fire({
		element = element,
		path = data.path,
		absolutePosition = element.AbsolutePosition,
		absoluteSize = element.AbsoluteSize,
	})

	print("[MCPInput] GUI clicked:", data.path)
end

-- Listen for commands from server
local inputCommand = ReplicatedStorage:WaitForChild("MCPInputCommand", 10)
if inputCommand then
	inputCommand.OnClientEvent:Connect(function(command)
		local data = command.data
		if command.command_type == "input" then
			if data.inputType == "keyboard" then
				handleKeyboard(data)
			elseif data.inputType == "mouse" then
				handleMouse(data)
			end
		elseif command.command_type == "gui_click" then
			handleGuiClick(data)
		end
	end)
	print("[MCPInput] Client handler ready!")
else
	warn("[MCPInput] Failed to find MCPInputCommand - is MCPInputPoller running?")
end
]]


--============================================================================
-- SCRIPT 3: MCPMovementController (OPTIONAL)
-- Location: StarterPlayerScripts
-- Type: LocalScript
--
-- Add this script to enable WASD movement and Space jumping via MCP.
-- Without this, simulate_input with W/A/S/D won't move your character.
--============================================================================
--[[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

-- Track which movement keys are currently held down
local MovementKeys = {
	[Enum.KeyCode.W] = false,
	[Enum.KeyCode.A] = false,
	[Enum.KeyCode.S] = false,
	[Enum.KeyCode.D] = false,
	[Enum.KeyCode.Space] = false,
}

-- Get the MCPInputReceived event (created by MCPInputHandler)
local MCPInputReceived = ReplicatedStorage:WaitForChild("MCPInputReceived", 5)
if not MCPInputReceived then
	warn("[MCPMovement] MCPInputReceived not found - is MCPInputHandler running?")
	return
end

-- Listen for MCP input events
MCPInputReceived.Event:Connect(function(inputData)
	local keyCode = inputData.KeyCode

	-- Only handle movement keys
	if MovementKeys[keyCode] == nil then return end

	if inputData.UserInputState == Enum.UserInputState.Begin then
		MovementKeys[keyCode] = true

		-- Jump immediately when Space is pressed
		if keyCode == Enum.KeyCode.Space then
			local character = Player.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid")
				if humanoid then
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					print("[MCPMovement] Jump!")
				end
			end
		else
			print("[MCPMovement] Key down:", keyCode.Name)
		end
	elseif inputData.UserInputState == Enum.UserInputState.End then
		MovementKeys[keyCode] = false
		print("[MCPMovement] Key up:", keyCode.Name)
	end
end)

-- Convert pressed keys to movement direction
local function getMovementDirection()
	local direction = Vector3.zero

	if MovementKeys[Enum.KeyCode.W] then
		direction = direction + Vector3.new(0, 0, -1)  -- Forward
	end
	if MovementKeys[Enum.KeyCode.S] then
		direction = direction + Vector3.new(0, 0, 1)   -- Backward
	end
	if MovementKeys[Enum.KeyCode.A] then
		direction = direction + Vector3.new(-1, 0, 0)  -- Left
	end
	if MovementKeys[Enum.KeyCode.D] then
		direction = direction + Vector3.new(1, 0, 0)   -- Right
	end

	-- Normalize for diagonal movement
	if direction.Magnitude > 0 then
		direction = direction.Unit
	end

	return direction
end

-- Apply movement every frame
RunService.Heartbeat:Connect(function()
	local character = Player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local moveDir = getMovementDirection()

	if moveDir.Magnitude > 0 then
		-- Convert to camera-relative direction
		local camera = workspace.CurrentCamera
		if camera then
			local worldDir = camera.CFrame:VectorToWorldSpace(moveDir)
			worldDir = Vector3.new(worldDir.X, 0, worldDir.Z)  -- Keep horizontal
			if worldDir.Magnitude > 0 then
				humanoid:Move(worldDir.Unit, false)
			end
		else
			humanoid:Move(moveDir, false)
		end
	end
end)

print("[MCPMovement] WASD + Space movement enabled!")
]]


--============================================================================
-- SCRIPT 4: ABILITY INTEGRATION (OPTIONAL)
-- Location: Your existing ability script
-- Type: Add this code to your existing LocalScript
--
-- This shows how to make your game's abilities respond to MCP input.
-- Modify this to match your game's ability system.
--============================================================================
--[[
-- Add this to the BOTTOM of your existing AbilityController or similar script

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Define which keys trigger which abilities (customize for your game)
local AbilityKeys = {
	[Enum.KeyCode.Q] = "Ability1",  -- e.g., Dimension Shift
	[Enum.KeyCode.E] = "Ability2",  -- e.g., Dash
	[Enum.KeyCode.R] = "Ability3",  -- e.g., Shield
	[Enum.KeyCode.F] = "Ability4",  -- e.g., Ultimate
}

-- Map ability names to your existing handler functions
-- These functions should already exist in your ability script
local AbilityHandlers = {
	Ability1 = function()
		-- Call your existing ability function
		-- Example: useDimensionShift()
	end,
	Ability2 = function()
		-- Example: useVoidDash()
	end,
	Ability3 = function()
		-- Example: useEtherealShield()
	end,
	Ability4 = function()
		-- Example: useFluxBurst()
	end,
}

-- Listen for MCP input
local MCPInputReceived = ReplicatedStorage:WaitForChild("MCPInputReceived", 5)
if MCPInputReceived then
	MCPInputReceived.Event:Connect(function(inputData)
		-- Only trigger on key press (not release)
		if inputData.UserInputState ~= Enum.UserInputState.Begin then
			return
		end

		local abilityName = AbilityKeys[inputData.KeyCode]
		if not abilityName then return end

		local handler = AbilityHandlers[abilityName]
		if handler then
			-- Add your cooldown check here if needed
			-- Example: if not isOnCooldown(abilityName) then
			print("[Abilities] MCP triggered:", abilityName)
			handler()
		end
	end)

	print("[Abilities] MCP input integration enabled!")
end
]]


--============================================================================
-- USAGE EXAMPLES
--============================================================================
--[[
After adding these scripts to your game, you can control it via MCP:

-- Move character forward
simulate_input({ input_type = "keyboard", key = "W", action = "begin" })
task.wait(2)  -- Move for 2 seconds
simulate_input({ input_type = "keyboard", key = "W", action = "end" })

-- Jump
simulate_input({ input_type = "keyboard", key = "Space", action = "tap" })

-- Use ability (tap = quick press and release)
simulate_input({ input_type = "keyboard", key = "E", action = "tap" })

-- Click a GUI button
click_gui({ path = "MainMenu.PlayButton" })

-- Dismiss a welcome screen
click_gui({ path = "WelcomeUI.DismissButton" })

-- Move diagonally (forward + right)
simulate_input({ input_type = "keyboard", key = "W", action = "begin" })
simulate_input({ input_type = "keyboard", key = "D", action = "begin" })
task.wait(1)
simulate_input({ input_type = "keyboard", key = "W", action = "end" })
simulate_input({ input_type = "keyboard", key = "D", action = "end" })
]]


--============================================================================
-- TROUBLESHOOTING
--============================================================================
--[[
Problem: Commands not received
  - Check: Is HttpService enabled? (Game Settings > Security)
  - Check: Is MCPInputPoller in ServerScriptService?
  - Check: Output should show "[MCPPoller] Started - polling..."

Problem: "[MCPPoller] Got 1 commands!" but nothing happens
  - Check: Is MCPInputHandler in StarterPlayerScripts?
  - Check: Output should show "[MCPInput] Client handler ready!"

Problem: WASD doesn't move character
  - Check: Did you add MCPMovementController?
  - Check: Output should show "[MCPMovement] Key down: W"

Problem: Abilities don't trigger
  - Check: Did you add ability integration to your ability script?
  - Check: Are your AbilityKeys mapped correctly?

Problem: GUI clicks don't work
  - Check: Is the path correct? Use full path from ScreenGui
  - Example: "MyScreenGui.Frame.Button" not just "Button"
]]
