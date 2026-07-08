-- DCE Control Center v2 - MLO Location Provider
-- Provider for MLO (Map Location Object) interiors like Gabz, K4MB1

local MLOProvider = {}

--- Get an MLO location by ID
---@param locationId string
---@return table|nil
function MLOProvider.GetLocation(locationId)
    -- MLO locations would be loaded from data files
    return nil
end

--- List all MLO locations
---@return table
function MLOProvider.ListLocations()
    return {}
end

return MLOProvider