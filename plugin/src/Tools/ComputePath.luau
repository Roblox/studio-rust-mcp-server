-- ComputePath.luau
local ToolHelpers = require(script.Parent.Parent.ToolHelpers)
local PathfindingService = game:GetService("PathfindingService")

local function execute(args)
    local success, pcall_result = pcall(function()
        local startPosJson = args.start_position
        local endPosJson = args.end_position
        local agentParamsJson = args.agent_parameters -- Optional

        if not startPosJson or type(startPosJson) ~= "table" then
            return ToolHelpers.FormatErrorResult("'start_position' is required and must be a Vector3-like table.")
        end
        if not endPosJson or type(endPosJson) ~= "table" then
            return ToolHelpers.FormatErrorResult("'end_position' is required and must be a Vector3-like table.")
        end
        if agentParamsJson ~= nil and type(agentParamsJson) ~= "table" then
            return ToolHelpers.FormatErrorResult("'agent_parameters' must be a table if provided.")
        end

        local startPos = ToolHelpers.JsonToRobloxValue(startPosJson)
        local endPos = ToolHelpers.JsonToRobloxValue(endPosJson)

        if typeof(startPos) ~= "Vector3" then
            return ToolHelpers.FormatErrorResult("'start_position' did not convert to a Vector3. Ensure format {'x':0,'y':0,'z':0}.")
        end
        if typeof(endPos) ~= "Vector3" then
            return ToolHelpers.FormatErrorResult("'end_position' did not convert to a Vector3. Ensure format {'x':0,'y':0,'z':0}.")
        end

        local agentParameters = {}
        if agentParamsJson then
            -- Convert known agent parameters, allow others if PathfindingService supports them dynamically
            if agentParamsJson.AgentRadius then agentParameters.AgentRadius = agentParamsJson.AgentRadius end
            if agentParamsJson.AgentHeight then agentParameters.AgentHeight = agentParamsJson.AgentHeight end
            if agentParamsJson.AgentCanJump then agentParameters.AgentCanJump = agentParamsJson.AgentCanJump end
            if agentParamsJson.WaypointSpacing then agentParameters.WaypointSpacing = agentParamsJson.WaypointSpacing end
            if agentParamsJson.Costs then -- Costs is a dictionary itself
                agentParameters.Costs = {}
                for materialName, cost in pairs(agentParamsJson.Costs) do
                    local materialEnum = Enum.Material[materialName]
                    if materialEnum then
                        agentParameters.Costs[materialEnum] = cost
                    else
                        print("ComputePath: Unknown material name in Costs: " .. materialName)
                    end
                end
            end
        end

        local path = PathfindingService:CreatePath(agentParameters)
        path:ComputeAsync(startPos, endPos)

        local status = path.Status
        local waypointsJson = {}
        local resultMessage = ""

        if status == Enum.PathStatus.Success then
            resultMessage = "Path computed successfully."
            local waypoints = path:GetWaypoints()
            for _, waypoint in ipairs(waypoints) do
                table.insert(waypointsJson, ToolHelpers.RobloxValueToJson(waypoint.Position)) -- Store position only for simplicity
                -- Could also include waypoint.Action if needed by adding to the table above
            end
        elseif status == Enum.PathStatus.NoPath then
            resultMessage = "No path found between the points."
        elseif status == Enum.PathStatus.ClosestNoPath then
            resultMessage = "No path found, but closest path might be available (not implemented by this tool)."
        elseif status == Enum.PathStatus.ClosestOutOfRange then
             resultMessage = "Closest path is out of range (not implemented by this tool)."
        elseif status == Enum.PathStatus.FailStartNotEmpty then
            resultMessage = "Pathfinding failed: Start point is inside an obstacle."
        elseif status == Enum.PathStatus.FailFinishNotEmpty then
            resultMessage = "Pathfinding failed: End point is inside an obstacle."
        else
            resultMessage = "Pathfinding failed with an unknown status: " .. tostring(status)
        end

        return ToolHelpers.FormatSuccessResult({
            message = resultMessage,
            status = tostring(status),
            start_position_used = ToolHelpers.RobloxValueToJson(startPos),
            end_position_used = ToolHelpers.RobloxValueToJson(endPos),
            waypoints = waypointsJson -- This will be an array of Vector3-like tables
        })
    end)

    if success then
        return pcall_result
    else
        return ToolHelpers.FormatErrorResult("Internal error in ComputePath: " .. tostring(pcall_result))
    end
end

return execute
