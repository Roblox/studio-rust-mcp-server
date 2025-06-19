-- GetTeams.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local TeamsService = ToolHelpers.GetTeamsService()

local function execute(args: Types.GetTeamsArgs)
    -- This tool does not currently take any specific arguments from the 'args' table.
    local success, pcall_result = pcall(function()
        if not TeamsService then
            return ToolHelpers.FormatErrorResult("TeamsService not available.")
        end

        local teams = TeamsService:GetTeams()
        local teamsData = {}

        for _, team in ipairs(teams) do
            table.insert(teamsData, {
                name = team.Name,
                path = team:GetFullName(),
                team_color_brickcolor_string = team.TeamColor.Name, -- More standard way to represent BrickColor as string
                team_color_rgb = {R=team.TeamColor.Color.R, G=team.TeamColor.Color.G, B=team.TeamColor.Color.B},
                auto_assignable = team.AutoAssignable,
                player_count = #team:GetPlayers() -- Added player count
            })
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Retrieved %d teams."):format(#teamsData),
            team_count = #teamsData,
            teams = teamsData
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in GetTeams: " .. tostring(pcall_result))
    end
end

return execute
