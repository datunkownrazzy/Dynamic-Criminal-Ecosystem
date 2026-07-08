-- DCE Control Center v2 - Location Provider Interface
-- All location providers must implement this interface

local ILocationProvider = {}

--- Initialize the provider
--- Called on resource start
---@return boolean success
function ILocationProvider.Initialize()
    error("ILocationProvider:Initialize must be implemented by provider")
end

--- Shutdown the provider
--- Called on resource stop
function ILocationProvider.Shutdown()
    error("ILocationProvider:Shutdown must be implemented by provider")
end

--- Check if provider supports location type
---@param locationType string
---@return boolean
function ILocationProvider.Supports(locationType)
    error("ILocationProvider:Supports must be implemented by provider")
end

--- Create a location
---@param location table Location data
---@return table|nil result, string|nil error
function ILocationProvider.Create(location)
    error("ILocationProvider:Create must be implemented by provider")
end

--- Delete a location
---@param locationId string
---@return boolean success
function ILocationProvider.Delete(locationId)
    error("ILocationProvider:Delete must be implemented by provider")
end

--- Update a location
---@param locationId string
---@param location table Updated location data
---@return table|nil result, string|nil error
function ILocationProvider.Update(locationId, location)
    error("ILocationProvider:Update must be implemented by provider")
end

--- Validate location data
---@param location table
---@return boolean valid, table errors
function ILocationProvider.Validate(location)
    error("ILocationProvider:Validate must be implemented by provider")
end

--- Preview location (for editor)
---@param location table
---@return table previewData
function ILocationProvider.Preview(location)
    error("ILocationProvider:Preview must be implemented by provider")
end

--- Teleport player to location
---@param source number Player source
---@param location table
---@return boolean success
function ILocationProvider.Teleport(source, location)
    error("ILocationProvider:Teleport must be implemented by provider")
end

--- Serialize location to storage format
---@param location table
---@return table serialized
function ILocationProvider.Serialize(location)
    return location -- Default: pass through
end

--- Deserialize location from storage
---@param serialized table
---@return table location
function ILocationProvider.Deserialize(serialized)
    return serialized -- Default: pass through
end

--- Export location data
---@param location table
---@return table exported
function ILocationProvider.Export(location)
    return location
end

--- Import location data
---@param exported table
---@return table location
function ILocationProvider.Import(exported)
    return exported
end

--- Test provider connectivity/configuration
---@return boolean healthy, string|nil error
function ILocationProvider.Test()
    return true
end

--- Get provider name
---@return string
function ILocationProvider.GetName()
    return "unknown"
end

--- Get supported location types
---@return table
function ILocationProvider.GetSupportedTypes()
    return {}
end

return ILocationProvider