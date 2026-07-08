-- DCE Control Center v2 - Resource Entry Point
-- Registers services and initializes the Control Center

-- ============================================================================
-- Global state
-- ============================================================================

local DCE = _G.DCE
local DCEControlCenterService = nil
local DCELocationEditorService = nil
local DCEOrganizationEditorService = nil
local DCEPluginRegistryService = nil

-- ============================================================================
-- Events for NUI subscriptions
-- ============================================================================

local function RegisterNUIEventHandlers()
    -- Location editor callbacks
    RegisterNUICallback('dcc-location:create', function(data, cb)
        local source = source
        if DCELocationEditorService then
            local result = DCELocationEditorService.CreateLocation(source, data)
            cb(result)
        else
            cb({ success = false, error = "LocationEditor not available" })
        end
    end)
    
    RegisterNUICallback('dcc-location:update', function(data, cb)
        local source = source
        if DCELocationEditorService then
            local result = DCELocationEditorService.UpdateLocation(source, data.id, data)
            cb(result)
        else
            cb({ success = false, error = "LocationEditor not available" })
        end
    end)
    
    RegisterNUICallback('dcc-location:delete', function(data, cb)
        local source = source
        if DCELocationEditorService then
            local result = DCELocationEditorService.DeleteLocation(source, data.id)
            cb(result)
        else
            cb({ success = false, error = "LocationEditor not available" })
        end
    end)
    
    RegisterNUICallback('dcc-location:list', function(data, cb)
        if DCELocationEditorService then
            local locations = DCELocationEditorService.ListLocations()
            cb({ locations = locations })
        else
            cb({ locations = {} })
        end
    end)
    
    RegisterNUICallback('dcc-location:get', function(data, cb)
        if DCELocationEditorService then
            local loc = DCELocationEditorService.GetLocation(data.id)
            cb(loc or {})
        else
            cb({})
        end
    end)
    
    RegisterNUICallback('dcc-territory:list', function(data, cb)
        if DCELocationEditorService then
            local territories = DCELocationEditorService.ListTerritories()
            cb({ territories = territories })
        else
            cb({ territories = {} })
        end
    end)
    
    RegisterNUICallback('dcc-territory:create', function(data, cb)
        local source = source
        if DCELocationEditorService then
            local result = DCELocationEditorService.CreateTerritory(source, data)
            cb(result)
        else
            cb({ success = false, error = "LocationEditor not available" })
        end
    end)
    
    RegisterNUICallback('dcc-territory:update', function(data, cb)
        local source = source
        if DCELocationEditorService then
            local result = DCELocationEditorService.UpdateTerritory(source, data.id, data)
            cb(result)
        else
            cb({ success = false, error = "LocationEditor not available" })
        end
    end)
    
    RegisterNUICallback('dcc-territory:delete', function(data, cb)
        local source = source
        if DCELocationEditorService then
            local result = DCELocationEditorService.DeleteTerritory(source, data.id)
            cb(result)
        else
            cb({ success = false, error = "LocationEditor not available" })
        end
    end)
    
    -- Window management callbacks
    RegisterNUICallback('dcc-window:state', function(data, cb)
        local src = source
        if DCEControlCenterService then
            DCEControlCenterService.SetWindowState(src, data.windowId, data.state)
        end
        cb({})
    end)
    
    RegisterNUICallback('dcc-window:allClosed', function(data, cb)
        local src = source
        -- This is called when all windows are closed in NUI
        -- The lifecycle manager will handle focus release
        cb({})
    end)
    
    -- Event subscription for real-time updates
    RegisterNUICallback('dcc-eventbus:subscribe', function(data, cb)
        local src = source
        if DCEControlCenterService and data.eventName then
            DCEControlCenterService.RegisterSubscription(src, data.eventName)
        end
        cb({})
    end)
    
    RegisterNUICallback('dcc-eventbus:unsubscribe', function(data, cb)
        local src = source
        if DCEControlCenterService and data.eventName then
            DCEControlCenterService.UnregisterSubscription(src, data.eventName)
        end
        cb({})
    end)
    
    -- Undo/Redo
    RegisterNUICallback('dcc-editor:undo', function(data, cb)
        local src = source
        if DCELocationEditorService then
            local result = DCELocationEditorService.Undo(src)
            cb(result)
        else
            cb({ success = false, error = "LocationEditor not available" })
        end
    end)
    
    RegisterNUICallback('dcc-editor:redo', function(data, cb)
        local src = source
        if DCELocationEditorService then
            local result = DCELocationEditorService.Redo(src)
            cb(result)
        else
            cb({ success = false, error = "LocationEditor not available" })
        end
    end)
    
    -- Dashboard data
    RegisterNUICallback('dcc-dashboard:data', function(data, cb)
        if DCEControlCenterService then
            cb(DCEControlCenterService.GetDashboardData and DCEControlCenterService.GetDashboardData() or {})
        else
            cb({})
        end
    end)
    
    RegisterNUICallback('dcc-services:list', function(data, cb)
        if DCEControlCenterService then
            cb({ services = DCEControlCenterService.GetServices() })
        else
            cb({ services = {} })
        end
    end)
    
    RegisterNUICallback('dcc-plugins:list', function(data, cb)
        if DCEControlCenterService then
            cb({ plugins = DCEControlCenterService.GetPlugins() })
        else
            cb({ plugins = {} })
        end
    end)
    
    RegisterNUICallback('dcc-profiler:metrics', function(data, cb)
        if DCEControlCenterService then
            cb(DCEControlCenterService.GetProfilerMetrics())
        else
            cb({})
        end
    end)
    
    RegisterNUICallback('dcc-eventbus:metrics', function(data, cb)
        if DCEControlCenterService then
            cb(DCEControlCenterService.GetEventBusMetrics())
        else
            cb({})
        end
    end)
