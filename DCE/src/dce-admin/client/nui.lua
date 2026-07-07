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

-- ============================================================================
-- Data Request Callbacks

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
-- Keybind Registration (FiveM client-side)
-- ============================================================================

-- Register keybind when resource starts (FiveM-specific)
-- Note: RegisterKeyMapping is FiveM-specific and may not exist in all environments
AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
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
