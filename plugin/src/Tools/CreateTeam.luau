-- CreateTeam.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local TeamsService = game:GetService("Teams")

local function execute(args: Types.CreateTeamArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local teamName = args.team_name
        local teamColorBrickColorString = args.team_color_brickcolor_string
        local autoAssignable = if args.auto_assignable == nil then true else args.auto_assignable

        if not teamName or type(teamName) ~= "string" then
            return "'team_name' is required and must be a string."
        end
        if not teamColorBrickColorString or type(teamColorBrickColorString) ~= "string" then
            return "'team_color_brickcolor_string' is required (e.g., 'Bright red')."
        end
        if type(autoAssignable) ~= "boolean" then
            return ("'auto_assignable' must be a boolean, got %s"):format(typeof(autoAssignable))
        end

        if TeamsService:FindFirstChild(teamName) then
            return ("Team '%s' already exists."):format(teamName)
        end

        local teamColor = BrickColor.new(teamColorBrickColorString)
        -- BrickColor.new() defaults to white for invalid strings.

        local newTeam = Instance.new("Team")
        newTeam.Name = teamName
        newTeam.TeamColor = teamColor
        newTeam.AutoAssignable = autoAssignable
        newTeam.Parent = TeamsService

        local resultData: Types.CreateTeamResultData = {
            message = ("Successfully created team '%s'."):format(teamName),
            team_name = newTeam.Name,
            team_color = tostring(newTeam.TeamColor),
            auto_assignable = newTeam.AutoAssignable,
            team_path = newTeam:GetFullName(),
        }
        return resultData
    end)

    if success then
        if type(resultOrError) == "string" then
            return ToolHelpers.FormatErrorResult(resultOrError)
        else
            return ToolHelpers.FormatSuccessResult(resultOrError)
        end
    else
        return ToolHelpers.FormatErrorResult("Internal error in CreateTeam: " .. tostring(resultOrError))
    end
end

return execute
