---@diagnostic disable: redundant-parameter
-- DCE Control Center NUI Client
-- Handles NUI display and user interaction
-- Note: SetNuiFocus takes 2 parameters in FiveM (hasFocus, hasCursor)

-- ============================================================================
-- NUI State Management
-- ============================================================================

local hasFocus = false
local playerUIState = {}

-- Safely release focus and cursor
local function releaseFocus()
    hasFocus = false
    if SetNuiFocus then
        SetNuiFocus(false, false)
    end
    if SendNUIMessage then
        SendNUIMessage({
            action = "close"
        })
    end
end

-- ============================================================================
-- Dashboard Open/Close Events
-- ============================================================================

-- Open Control Center
RegisterNetEvent('dce-admin:client:openDashboard', function()
    if hasFocus then return end
    
    hasFocus = true
    if SetNuiFocus then
        SetNuiFocus(true, true)
    end
    if SendNUIMessage then
        SendNUIMessage({
            action = "open"
        })
    end
end)

-- Close Control Center (server triggered)
RegisterNetEvent('dce-admin:client:closeDashboard', function()
    releaseFocus()
end)

-- ============================================================================
-- EventBus subscription request
-- ============================================================================

RegisterNUICallback('subscribe', function(data, cb)
    -- Forward event name to server for EventBus registration
    if data.eventName then
        TriggerServerEvent('dce-admin:server:subscribe', data.eventName)
    end
    cb({})
end)

-- ============================================================================
-- Keybind Handler (for opening Control Center)
-- ============================================================================

-- Listen for keybind activation from client (FiveM RegisterKeyMapping)
RegisterNetEvent('dce-admin:client:openByKeybind', function()
    if hasFocus then return end
    
    if DCE and DCE.Log then
        DCE.Log("admin", "debug", "Control Center opened via keybind")
    end
    
    hasFocus = true
    if SetNuiFocus then
        SetNuiFocus(true, true)
    end
    if SendNUIMessage then
        SendNUIMessage({
            action = "open"
        })
    end
end)

-- ============================================================================
-- NUI Callbacks (from JS)
-- ============================================================================

-- Generic close callback from JS close button
RegisterNUICallback('close', function(data, cb)
    releaseFocus()
    cb({})
end)

-- NUI ready notification
RegisterNUICallback('nuiReady', function(data, cb)
    -- UI loaded, acknowledge
    cb({ status = "ready" })
end)

-- ESC key handler - closes Control Center when pressed
RegisterNUICallback('keydown', function(data, cb)
    if data.key == "Escape" or data.key == "Esc" then
        releaseFocus()
    end
    cb({})
end)

-- Window close notification
RegisterNUICallback('windowClosed', function(data, cb)
    -- Window was closed in UI, could log for audit
    if DCE and DCE.Log then
        DCE.Log("admin", "debug", "Window closed: %s", data.windowId)
    end
    cb({})
end)

-- Keybind handler - receives activation from keybind check on server
RegisterNUICallback('toggleControlCenter', function(data, cb)
    if hasFocus then
        -- Already open, close it
        releaseFocus()
    else
        -- Not open, open it
        hasFocus = true
        if SetNuiFocus then
            SetNuiFocus(true, true)
        end
        if SendNUIMessage then
            SendNUIMessage({
                action = "open"
            })
        end
    end
    cb({})
end)

-- World Editor: Position capture request
RegisterNUICallback('capturePosition', function(data, cb)
    if DCE and DCE.Log then
        DCE.Log("admin", "info", "Position capture requested from World Editor")
    end
    
    -- Emit event for position capture (can be handled by other systems)
    if DCE and DCE.Emit then
        DCE.Emit("worldeditor:position:captureRequested", {
            eventName = "worldeditor:position:captureRequested",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-admin",
            payload = {}
        })
    end
    
    cb({ status = "requested" })
end)

-- ============================================================================
-- Data Request Callbacks
-- ============================================================================

