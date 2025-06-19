-- ComputePath.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local Types = require(Main.Types)
local PathfindingService = ToolHelpers.GetPathfindingService()
local HttpService = game:GetService("HttpService") -- Added

local function execute(args: Types.ComputePathArgs)
    -- Arguments are now expected directly on args table
    local success, pcall_result = pcall(function()
        local startPosInput = args.start_position
        local endPosInput = args.end_position
        local agentParamsTable = args.agent_parameters -- Renamed for clarity from agentParamsJson

        local startPosFinal: Vector3
        local endPosFinal: Vector3

        -- Process start_position
        if type(startPosInput) == "table" then
            local converted, err = ToolHelpers.ConvertTableToRobloxType(startPosInput, "start_position", nil)
            if err then
                return ToolHelpers.FormatErrorResult(("Invalid 'start_position' table: %s. Original: %s"):format(err, HttpService:JSONEncode(startPosInput)))
            end
            if typeof(converted) == "Vector3" then
                startPosFinal = converted
            else
                return ToolHelpers.FormatErrorResult(("'start_position' table did not convert to Vector3. Got %s."):format(typeof(converted)))
            end
        elseif typeof(startPosInput) == "Vector3" then
            startPosFinal = startPosInput
        else
            return ToolHelpers.FormatErrorResult(("'start_position' must be a Vector3 or a table convertible to Vector3. Got %s."):format(typeof(startPosInput)))
        end

        -- Process end_position
        if type(endPosInput) == "table" then
            local converted, err = ToolHelpers.ConvertTableToRobloxType(endPosInput, "end_position", nil)
            if err then
                return ToolHelpers.FormatErrorResult(("Invalid 'end_position' table: %s. Original: %s"):format(err, HttpService:JSONEncode(endPosInput)))
            end
            if typeof(converted) == "Vector3" then
                endPosFinal = converted
            else
                return ToolHelpers.FormatErrorResult(("'end_position' table did not convert to Vector3. Got %s."):format(typeof(converted)))
            end
        elseif typeof(endPosInput) == "Vector3" then
            endPosFinal = endPosInput
        else
            return ToolHelpers.FormatErrorResult(("'end_position' must be a Vector3 or a table convertible to Vector3. Got %s."):format(typeof(endPosInput)))
        end

        if agentParamsTable ~= nil and type(agentParamsTable) ~= "table" then
            return ToolHelpers.FormatErrorResult("'agent_parameters' must be a table if provided.")
        end

        local agentParameters = {}
        if agentParamsTable then
            if agentParamsTable.AgentRadius then agentParameters.AgentRadius = agentParamsTable.AgentRadius end
            if agentParamsTable.AgentHeight then agentParameters.AgentHeight = agentParamsTable.AgentHeight end
            if agentParamsTable.AgentCanJump then agentParameters.AgentCanJump = agentParamsTable.AgentCanJump end
            if agentParamsTable.WaypointSpacing then agentParameters.WaypointSpacing = agentParamsTable.WaypointSpacing end
            if agentParamsTable.Costs then
                agentParameters.Costs = {}
                for materialName, cost in pairs(agentParamsTable.Costs) do
                    local materialEnum = Enum.Material[materialName]
                    if materialEnum then
                        agentParameters.Costs[materialEnum] = cost
                    else
                        print("ComputePath: Unknown material name in Costs: " .. materialName .. ". Skipping.")
                    end
                end
            end
        end

        local path = PathfindingService:CreatePath(agentParameters)

        local computeSuccess, computeMessage = pcall(path.ComputeAsync, path, startPosFinal, endPosFinal)
        if not computeSuccess then
            return ToolHelpers.FormatErrorResult("Path:ComputeAsync failed: " .. tostring(computeMessage))
        end

        local status = path.Status
        local waypointsData = {} -- Store Roblox Vector3s directly
        local resultMessage = ""
        local isPathError = false

        if status == Enum.PathStatus.Success then
            resultMessage = "Path computed successfully."
            local waypoints = path:GetWaypoints()
            for _, waypoint in ipairs(waypoints) do
                -- Storing Roblox Vector3s; FormatSuccessResult will handle their conversion via RobloxValueToJson.
                table.insert(waypointsData, waypoint.Position)
            end
        elseif status == Enum.PathStatus.NoPath then
            resultMessage = "No path found between the points."
            isPathError = true
        else
            resultMessage = "Pathfinding failed with status: " .. tostring(status)
            isPathError = true
        end

        local resultPayload = {
            status = tostring(status),
            start_position_used = startPosFinal, -- Store Roblox Vector3
            end_position_used = endPosFinal,     -- Store Roblox Vector3
            -- waypoints will be added by success case
        }

        if isPathError then
            resultPayload.message = resultMessage
            -- No waypoints to add for error cases generally, or they are not valid.
            return ToolHelpers.FormatErrorResult(resultPayload.message, resultPayload)
        end

        resultPayload.message = resultMessage
        resultPayload.waypoints = waypointsData -- Array of Vector3s

        return ToolHelpers.FormatSuccessResult(resultPayload)
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in ComputePath: " .. tostring(pcall_result))
    end
end

return execute
