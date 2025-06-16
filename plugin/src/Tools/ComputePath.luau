-- ComputePath.luau
local Main = script:FindFirstAncestor("MCPStudioPlugin")
local ToolHelpers = require(Main.ToolHelpers)
local PathfindingService = game:GetService("PathfindingService")

local function execute(args)
    -- Arguments are now expected directly on args table
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
            if agentParamsJson.AgentRadius then agentParameters.AgentRadius = agentParamsJson.AgentRadius end
            if agentParamsJson.AgentHeight then agentParameters.AgentHeight = agentParamsJson.AgentHeight end
            if agentParamsJson.AgentCanJump then agentParameters.AgentCanJump = agentParamsJson.AgentCanJump end
            if agentParamsJson.WaypointSpacing then agentParameters.WaypointSpacing = agentParamsJson.WaypointSpacing end
            if agentParamsJson.Costs then
                agentParameters.Costs = {}
                for materialName, cost in pairs(agentParamsJson.Costs) do
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

        local computeSuccess, computeMessage = pcall(path.ComputeAsync, path, startPos, endPos)
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
            start_position_used = startPos, -- Store Roblox Vector3
            end_position_used = endPos,     -- Store Roblox Vector3
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
