-- DCE Control Center v2 - Location Manager Service
-- Central service for all location management with provider abstraction

local LocationManager = {}
local DCE = _G.DCE
local logger

-- Location storage
local locations = {}
local territories = {}
local locationCache = {}

-- Provider registry
local providers = {}

--- Initialize the service
function LocationManager.Init(log)
    logger = log
    if logger then
        logger.Info("location-manager", "Initializing Location Manager...")
    end
end

--- Log helper
local function log(level, msg, ...)
    if logger then
        logger.Log("location-manager", level, msg, ...)
    end
end

--- Register a location provider
---@param providerId string
---@param provider table Provider module implementing ILocationProvider
---@return boolean
function LocationManager.RegisterProvider(providerId, provider)
    if not provider or type(provider) ~= "table" then
        log("error", "Invalid provider: %s", providerId)
        return false
    end
    
    -- Verify required interface methods
    local required = { "Initialize", "Supports", "Create", "Delete", "Update", "Validate" }
    for _, method in ipairs(required) do
        if type(provider[method]) ~= "function" then
            log("error", "Provider %s missing required method: %s", providerId, method)
            return false
        end
    end
    
    providers[providerId] = provider
    log("info", "Registered location provider: %s", providerId)
    return true
end

--- Get provider for a location type
---@param locationType string
---@return table|nil
function LocationManager.GetProviderForType(locationType)
    for providerId, provider in pairs(providers) do
        if provider.Supports and provider.Supports(locationType) then
            return provider
        end
    end
    return nil
end

--- Create a location
---@param locationData table
---@return boolean, string|nil
function LocationManager.CreateLocation(locationData)
    if not locationData or not locationData.type then
        return false, "Location type required"
    end
    
    if not locationData.id then
        return false, "Location ID required"
    end
    
    -- Get appropriate provider
    local provider = LocationManager.GetProviderForType(locationData.type)
    if not provider then
        return false, "No provider for type: " .. locationData.type
    end
    
    -- Validate
    local valid, errors = provider.Validate(locationData)
    if not valid then
        return false, errors and table.concat(errors, ", ") or "Validation failed"
    end
    
    -- Let provider create
    local result, err = provider.Create(locationData)
    if not result then
        return false, err or "Provider create failed"
    end
    
    -- Store location
    locations[locationData.id] = result
    
    -- Emit event
    if DCE and DCE.Emit then
        DCE.Emit("location:created", {
            locationId = locationData.id,
            location = result,
        })
    end
    
    log("info", "Created location: %s (type: %s)", locationData.id, locationData.type)
    return true
end

--- Get a location
---@param locationId string
---@return table|nil
function LocationManager.GetLocation(locationId)
    if locationCache[locationId] then
        return locationCache[locationId]
    end
    
    local location = locations[locationId]
    if location then
        locationCache[locationId] = location
    end
    
    return location
end

--- Update a location
---@param locationId string
---@param locationData table
---@return boolean, string|nil
function LocationManager.UpdateLocation(locationId, locationData)
    if not locations[locationId] then
        return false, "Location not found: " .. locationId
    end
    
    local location = locations[locationId]
    local provider = LocationManager.GetProviderForType(location.type)
    
    if provider and provider.Validate then
        local valid, errors = provider.Validate(locationData)
        if not valid then
            return false, errors and table.concat(errors, ", ") or "Validation failed"
        end
    end
    
    -- Merge updates
    for k, v in pairs(locationData) do
        location[k] = v
    end
    
    -- Clear cache
    locationCache[locationId] = nil
    
    -- Emit event
    if DCE and DCE.Emit then
        DCE.Emit("location:updated", {
            locationId = locationId,
            location = location,
        })
    end
    
    log("info", "Updated location: %s", locationId)
    return true
end

--- Delete a location
---@param locationId string
---@return boolean
function LocationManager.DeleteLocation(locationId)
    local location = locations[locationId]
    if not location then
        return false
    end
    
    local provider = LocationManager.GetProviderForType(location.type)
    if provider and provider.Delete then
        provider.Delete(locationId)
    end
    
    locations[locationId] = nil
    locationCache[locationId] = nil
    
    -- Emit event
    if DCE and DCE.Emit then
        DCE.Emit("location:deleted", { locationId = locationId })
    end
    
    log("info", "Deleted location: %s", locationId)
    return true
end

--- List all locations
---@return table
function LocationManager.ListLocations()
    local result = {}
    for id, loc in pairs(locations) do
        table.insert(result, loc)
    end
    return result
end

--- List locations by type
---@param locationType string
---@return table
function LocationManager.ListLocationsByType(locationType)
    local result = {}
    for id, loc in pairs(locations) do
        if loc.type == locationType then
            table.insert(result, loc)
        end
    end
    return result
end

--- Create a territory
---@param territoryData table
---@return boolean, string|nil
function LocationManager.CreateTerritory(territoryData)
    if not territoryData.id then
        return false, "Territory ID required"
    end
    
    territoryData.type = "territory"
    territories[territoryData.id] = territoryData
    
    if DCE and DCE.Emit then
        DCE.Emit("territory:created", { territoryId = territoryData.id })
    end
    
    return true
end

--- List all territories
---@return table
function LocationManager.ListTerritories()
    local result = {}
    for id, territory in pairs(territories) do
        table.insert(result, territory)
    end
    return result
end

--- Resolve location for player (teleport/enter)
---@param source number
---@param locationId string
---@return table|nil resolution
function LocationManager.ResolveLocation(source, locationId)
    local location = LocationManager.GetLocation(locationId)
    if not location then
        return nil
    end
    
    local provider = LocationManager.GetProviderForType(location.type)
    if provider and provider.ResolveLocation then
        return provider.ResolveLocation(location, source)
    end
    
    return { coords = location.coords, heading = location.heading }
end

--- Shutdown
function LocationManager.Shutdown()
    -- Shutdown all providers
    for id, provider in pairs(providers) do
        if provider.Shutdown then
            provider.Shutdown()
        end
    end
    
    providers = {}
    locations = {}
    territories = {}
    locationCache = {}
    
    log("info", "Location Manager shut down")
end

return LocationManager