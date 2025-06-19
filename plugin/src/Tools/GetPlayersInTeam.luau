-- GetPlayersInTeam.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local Types = require(script.Parent.Parent.Types)
local TeamsService = ToolHelpers.GetTeamsService()

local function execute(args: Types.GetPlayersInTeamArgs)
    local success, pcall_result = pcall(function()
        local teamPathOrName = args.team_path_or_name

        if not teamPathOrName or type(teamPathOrName) ~= "string" or teamPathOrName == "" then
            return ToolHelpers.FormatErrorResult("'team_path_or_name' is required and must be a non-empty string.")
        end

        if not TeamsService then
            return ToolHelpers.FormatErrorResult("TeamsService not available.")
        end

        local teamInstance = nil
        if string.find(teamPathOrName, "%.") then -- Likely a path
            local found, err = ToolHelpers.FindInstanceByPath(teamPathOrName)
            if found and found:IsA("Team") then
                teamInstance = found
            else
                 return ToolHelpers.FormatErrorResult(("Team not found or invalid at path: %s. %s"):format(teamPathOrName, err or ""))
            end
        else -- Assume it's a name
            teamInstance = TeamsService:FindFirstChild(teamPathOrName)
            if not teamInstance or not teamInstance:IsA("Team") then
                return ToolHelpers.FormatErrorResult(("Team with name '%s' not found."):format(teamPathOrName))
            end
        end

        if not teamInstance then
             return ToolHelpers.FormatErrorResult(("Could not find team: %s"):format(teamPathOrName))
        end

        local playersInTeam = teamInstance:GetPlayers()
        local playersData = {}

        for _, player in ipairs(playersInTeam) do
            table.insert(playersData, {
                name = player.Name,
                path = player:GetFullName(),
                user_id = player.UserId
            })
        end

        return ToolHelpers.FormatSuccessResult({
            message = ("Found %d player(s) in team '%s'."):format(#playersData, teamInstance.Name),
            team_name = teamInstance.Name,
            team_path = teamInstance:GetFullName(),
            players = playersData
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in GetPlayersInTeam: " .. tostring(pcall_result))
    end
end

return execute