RegisterNUICallback('getDashboardData', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        local result = AdminService.GetDashboardData and AdminService.GetDashboardData()
        cb(result or {})
    else
        cb({})
    end
end)

RegisterNUICallback('getOrganizations', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        local result = AdminService.GetOrganizationOverview and AdminService.GetOrganizationOverview()
        cb(result or {})
    else
        cb({})
    end
end)

RegisterNUICallback('getIncidents', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        local result = AdminService.GetActiveIncidents and AdminService.GetActiveIncidents()
        cb(result or {})
    else
        cb({})
    end
end)

RegisterNUICallback('getServices', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        local result = AdminService.GetServicesList and AdminService.GetServicesList()
        cb(result or {})
    else
        cb({})
    end
end)

RegisterNUICallback('getTasks', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        local result = AdminService.GetTasksList and AdminService.GetTasksList()
        cb(result or {})
    else
        cb({})
    end
end)

RegisterNUICallback('getEvents', function(data, cb)
    local CoreRegistry = (DCE and DCE.GetService) and DCE.GetService("CoreRegistry")
    if CoreRegistry then
        cb(CoreRegistry.ListEvents and CoreRegistry.ListEvents() or {})
    else
        cb({})
    end
end)

RegisterNUICallback('getPlugins', function(data, cb)
    local CoreRegistry = (DCE and DCE.GetService) and DCE.GetService("CoreRegistry")
    if CoreRegistry then
        cb(CoreRegistry.ListPlugins and CoreRegistry.ListPlugins() or {})
    else
        cb({})
    end
end)

RegisterNUICallback('getAdapters', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        cb(AdminService.GetIntegrationHealth and AdminService.GetIntegrationHealth() or {})
    else
        cb({})
    end
end)

RegisterNUICallback('getDebugHistory', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        local limit = data and data.limit or 50
        cb(AdminService.GetDebugHistory and AdminService.GetDebugHistory(limit) or {})
    else
        cb({})
    end
end)

RegisterNUICallback('getAuditLog', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        local limit = data and data.limit or 50
        cb(AdminService.GetAuditLog and AdminService.GetAuditLog(limit) or {})
    else
        cb({})
    end
end)

RegisterNUICallback('getConfigs', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        cb(AdminService.GetAllConfigs and AdminService.GetAllConfigs() or {})
    else
        cb({})
    end
end)

RegisterNUICallback('executeDebug', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        local result = AdminService.ExecuteDebugCommand and AdminService.ExecuteDebugCommand(source, data.command, data.args or {})
        cb(result or {})
    else
        cb({})
    end
end)

RegisterNUICallback('updateConfig', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService and AdminService.UpdateConfig then
        local success, err = AdminService.UpdateConfig(data.resource, data.key, data.value)
        cb({ success = success, error = err })
    else
        cb({ success = false, error = "Admin service not available" })
    end
end)

-- ============================================================================
-- World Editor NUI Callbacks
-- ============================================================================

RegisterNUICallback('getLocations', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        cb(AdminService.GetAllLocations and AdminService.GetAllLocations() or { locations = {} })
    else
        cb({ locations = {} })
    end
end)

RegisterNUICallback('getLocation', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        cb(AdminService.GetLocation and AdminService.GetLocation(data.id) or {})
    else
        cb({})
    end
end)

RegisterNUICallback('createLocation', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        cb(AdminService.CreateLocation and AdminService.CreateLocation(data) or { success = false, error = "Method not available" })
    else
        cb({ success = false, error = "Admin service not available" })
    end
end)

RegisterNUICallback('updateLocation', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        cb(AdminService.UpdateLocation and AdminService.UpdateLocation(data.id, data) or { success = false, error = "Method not available" })
    else
        cb({ success = false, error = "Admin service not available" })
    end
end)

RegisterNUICallback('deleteLocation', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        cb(AdminService.DeleteLocation and AdminService.DeleteLocation(data.id) or { success = false, error = "Method not available" })
    else
        cb({ success = false, error = "Admin service not available" })
    end
end)

