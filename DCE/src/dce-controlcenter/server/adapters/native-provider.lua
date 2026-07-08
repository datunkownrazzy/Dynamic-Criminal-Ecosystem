-- DCE Control Center v2 - Native Location Provider
-- Provides access to native GTA interiors and simple teleport locations

local NativeProvider = {}
local DCE = _G.DCE

--- Get a native location by ID
---@param locationId string
---@return table|nil
function NativeProvider.GetLocation(locationId)
    -- Native locations are defined by their coordinates
    -- This would be expanded to include all interior entrances
    return nil
end

--- List all native locations
---@return table
function NativeProvider.ListLocations()
    local locations = {}
    
    -- Built-in locations that come with the system
    -- Example: convenience stores, gas stations, etc.
    
    return locations
end

--- Resolve a native location
---@param location table Location info
---@param playerSource number|nil
---@return table
function NativeProvider.ResolveLocation(location, playerSource)
    return {
        coords = location.coords,
        heading = location.heading or 0,
        routingBucket = nil, -- Native locations don't use buckets
    }
end

return NativeProvider