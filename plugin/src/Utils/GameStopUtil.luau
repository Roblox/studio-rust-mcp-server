local Main = script:FindFirstAncestor("MCPStudioPlugin")
local PluginUtils = require(Main.Utils.PluginUtils)
local StudioTestService = game:GetService("StudioTestService")

local MCP_STOP_PLAY_MESSAGE_KEY = "MCP_STOP_PLAY_MESSAGE"

local function stopPlay()
	PluginUtils.setSettings(MCP_STOP_PLAY_MESSAGE_KEY, true)
end

local function monitorForStopPlay()
	while true do
		if PluginUtils.getSettings(MCP_STOP_PLAY_MESSAGE_KEY) then
			PluginUtils.setSettings(MCP_STOP_PLAY_MESSAGE_KEY, false)
			StudioTestService:EndTest({})
		end
		task.wait(1)
	end
end

return { stopPlay = stopPlay, monitorForStopPlay = monitorForStopPlay }
