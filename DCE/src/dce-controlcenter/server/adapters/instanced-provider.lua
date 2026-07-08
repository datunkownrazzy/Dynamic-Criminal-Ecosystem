-- DCE Control Center v2 - Instanced Location Provider
-- Provider for routing bucket instanced interiors

local InstancedProvider = {}

--- Get an instanced location by ID
---@param locationId string
---@return table|nil
function InstancedProvider.GetLocation(locationId)
    -- Instanced locations have routingBucket and instanceId
    return nil
end

--- Resolve instanced location with player-specific bucket
---@param location table
---@param playerSource number
---@return table
function InstancedProvider.ResolveLocation(location, playerSource)
    return {
        coords = location.coords,
        heading = location.heading or 0,
        routingBucket = location.routingBucket or 0,
        instanceId = location.instanceId,
    }
end

return InstancedProvider