RegisterNUICallback('getTerritories', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        cb(AdminService.GetAllTerritories and AdminService.GetAllTerritories() or { territories = {} })
    else
        cb({ territories = {} })
    end
end)

RegisterNUICallback('getTerritory', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        cb(AdminService.GetTerritory and AdminService.GetTerritory(data.id) or { success = false, error = "Not found" })
    else
        cb({})
    end
end)

RegisterNUICallback('createTerritory', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        cb(AdminService.CreateTerritory and AdminService.CreateTerritory(data) or { success = false, error = "Method not available" })
    else
        cb({ success = false, error = "Admin service not available" })
    end
end)

RegisterNUICallback('updateTerritory', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        cb(AdminService.UpdateTerritory and AdminService.UpdateTerritory(data.id, data) or { success = false, error = "Method not available" })
    else
        cb({ success = false, error = "Admin service not available" })
    end
end)

RegisterNUICallback('deleteTerritory', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        cb(AdminService.DeleteTerritory and AdminService.DeleteTerritory(data.id) or { success = false, error = "Method not available" })
    else
        cb({ success = false, error = "Admin service not available" })
    end
end)

RegisterNUICallback('getOrganizationFacilities', function(data, cb)
    local AdminService = (DCE and DCE.GetService) and DCE.GetService("Admin")
    if AdminService then
        cb(AdminService.GetOrganizationFacilities and AdminService.GetOrganizationFacilities(data.orgId) or { facilities = {} })
    else
        cb({ facilities = {} })
    end
end)

-- ============================================================================
-- EventBus Forwarder
-- ============================================================================

-- This would be called by the server when events occur
RegisterNetEvent('dce-admin:client:eventbus:emit', function(payload)
    if SendNUIMessage and payload then
        SendNUIMessage({
            action = "eventbus:emit",
            eventName = payload.eventName,
            payload = payload.payload
        })
    end
end)

-- ============================================================================
-- NUI Lifecycle: Focus Safety
-- ============================================================================

-- FiveM Focus Behavior Documentation:
-- When a resource with ui_page loads, FiveM may automatically grant NUI focus
-- without an explicit message. This causes a gray overlay on spawn.
-- The fix: Always release focus on onClientResourceStart to ensure clean state.
--
-- Lifecycle:
--   Resource Start → NUI loads → (optional auto-focus) → onClientResourceStart fires
--   We release focus here → UI stays hidden until /dce admin or keybind pressed
--
-- Note: We send "close" action to JS even if UI not open, as it's idempotent
AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Step 1: Release any orphaned focus (FiveM auto-focus defense)
        hasFocus = false
        if SetNuiFocus then
            SetNuiFocus(false, false)
        end
        if SendNUIMessage then
            SendNUIMessage({
                action = "close"
            })
        end
        
        -- Step 2: Register keybind (only after focus is released)
        local keybindName = "dce_controlcenter"
        local keybindDesc = "Toggle DCE Control Center"
        
        local Config = _G.Config or {}
        local defaultKey = "KC_LMENU + K"
        if Config.Admin and Config.Admin.Keybind and Config.Admin.Keybind.Key then
            defaultKey = Config.Admin.Keybind.Key
        end
        
        -- Register keybind command
        local registerSuccess, registerErr = pcall(function()
            RegisterCommand("+" .. keybindName, function()
                TriggerServerEvent("dce-admin:server:keybindPressed", keybindName)
            end, false)
        end)
        
        if not registerSuccess and DCE and DCE.Log then
            DCE.Log("admin", "warn", "Failed to register keybind command: %s", tostring(registerErr))
        end
        
        -- Register keybind mapping (FiveM-specific)
        local keymapSuccess, keymapErr = pcall(function()
            if RegisterKeyMapping then
                RegisterKeyMapping("+" .. keybindName, keybindDesc, "keyboard", defaultKey)
            end
        end)
        
        if not keymapSuccess and DCE and DCE.Log then
            DCE.Log("admin", "warn", "RegisterKeyMapping not available or failed: %s", tostring(keymapErr))
        end
    end
end)