end

-- ============================================================================
-- Resource lifecycle
-- ============================================================================

local function OnResourceStart()
    local Diagnostics = _G.DCEDiagnostics
    
    -- Get DCE API
    if not DCE then
        if exports and exports['dce-core'] and exports['dce-core'].GetDCEAPI then
            DCE = _G.DCE or exports['dce-core']:GetDCEAPI()
        end
    end
    
    if not DCE then
        print("^1[DCE ControlCenter] FATAL: DCE API not available^0")
        return
    end
    
    -- Load services (they set their globals on load)
    local Logger = DCELogger
    
    if DCEControlCenterService then
        DCEControlCenterService.Init(Logger)
    end
    
    if DCELocationEditorService then
        DCELocationEditorService.Init(Logger)
    end
    
    if DCEOrganizationEditorService then
        DCEOrganizationEditorService.Init(Logger)
    end
    
    if DCEPluginRegistryService then
        DCEPluginRegistryService.Init(Logger)
    end
    
    -- Register with DCE
    if DCE.RegisterService then
        DCE.RegisterService("ControlCenter", DCEControlCenterService or {})
        DCE.RegisterService("LocationEditor", DCELocationEditorService or {})
        DCE.RegisterService("OrganizationEditor", DCEOrganizationEditorService or {})
    end
    
    -- Register NUI callbacks
    RegisterNUIEventHandlers()
    
    -- Register commands
    RegisterCommand('dce', function(source, args, rawCommand)
        local src = source
        if #args == 0 or args[1] == 'admin' then
            if DCEControlCenterService and DCEControlCenterService.RequestOpen then
                DCEControlCenterService.RequestOpen(src)
            end
        end
    end, true)
    
    -- Server event for keybind
    RegisterNetEvent('dce-cc:server:keybindPressed')
    AddEventHandler('dce-cc:server:keybindPressed', function()
        local src = source
        if DCEControlCenterService and DCEControlCenterService.RequestOpen then
            DCEControlCenterService.RequestOpen(src)
        end
    end)
    
    if Logger then
        Logger.Info("controlcenter", "Control Center v2 initialized")
    end
end

local function OnResourceStop()
    if DCEControlCenterService and DCEControlCenterService.Shutdown then
        DCEControlCenterService.Shutdown()
    end
    
    if DCELocationEditorService and DCELocationEditorService.Shutdown then
        DCELocationEditorService.Shutdown()
    end
    
    if DCEOrganizationEditorService and DCEOrganizationEditorService.Shutdown then
        DCEOrganizationEditorService.Shutdown()
    end
    
    if DCEPluginRegistryService and DCEPluginRegistryService.Shutdown then
        DCEPluginRegistryService.Shutdown()
    end
    
    if DCE and DCE.Log then
        DCE.Log("controlcenter", "info", "Control Center v2 stopped")
    end
end

-- Lifecycle hooks
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnResourceStart()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnResourceStop()
    end
end)

-- ============================================================================
-- Exports
-- ============================================================================

function GetConfig()
    return (_G.Config and _G.Config.CC) or {}
end

function GetLifecycleState()
    local LifecycleManager = _G.DCELifecycleManager
    if LifecycleManager then
        return LifecycleManager.getState and LifecycleManager.getState() or "closed"
    end
    return "closed"
end