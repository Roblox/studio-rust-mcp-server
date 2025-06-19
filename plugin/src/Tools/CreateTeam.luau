-- CreateTeam.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types) -- Added
local TeamsService = ToolHelpers.GetTeamsService()
local HttpService = game:GetService("HttpService") -- Added

local function execute(args: Types.CreateTeamArgs) -- Type annotation added
    local success, resultOrError = pcall(function()
        local teamName = args.team_name
        -- Assuming args.team_color is the field that can be string or table.
        -- If Types.CreateTeamArgs still uses team_color_brickcolor_string, this line should be:
        -- local teamColorInput = args.team_color_brickcolor_string
        local teamColorInput = args.team_color -- Using team_color as per prompt example
        local autoAssignable = if args.auto_assignable == nil then true else args.auto_assignable

        if not teamName or type(teamName) ~= "string" then
            return "'team_name' is required and must be a string."
        end

        -- Validate teamColorInput: must be a non-empty string or a table
        if not ((type(teamColorInput) == "string" and teamColorInput ~= "") or type(teamColorInput) == "table") then
            return "'team_color' is required and must be a non-empty string or a table (e.g., {name='Bright red'}, {number=194}, or {r=1,g=0,b=0})."
        end

        if type(autoAssignable) ~= "boolean" then
            return ("'auto_assignable' must be a boolean, got %s"):format(typeof(autoAssignable))
        end

        if TeamsService:FindFirstChild(teamName) then
            return ("Team '%s' already exists."):format(teamName)
        end

        local teamColorFinal: BrickColor
        local conversionErrorMsg = nil

        if type(teamColorInput) == "table" then
            local convertedBc, convErr = ToolHelpers.ConvertTableToRobloxType(teamColorInput, "TeamColor", nil)
            if convErr then
                conversionErrorMsg = ("Invalid table for team_color: %s. Original: %s"):format(convErr, HttpService:JSONEncode(teamColorInput))
            elseif typeof(convertedBc) == "BrickColor" then
                teamColorFinal = convertedBc
            else
                conversionErrorMsg = ("Table for team_color did not convert to a BrickColor. Got type: %s. Original: %s"):format(typeof(convertedBc), HttpService:JSONEncode(teamColorInput))
            end
        elseif type(teamColorInput) == "string" then
            -- pcall BrickColor.new for safety, though it usually just returns White on invalid string
            local successBc, bcOrErr = pcall(BrickColor.new, teamColorInput)
            if successBc then
                teamColorFinal = bcOrErr
                -- Optional: Add check if color is white for non-white input string if desired
                -- if teamColorFinal == BrickColor.White() and string.lower(teamColorInput) ~= "white" and teamColorInput ~= "Institutional white" then
                --    print(("[CreateTeam] Warning: TeamColor string '%s' resulted in White. Input might be invalid."):format(teamColorInput))
                -- end
            else
                conversionErrorMsg = ("Invalid string for team_color: %s. Error: %s"):format(teamColorInput, tostring(bcOrErr))
            end
        end

        if conversionErrorMsg then
            return conversionErrorMsg -- Return the error string
        end

        -- If teamColorFinal is somehow still nil here, it means an earlier validation was missed.
        -- However, the logic above should ensure an error string is returned if it's not set.
        if not teamColorFinal then
            return "Failed to determine team color from input." -- Should be unreachable if logic above is correct
        end

        local newTeam = Instance.new("Team")
        newTeam.Name = teamName
        newTeam.TeamColor = teamColorFinal
        newTeam.AutoAssignable = autoAssignable
        newTeam.Parent = TeamsService

        local resultData: Types.CreateTeamResultData = {
            message = ("Successfully created team '%s'."):format(teamName),
            team_name = newTeam.Name,
            team_color = tostring(newTeam.TeamColor), -- Report the actual BrickColor string
            auto_assignable = newTeam.AutoAssignable,
            team_path = newTeam:GetFullName(),
        }
        return resultData -- This is a table
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
