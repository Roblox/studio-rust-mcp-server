-- CreateTeam.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local TeamsService = game:GetService("Teams")

local function execute(args)
    local success, result = pcall(function()
        local teamName = args.team_name
        local teamColorBrickColorString = args.team_color_brickcolor_string
        local autoAssignable = args.auto_assignable == nil and true or args.auto_assignable -- Default true if nil

        if not teamName or type(teamName) ~= "string" then
            return ToolHelpers.FormatErrorResult("'team_name' is required and must be a string.")
        end
        if not teamColorBrickColorString or type(teamColorBrickColorString) ~= "string" then
            return ToolHelpers.FormatErrorResult("'team_color_brickcolor_string' is required and must be a string (e.g., 'Bright red').")
        end
        if type(autoAssignable) ~= "boolean" then
            return ToolHelpers.FormatErrorResult("'auto_assignable' must be a boolean if provided.")
        end

        -- Check if team already exists
        if TeamsService:FindFirstChild(teamName) then
            return ToolHelpers.FormatErrorResult(("Team '%s' already exists."):format(teamName))
        end

        local teamColor = BrickColor.new(teamColorBrickColorString)
        if not teamColor then
             return ToolHelpers.FormatErrorResult(("Invalid BrickColor string: '%s'."):format(teamColorBrickColorString))
        end

        local newTeam = Instance.new("Team")
        newTeam.Name = teamName
        newTeam.TeamColor = teamColor
        newTeam.AutoAssignable = autoAssignable
        newTeam.Parent = TeamsService

        return ToolHelpers.FormatSuccessResult({
            message = ("Successfully created team '%s'."):format(teamName),
            team_name = newTeam.Name,
            team_color = tostring(newTeam.TeamColor),
            auto_assignable = newTeam.AutoAssignable,
            team_path = newTeam:GetFullName()
        })
    end)

    if success then
        return result
    else
        return ToolHelpers.FormatErrorResult("Internal error in CreateTeam: " .. tostring(result))
    end
end

return execute
