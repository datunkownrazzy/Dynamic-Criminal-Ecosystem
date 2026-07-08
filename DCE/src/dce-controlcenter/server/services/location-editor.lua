-- DCE Location Editor Service
-- Provides runtime editing capabilities for locations
-- Hot-reload friendly, event-driven updates

local LocationEditor = {}
local DCE = _G.DCE
local logger

-- Undo/redo stack for each player
local editHistory = {}     -- source -> { undoStack = {}, redoStack = {} }

-- Location validation schema
local LOCATION_VALIDATORS = {
    id = {
        required = true,
        type = "string",
        pattern = "^[a-z0-9_%-]+$",
    },
    type = {
        required = true,
        type = "string",
        allowed = {
            "vanilla", "walkin-mlo", "instanced", "hybrid",
            "mlo", "ipl", "teleport", "spawn",
            "business", "safehouse", "druglab", "warehouse",
            "territory", "crimescene", "dispatch", "evidence",
            "mission", "roadblock", "patrol", "gangcorner"
        }
    },
    coords = {
        required = false,
        type = "vector3"
    },
    heading = {
        required = false,
        type = "number",
        min = 0,
        max = 360
    }
}

--- Initialize the service
function LocationEditor.Init(log)
    logger = log
    if logger then
        logger.Info("location-editor", "Initializing Location Editor...")
    end
end

--- Log helper
local function log(level, msg, ...)
    if logger then
        logger.Log("location-editor", level, msg, ...)
    end
end

--- Validate location data
---@param locationData table Location to validate
---@return boolean valid, string|nil error
function LocationEditor.ValidateLocation(locationData)
    if not locationData or type(locationData) ~= "table" then
        return false, "Location data must be a table"
    end
    
    -- Check required fields
    for field, validator in pairs(LOCATION_VALIDATORS) do
        local value = locationData[field]
        
        if validator.required and value == nil then
            return false, field .. " is required"
        end
        
        if value ~= nil then
            if validator.type == "string" and type(value) ~= "string" then
                return false, field .. " must be a string"
            end
            
            if validator.pattern and type(value) == "string" then
                -- Simple pattern check without full regex
                local valid = string.match(value, "^[a-z0-9_%-]+$") ~= nil
                if not valid then
                    return false, field .. " contains invalid characters"
                end
            end
            
            if validator.allowed and type(value) == "string" then
                local found = false
                for _, allowed in ipairs(validator.allowed) do
                    if value == allowed then
                        found = true
                        break
                    end
                end
                if not found then
                    return false, field .. " must be one of: " .. table.concat(validator.allowed, ", ")
                end
            end
            
            if validator.type == "vector3" then
                if type(value) ~= "vector3" and type(value) ~= "table" then
                    return false, field .. " must be coordinates (vector3 or table)"
                end
            end
            
            if validator.type == "number" then
                if type(value) ~= "number" then
                    return false, field .. " must be a number"
                end
                if validator.min and value < validator.min then
                    return false, field .. " must be >= " .. validator.min
                end
                if validator.max and value > validator.max then
                    return false, field .. " must be <= " .. validator.max
                end
            end
        end
    end
    
    return true
end

--- Create a location (with undo support)
---@param source number Player source
---@param locationData table Location data
---@return table result
function LocationEditor.CreateLocation(source, locationData)
    -- Validate first
    local valid, err = LocationEditor.ValidateLocation(locationData)
    if not valid then
        return { success = false, error = err }
    end
    
    -- Get LocationManager service
    local LocationManager = DCE and DCE.GetService and DCE.GetService("LocationManager")
    
    if not LocationManager then
        return { success = false, error = "LocationManager service not available" }
    end
    
    -- Create the location
    local success, err = LocationManager.CreateLocation(locationData)
    
    if success then
        -- Add to undo history
        LocationEditor.PushUndoAction(source, {
            action = "delete",
            locationId = locationData.id,
        })
        
        log("info", "Location created by player %d: %s", source, locationData.id)
    end
    
    return { success = success, error = err }
end

--- Update a location (with undo support)
---@param source number Player source
---@param locationId string Location ID
---@param locationData table Updated location data
---@return table result
function LocationEditor.UpdateLocation(source, locationId, locationData)
    -- Validate
    local valid, err = LocationEditor.ValidateLocation(locationData)
    if not valid then
        return { success = false, error = err }
    end
    
    local LocationManager = DCE and DCE.GetService and DCE.GetService("LocationManager")
    if not LocationManager then
        return { success = false, error = "LocationManager service not available" }
    end
    
    -- Get original for undo
    local original = LocationManager.GetLocation(locationId)
    
    -- Update the location
    local success, err = LocationManager.UpdateLocation(locationId, locationData)
    
    if success and original then
        -- Add restore to undo stack
        LocationEditor.PushUndoAction(source, {
            action = "restore",
            locationId = locationId,
            original = original,
        })
        
        log("info", "Location updated by player %d: %s", source, locationId)
    end
    
    return { success = success, error = err, location = success and locationData or nil }
