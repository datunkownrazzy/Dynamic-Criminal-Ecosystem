-- DCE Location Manager Service
-- Provider-based location management system
-- Single source of truth for all physical locations in DCE

local LocationManager = {}
local locations = {}         -- id -> Location object
local providers = {}         -- providerName -> provider module
local logger

--- Initialize the location manager
function LocationManager.Init(log)
    logger = log
    _G.DCELocationManager = LocationManager
end

--- Log helper
local function log(level, msg, ...)
    if logger then
        logger.Log("location-manager", level, msg, ...)
    end
end

--- Register a location provider
--- Providers handle location resolution for specific types (vanilla, walkin-mlo, instanced, hybrid)
---@param providerName string Provider identifier
---@param providerModule table Provider module with GetLocation, ListLocations methods
---@return boolean success
function LocationManager.RegisterProvider(providerName, providerModule)
    if not providerName or type(providerName) ~= "string" then
        log("error", "Provider name must be a string")
        return false
    end
    
    if not providerModule or type(providerModule) ~= "table" then
        log("error", "Provider module must be a table for '%s'", providerName)
        return false
    end
    
    providers[providerName] = providerModule
    log("info", "Registered location provider: %s", providerName)
    return true
end

--- Get a location by ID
--- Queries all registered providers until one returns the location
---@param locationId string
---@return table|nil Location object
function LocationManager.GetLocation(locationId)
    -- Check cache first
    if locations[locationId] then
        return locations[locationId]
    end
    
    -- Query providers
    for providerName, provider in pairs(providers) do
        local result = provider.GetLocation and provider.GetLocation(locationId)
        if result then
            locations[locationId] = result
            return result
        end
    end
    
    return nil
end

--- Register a location directly (bypasses providers)
--- Used for runtime-created locations
---@param location table Location object
---@return boolean success
function LocationManager.RegisterLocation(location)
    if not location or not location.id then
        log("error", "Location must have an id")
        return false
    end
    
    locations[location.id] = location
    log("info", "Registered location: %s", location.id)
    return true
end

--- Get all locations of a specific type
---@param locationType string|nil Optional type filter
---@return table Array of locations
function LocationManager.ListLocations(locationType)
    local result = {}
    
    for _, loc in pairs(locations) do
        if not locationType or loc.type == locationType then
            table.insert(result, loc)
        end
    end
    
    -- Also query providers for their locations
    for providerName, provider in pairs(providers) do
        if provider.ListLocations then
            local providerLocs = provider.ListLocations(locationType)
            for _, loc in ipairs(providerLocs) do
                -- Don't duplicate cached locations
                if not locations[loc.id] then
                    table.insert(result, loc)
                end
            end
        end
    end
    
    return result
end

--- Get locations for an organization
---@param orgId string Organization ID
---@return table Array of locations owned by the organization
function LocationManager.GetOrganizationLocations(orgId)
    local result = {}
    
    for _, loc in pairs(locations) do
        if loc.metadata and loc.metadata.orgId == orgId then
            table.insert(result, loc)
        end
    end
    
    return result
end

--- Resolve location coordinates (handles instanced/hybrid)
---@param locationId string
---@param playerSource number|nil Player source for instance resolution
---@return table|nil Resolved coordinates and routing info
function LocationManager.ResolveLocation(locationId, playerSource)
    local loc = LocationManager.GetLocation(locationId)
    if not loc then
        return nil
    end
    
    -- Check if this location uses a specific provider for resolution
    if loc.provider and providers[loc.provider] then
        if providers[loc.provider].ResolveLocation then
            return providers[loc.provider].ResolveLocation(loc, playerSource)
        end
    end
    
    -- Default resolution
    return {
        coords = loc.coordinates,
        heading = loc.heading,
        routingBucket = loc.routingBucket,
        instanceId = loc.instanceId,
    }
end

--- Get all registered providers
---@return table Provider names
function LocationManager.ListProviders()
    local names = {}
    for name, _ in pairs(providers) do
        table.insert(names, name)
    end
    return names
end

--- Clear all cached locations (for testing/reload)
--- Called on resource shutdown
function LocationManager.Clear()
    locations = {}
    log("info", "Location cache cleared")
end

--- Query for territories managed by this location manager
---@return table Array of territory objects
function LocationManager.ListTerritories()
    -- Territories are stored as locations with type "territory"
    return LocationManager.ListLocations("territory")
end

--- Get all locations (alias for ListLocations)
---@return table Array of all locations
function LocationManager.GetAllLocations()
    return LocationManager.ListLocations()
end

--- Get all territories (alias for ListTerritories)
---@return table Array of all territories
function LocationManager.GetAllTerritories()
    return LocationManager.ListTerritories()
end

--- Create a new location
---@param locationData table Location data
---@return boolean success, string|nil error
function LocationManager.CreateLocation(locationData)
    if not locationData or not locationData.id then
        return false, "Location must have an id"
    end
    
    if locations[locationData.id] then
        return false, "Location already exists"
    end
    
    locations[locationData.id] = locationData
    locations[locationData.id].active = locationData.active ~= false
    
    -- Emit event for real-time update
    if DCE and DCE.Emit then
        DCE.Emit("location:created", {
            eventName = "location:created",
            eventVersion = 1,
            timestamp = os.time(),
            source = "location-manager",
            payload = locationData,
        })
    end
    
    log("info", "Created location: %s", locationData.id)
    return true
end

--- Update an existing location
---@param id string Location ID
---@param locationData table Updated location data
---@return boolean success, string|nil error
function LocationManager.UpdateLocation(id, locationData)
    if not locations[id] then
        return false, "Location not found"
    end
    
    -- Merge updates
    for key, value in pairs(locationData) do
        locations[id][key] = value
    end
    
    -- Build payload for event
    local payload = { id = id }
    for key, value in pairs(locationData) do
        payload[key] = value
    end
    
    -- Emit event
    if DCE and DCE.Emit then
        DCE.Emit("location:updated", {
            eventName = "location:updated",
            eventVersion = 1,
            timestamp = os.time(),
            source = "location-manager",
            payload = payload,
        })
    end
    
    log("info", "Updated location: %s", id)
    return true
end

--- Delete a location
---@param id string Location ID
---@return boolean success
function LocationManager.DeleteLocation(id)
    if not locations[id] then
        return false
    end
    
    locations[id] = nil
    
    -- Emit event
    if DCE and DCE.Emit then
        DCE.Emit("location:deleted", {
            eventName = "location:deleted",
            eventVersion = 1,
            timestamp = os.time(),
            source = "location-manager",
            payload = { id = id },
        })
    end
    
    log("info", "Deleted location: %s", id)
    return true
end

--- Create a new territory
---@param territoryData table Territory data
---@return boolean success, string|nil error
function LocationManager.CreateTerritory(territoryData)
    if not territoryData or not territoryData.id then
        return false, "Territory must have an id"
    end
    
    territoryData.type = "territory"
    return LocationManager.CreateLocation(territoryData)
end

--- Update a territory
---@param id string Territory ID
---@param territoryData table Updated territory data
---@return boolean success, string|nil error
function LocationManager.UpdateTerritory(id, territoryData)
    territoryData.type = "territory"
    return LocationManager.UpdateLocation(id, territoryData)
end

--- Delete a territory
---@param id string Territory ID
---@return boolean success
function LocationManager.DeleteTerritory(id)
    return LocationManager.DeleteLocation(id)
end

--- Shutdown the location manager
--- Called during resource stop for cleanup
function LocationManager.Shutdown()
    LocationManager.Clear()
    providers = {}
    log("info", "Location Manager shutdown complete")
end

return LocationManager
