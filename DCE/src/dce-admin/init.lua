-- DCE Admin UI - Resource Entry Point
-- Provides admin dashboard, monitoring, and debug console
-- v1.0 Scope: Organization overview, Active incidents, Performance metrics

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

local function GetDCEAPI()
    local DCEAPI = nil
    local attempts = 0
    while not DCEAPI and attempts < 50 do
        attempts = attempts + 1
        Citizen.Wait(100)
        local success, api = pcall(function()
            if exports and exports['dce-core'] and exports['dce-core'].GetDCEAPI then
                return exports['dce-core']:GetDCEAPI()
            end
            return nil
        end)
        if success then
            DCEAPI = api
        end
    end
    return DCEAPI
end

local function OnAdminStart()
    local DCEAPI = GetDCEAPI()
    if not DCEAPI then
        print("^1[DCE Admin] FATAL: Could not obtain DCE API from dce-core^0")
        return
    end
    _G.DCE = DCEAPI

    if DCE and DCE.Log then
        DCE.Log("admin", "info", "=== DCE Admin UI Starting ===")
    end

    -- Initialize the admin service (DCEAdminService is set by services/admin.lua at load time)
    if DCEAdminService and DCEAdminService.Initialize then
        DCEAdminService.Initialize(function(module, level, message, ...)
            if DCE and DCE.Log then
                DCE.Log(module, level, message, ...)
            end
        end)
    end

    -- Initialize commands module
    if DCEAdminCommands and DCEAdminCommands.Initialize then
        DCEAdminCommands.Initialize(function(module, level, message, ...)
            if DCE and DCE.Log then
                DCE.Log(module, level, message, ...)
            end
        end)
    end

    -- Register admin commands (after core is ready and services are registered)
    Citizen.CreateThread(function()
        Citizen.Wait(1000) -- Wait for all services to be registered
        if DCEAdminCommands and DCEAdminCommands.RegisterCommands then
            DCEAdminCommands.RegisterCommands()
        end
        if DCE and DCE.Log then
            DCE.Log("admin", "info", "Admin commands registered")
        end
    end)

    -- Register the Admin service
    -- Defensive patterns: return nil OR actual value for service timing safety
    if DCE and DCE.RegisterService then
        DCE.RegisterService("Admin", {
            HasPermission = function(source) 
                if DCEAdminService and DCEAdminService.HasPermission then
                    return DCEAdminService.HasPermission(source)
                end
                return false
            end,
            GetOrganizationOverview = function() 
                if DCEAdminService and DCEAdminService.GetOrganizationOverview then
                    return DCEAdminService.GetOrganizationOverview()
                end
                return {}
            end,
            GetActiveIncidents = function() 
                if DCEAdminService and DCEAdminService.GetActiveIncidents then
                    return DCEAdminService.GetActiveIncidents()
                end
                return {}
            end,
            GetPerformanceMetrics = function() 
                if DCEAdminService and DCEAdminService.GetPerformanceMetrics then
                    return DCEAdminService.GetPerformanceMetrics()
                end
                return {}
            end,
            GetIntegrationHealth = function() 
                if DCEAdminService and DCEAdminService.GetIntegrationHealth then
                    return DCEAdminService.GetIntegrationHealth()
                end
                return {}
            end,
            ExecuteDebugCommand = function(source, command, args) 
                if DCEAdminService and DCEAdminService.ExecuteDebugCommand then
                    return DCEAdminService.ExecuteDebugCommand(source, command, args)
                end
                return {}
            end,
            GetAuditLog = function(limit) 
                if DCEAdminService and DCEAdminService.GetAuditLog then
                    return DCEAdminService.GetAuditLog(limit)
                end
                return {}
            end,
            GetDebugHistory = function(limit) 
                if DCEAdminService and DCEAdminService.GetDebugHistory then
                    return DCEAdminService.GetDebugHistory(limit)
                end
                return {}
            end,
            GetDashboardData = function() 
                if DCEAdminService and DCEAdminService.GetDashboardData then
                    return DCEAdminService.GetDashboardData()
                end
                return {}
            end,
            LogAction = function(adminId, action, target) 
                if DCEAdminService and DCEAdminService.LogAction then
                    DCEAdminService.LogAction(adminId, action, target)
                end
            end,
            GetAllConfigs = function() 
                if DCEAdminService and DCEAdminService.GetAllConfigs then
                    return DCEAdminService.GetAllConfigs()
                end
                return {}
            end,
            UpdateConfig = function(resource, key, value) 
                if DCEAdminService and DCEAdminService.UpdateConfig then
                    return DCEAdminService.UpdateConfig(resource, key, value)
                end
                return false, "Admin service not available"
            end,
            GetConfig = function() 
                if DCEAdminService and DCEAdminService.GetConfig then
                    return DCEAdminService.GetConfig()
                end
                return {}
            end,
            GetServicesList = function() 
                if DCEAdminService and DCEAdminService.GetServicesList then
                    return DCEAdminService.GetServicesList()
                end
                return {}
            end,
            GetTasksList = function() 
                if DCEAdminService and DCEAdminService.GetTasksList then
                    return DCEAdminService.GetTasksList()
                end
                return {}
            end,
        })
    end

    -- Subscribe to admin action events for logging
    if DCE and DCE.On then
        DCE.On("admin:action:executed", function(payload)
            if DCE and DCE.Log then
                local data = payload and (payload.payload or payload)
                if data then
                    DCE.Log("admin", "debug", "Admin action: %s by %s on %s", data.action, data.adminId, tostring(data.target))
                end
            end
        end)
    end

    if DCE and DCE.Log then
        DCE.Log("admin", "info", "=== DCE Admin UI Started ===")
    end
end

local function OnAdminStop()
    -- Safely clean up - DCE may be nil if core shut down first
    if DCE and DCE.Log then
        DCE.Log("admin", "info", "=== DCE Admin UI Stopping ===")
    end
    
    if DCE and DCE.UnregisterService then
        DCE.UnregisterService("Admin")
    end
    
    if DCEAdminService and DCEAdminService.Shutdown then
        DCEAdminService.Shutdown()
    end
    
    if DCE and DCE.Log then
        DCE.Log("admin", "info", "=== DCE Admin UI Stopped ===")
    end
end

-- ============================================================================
-- Lifecycle Hooks
-- ============================================================================

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnAdminStart()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnAdminStop()
    end
end)

-- ============================================================================
-- Export Functions
-- ============================================================================

--- Get the config table for exports
function GetConfig()
    return _G.Config or {}
end