end

--- Delete a location (with undo support)
---@param source number Player source
---@param locationId string Location ID
---@return table result
function LocationEditor.DeleteLocation(source, locationId)
    local LocationManager = DCE and DCE.GetService and DCE.GetService("LocationManager")
    if not LocationManager then
        return { success = false, error = "LocationManager service not available" }
    end
    
    -- Get location for undo
    local original = LocationManager.GetLocation(locationId)
    
    -- Delete
    local success = LocationManager.DeleteLocation(locationId)
    
    if success and original then
        -- Add restore to undo stack
        LocationEditor.PushUndoAction(source, {
            action = "create",
            location = original,
        })
        
        log("info", "Location deleted by player %d: %s", source, locationId)
    end
    
    return { success = success }
end

--- Undo the last action
---@param source number Player source
---@return table result
function LocationEditor.Undo(source)
    local history = editHistory[source]
    if not history or #history.undoStack == 0 then
        return { success = false, error = "No actions to undo" }
    end
    
    local action = table.remove(history.undoStack)
    local LocationManager = DCE and DCE.GetService and DCE.GetService("LocationManager")
    
    if action.action == "delete" then
        -- Recreate the deleted location
        if LocationManager and LocationManager.CreateLocation then
            LocationManager.CreateLocation(action.location)
        end
    elseif action.action == "create" then
        -- Delete the created location
        if LocationManager and LocationManager.DeleteLocation then
            LocationManager.DeleteLocation(action.locationId)
        end
    elseif action.action == "restore" then
        -- Restore original
        if LocationManager and LocationManager.UpdateLocation then
            LocationManager.UpdateLocation(action.locationId, action.original)
        end
    end
    
    return { success = true, undoneAction = action.action }
end

--- Redo the last undone action
---@param source number Player source
---@return table result
function LocationEditor.Redo(source)
    local history = editHistory[source]
    if not history or #history.redoStack == 0 then
        return { success = false, error = "No actions to redo" }
    end
    
    local action = table.remove(history.redoStack)
    -- Redo logic would mirror undo, switching stacks
    
    return { success = true, redoneAction = action.action }
end

--- Push an action to the undo stack
---@param source number Player source
---@param action table Action to push
local function PushUndoAction(source, action)
    if not editHistory[source] then
        editHistory[source] = { undoStack = {}, redoStack = {} }
    end
    
    local maxHistory = (_G.Config and _G.Config.CC and _G.Config.CC.LocationEditor and _G.Config.CC.LocationEditor.UndoHistorySize) or 50
    if #editHistory[source].undoStack >= maxHistory then
        table.remove(editHistory[source].undoStack, 1)
    end
    
    table.insert(editHistory[source].undoStack, action)
    editHistory[source].redoStack = {} -- Clear redo stack on new action
end

--- List all locations (for editor)
---@return table Array of locations
function LocationEditor.ListLocations()
    local LocationManager = DCE and DCE.GetService and DCE.GetService("LocationManager")
    if LocationManager then
        return LocationManager.ListLocations and LocationManager.ListLocations() or {}
    end
    return {}
end

--- Get a specific location
---@param locationId string
---@return table|nil Location
function LocationEditor.GetLocation(locationId)
    local LocationManager = DCE and DCE.GetService and DCE.GetService("LocationManager")
    if LocationManager then
        return LocationManager.GetLocation and LocationManager.GetLocation(locationId)
    end
end

--- List all territories
---@return table Array of territories
function LocationEditor.ListTerritories()
    local LocationManager = DCE and DCE.GetService and DCE.GetService("LocationManager")
    if LocationManager then
        return LocationManager.ListTerritories and LocationManager.ListTerritories() or {}
    end
    return {}
end

--- Create a territory
---@param source number
---@param territoryData table
---@return table result
function LocationEditor.CreateTerritory(source, territoryData)
    territoryData.type = "territory"
    return LocationEditor.CreateLocation(source, territoryData)
end

--- Update a territory
---@param source number
---@param locationId string
---@param territoryData table
---@return table result
function LocationEditor.UpdateTerritory(source, locationId, territoryData)
    territoryData.type = "territory"
    return LocationEditor.UpdateLocation(source, locationId, territoryData)
end

--- Delete a territory
---@param source number
---@param locationId string
---@return table result
function LocationEditor.DeleteTerritory(source, locationId)
    return LocationEditor.DeleteLocation(source, locationId)
end

--- Shutdown the editor
function LocationEditor.Shutdown()
    editHistory = {}
    log("info", "Location Editor service shut down")
end

return LocationEditor