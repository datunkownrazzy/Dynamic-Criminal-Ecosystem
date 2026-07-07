-- DCE Location Model
-- Represents a physical location in the world
-- Supports: vanilla interiors, walk-in MLOs, instanced interiors, hybrid locations

--- Location interface definition
---@class Location
---@field id string Unique location identifier
---@field name string Display name
---@field provider string Provider type (vanilla, walkin-mlo, instanced, hybrid)
---@field type string Location type (business, safehouse, crime_scene, etc.)
---@field coordinates vector3|table Exterior coordinates {x, y, z}
---@field heading number Heading angle
---@field interiorId number|nil Interior ID for native interiors
---@field routingBucket number|nil Bucket for instanced locations
---@field instanceId string|nil Instance identifier
---@field metadata table|nil Additional location data
---@field exits table|nil Exit points for chained locations
---@field entryZones table|nil Entry trigger zones
---@field exitZones table|nil Exit trigger zones

local Location = {}

--- Create a location definition
---@param def table Location definition
---@return table|nil Location object or nil if invalid definition
function Location.New(def)
    if not def or type(def) ~= "table" then
        return nil
    end
    
    return {
        id = def.id or ("location_" .. tostring(os.time())),
        name = def.name or "Unnamed Location",
        provider = def.provider or "vanilla",
        type = def.type or "generic",
        coordinates = def.coordinates or def.pos or { x = 0, y = 0, z = 0 },
        heading = def.heading or 0.0,
        interiorId = def.interiorId,
        routingBucket = def.routingBucket,
        instanceId = def.instanceId,
        metadata = def.metadata or {},
        exits = def.exits or {},
        entryZones = def.entryZones or {},
        exitZones = def.exitZones or {},
        createdAt = os.time(),
        createdBy = def.createdBy or "system",
    }
end

--- Check if location is valid
---@param loc table Location object
---@return boolean
function Location.IsValid(loc)
    return loc ~= nil 
        and type(loc.id) == "string"
        and type(loc.name) == "string"
        and type(loc.provider) == "string"
end

--- Get location coordinates as vector3 compatible table
---@param loc table Location object
---@return table {x, y, z}
function Location.GetCoords(loc)
    if type(loc.coordinates) == "table" then
        return loc.coordinates
    end
    return { x = loc.coordinates.x, y = loc.coordinates.y, z = loc.coordinates.z }
end

return Location