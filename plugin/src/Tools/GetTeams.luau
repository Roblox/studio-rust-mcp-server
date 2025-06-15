-- GetTeams.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local TeamsService = game:GetService("Teams")

local function execute(args)
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
                team_color = tostring(team.TeamColor),
                auto_assignable = team.AutoAssignable,
                -- Add other properties if needed, e.g., number of players
                -- player_count = #team:GetPlayers()
            })
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Retrieved %d teams."):format(#teamsData),
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
